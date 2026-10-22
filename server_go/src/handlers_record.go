package main

import (
	"crypto/md5"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// ---- record file helpers ----

func (s *Server) getRecordAbsFolder(userId int64) string {
	return filepath.Join(s.recordsFolder, "user_"+strconv.FormatInt(userId, 10), "record")
}

func (s *Server) getRecordAbsPath(userId int64, recordUuid string) string {
	return filepath.Join(s.getRecordAbsFolder(userId), recordUuid)
}

func (s *Server) deleteRecordFilesByUser(userId int64) error {
	return os.RemoveAll(s.getRecordAbsFolder(userId))
}

// writeRecordTempFile writes an upload to a temporary file and returns the temp path.
// The caller must call commitRecordTempFile after the DB transaction commits successfully to complete the atomic replace.
func (s *Server) writeRecordTempFile(userId int64, recordUuid string, file multipart.File) (string, ResultCode) {
	absPath := s.getRecordAbsPath(userId, recordUuid)
	if err := os.MkdirAll(filepath.Dir(absPath), 0755); err != nil {
		return "", ResultErrorRecordSave.with(err.Error())
	}
	// Unique temp file: a fixed .tmp path would overwrite concurrent uploads of the same uuid, producing corrupt files
	tmp, err := os.CreateTemp(filepath.Dir(absPath), filepath.Base(absPath)+".*.tmp")
	if err != nil {
		return "", ResultErrorRecordSave.with(err.Error())
	}
	tmpPath := tmp.Name()
	if _, err := io.Copy(tmp, file); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		return "", ResultErrorRecordSave.with(err.Error())
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpPath)
		return "", ResultErrorRecordSave.with(err.Error())
	}
	return tmpPath, ResultSuccess
}

// commitRecordTempFile: after DB commit succeeds, atomically replace the target file with the temp file; clean up the temp file on failure
func (s *Server) commitRecordTempFile(userId int64, recordUuid, tmpPath string) ResultCode {
	absPath := s.getRecordAbsPath(userId, recordUuid)
	// os.Rename atomically replaces an existing target file on Windows and within the same partition
	if err := os.Rename(tmpPath, absPath); err != nil {
		os.Remove(tmpPath)
		return ResultErrorRecordSave.with(err.Error())
	}
	return ResultSuccess
}

// md5OfFile computes the MD5 of an uploaded file and resets the file pointer to the start for subsequent disk writes
func (s *Server) md5OfFile(file multipart.File) (string, error) {
	h := md5.New()
	if _, err := io.Copy(h, file); err != nil {
		return "", err
	}
	md5sum := strings.ToUpper(hex.EncodeToString(h.Sum(nil)))
	file.Seek(0, io.SeekStart)
	return md5sum, nil
}

// ---- record handlers ----

// updateRecord updates or creates a record.
// Request is multipart/form-data:
//   - field "data": JSON-encoded RecordUpsert (metadata)
//   - field "file": optional content file
//
// The server computes the file md5 itself; the client-provided md5 is overridden.
func (s *Server) updateRecordHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	// Limit upload size; FormFile returns an error on oversized requests to avoid filling the disk
	r.Body = http.MaxBytesReader(w, r.Body, s.maxFileSize)

	// Parse the multipart form first (FormFile triggers ParseMultipartForm).
	file, fileHeader, formFileErr := r.FormFile("file")
	if formFileErr != nil && formFileErr != http.ErrMissingFile {
		http.Error(w, "multipart parse failed or file exceeds "+strconv.FormatInt(s.maxFileSize>>20, 10)+"MB limit", ResultErrorParams.Value)
		return
	}
	hasFile := file != nil

	// Parse metadata from the JSON "data" form field.
	var upsert RecordUpsert
	if dataStr := r.FormValue("data"); dataStr != "" {
		if err := json.Unmarshal([]byte(dataStr), &upsert); err != nil {
			http.Error(w, "invalid data field", ResultErrorParams.Value)
			return
		}
	}
	if !isValidRecordUUID(upsert.UUID) {
		http.Error(w, "invalid uuid", ResultErrorParams.Value)
		return
	}

	md5sum := ""
	var tmpPath string
	hasTempFile := false
	if hasFile {
		defer file.Close()
		if fileHeader.Size > s.maxFileSize {
			http.Error(w, "file exceeds "+strconv.FormatInt(s.maxFileSize>>20, 10)+"MB limit", ResultErrorParams.Value)
			return
		}
		_md5sum, err := s.md5OfFile(file)
		if err != nil {
			http.Error(w, "file md5 computation failed", ResultErrorParams.Value)
			return
		}
		md5sum = _md5sum
		// 1. First write the upload to a temp file; do NOT touch the target file or DB at this stage
		var rc ResultCode
		tmpPath, rc = s.writeRecordTempFile(user.UserID, upsert.UUID, file)
		if rc != ResultSuccess {
			http.Error(w, rc.Message, rc.Value)
			return
		}
		hasTempFile = true
	}
	// Server-computed md5 always overrides the client-provided one.
	upsert.MD5 = md5sum

	// 2. DB commit (version, md5, and metadata are persisted in one transaction)
	record, result := s.db.UpsertRecord(user.UserID, &upsert)
	if result != ResultSuccess {
		if hasTempFile {
			os.Remove(tmpPath)
		}
		if result == ResultErrorRecordConflict {
			w.WriteHeader(result.Value)
			json.NewEncoder(w).Encode(record)
			return
		}
		http.Error(w, result.Message, result.Value)
		return
	}

	// 3. Atomically replace the target file after DB commit succeeds
	if hasTempFile {
		if rc := s.commitRecordTempFile(user.UserID, upsert.UUID, tmpPath); rc != ResultSuccess {
			http.Error(w, rc.Message, rc.Value)
			return
		}
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(record)
}

// deleteRecordsHandler batch deletes records.
// Request body: JSON array of {"uuid", "version"}.
// Response: JSON array of {"uuid", "code", "data"} — one entry per requested uuid, in order.
//   - code 200: deleted (data is the tombstone record)
//   - code 531: conflict (data is the current server record, client should restore)
//   - code 533: record not found
func (s *Server) deleteRecordsHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	var items []DeleteRecordsItem
	if err := json.NewDecoder(r.Body).Decode(&items); err != nil {
		http.Error(w, "invalid request body", ResultErrorParams.Value)
		return
	}
	results, maxPurgedVersion := s.db.DeleteRecords(user.UserID, items)

	// Remove physical files and shares for successfully deleted records
	for _, res := range results {
		if res.Code == ResultSuccess.Value && res.Data != nil {
			os.Remove(s.getRecordAbsPath(user.UserID, res.Data.UUID))
			s.deleteSharesByRecord(user.UserID, res.Data.UUID)
		}
	}

	// Only update the cache when a milestone is triggered (same rationale as single delete)
	if maxPurgedVersion > 0 {
		user.PurgedVersion.Store(maxPurgedVersion)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(results)
}

// updateRecordsHandler batch upserts file-less records (metadata only, no file upload).
// Request body: JSON array of RecordUpsert objects.
// Response: JSON array of {"uuid", "code", "data"} — one entry per requested uuid, in order.
//   - code 200: upserted (data is the updated record)
//   - code 531: conflict (data is the current server record)
func (s *Server) updateRecordsHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	var items []RecordUpsert
	if err := json.NewDecoder(r.Body).Decode(&items); err != nil {
		http.Error(w, "invalid request body", ResultErrorParams.Value)
		return
	}
	results := s.db.UpsertRecords(user.UserID, items)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(results)
}

// queryRecords queries all records (incremental / full)
func (s *Server) queryRecordsHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	version, err := strconv.ParseInt(r.URL.Query().Get("version"), 10, 64)
	if err != nil {
		http.Error(w, "Invalid version", http.StatusBadRequest)
		return
	}
	limit, err := strconv.ParseInt(r.URL.Query().Get("limit"), 10, 64)
	if err != nil {
		http.Error(w, "Invalid limit", http.StatusBadRequest)
		return
	}
	// Constrain pagination range: negative or zero values are treated as "unlimited" by SQLite, fetching the whole table at once;
	// cap at 1000 to prevent malicious or unexpected parameters from crashing memory and bandwidth
	const maxFetchLimit = 1000
	if limit <= 0 {
		http.Error(w, "Invalid limit", http.StatusBadRequest)
		return
	}
	if limit > maxFetchLimit {
		limit = maxFetchLimit
	}

	// 强制全量: 客户端 version > 0 且低于 purgedVersion 时, 该区间内的墓碑已被物理删除,
	// 增量查询无法返回删除事件, 客户端会出现幽灵记录. 返回 537 让客户端必须走全量同步.
	// version=0 表示客户端正在全量拉取, 不触发此判断.
	// full=1 表示客户端已进入全量同步翻页流程, 跳过此判断 (否则翻页游标始终 < purgedVersion 会死循环).
	isFullSync := r.URL.Query().Get("full") == "1"
	if !isFullSync && version > 0 && version < user.PurgedVersion.Load() {
		http.Error(w, ResultErrorNeedFullSync.Message, ResultErrorNeedFullSync.Value)
		return
	}

	records, result := s.db.QueryRecordsByVersion(user.UserID, version, limit)
	if result != ResultSuccess {
		http.Error(w, result.Message, result.Value)
		return
	}

	// Returns {"records":[], "purgedVersion"}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"records":       records,
		"purgedVersion": user.PurgedVersion.Load(),
	})
}

// downloadRecordFile downloads a record file
func (s *Server) downloadRecordFileHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	uuid := r.URL.Query().Get("uuid")
	if !isValidRecordUUID(uuid) {
		http.Error(w, "invalid uuid", ResultErrorParams.Value)
		return
	}
	record, result := s.db.GetRecord(user.UserID, uuid)
	if result != ResultSuccess {
		http.Error(w, result.Message, result.Value)
		return
	}
	absPath := s.getRecordAbsPath(user.UserID, record.UUID)
	f, err := os.Open(absPath)
	if err != nil {
		http.Error(w, ResultErrorFileNotFound.Message, ResultErrorFileNotFound.Value)
		return
	}
	defer f.Close()
	// Strip control characters from the filename to prevent HTTP header injection that would discard Content-Disposition
	filename := filepath.Base(record.Path)
	for _, c := range filename {
		if c < 32 || c == 127 {
			filename = "download"
			break
		}
	}
	w.Header().Set("Content-Disposition", "attachment; filename="+filename)
	w.Header().Set("Content-Type", "application/octet-stream")
	// Carry record metadata so the client can verify file integrity and version correctness after download
	w.Header().Set("x-record-fileversion", strconv.FormatInt(record.FileVersion, 10))
	w.Header().Set("x-record-md5", record.MD5)
	w.WriteHeader(http.StatusOK)
	if _, err := io.Copy(w, f); err != nil {
		// Status code and headers are already written and cannot be changed; at least log it so truncated transfers can be noticed
		log.Printf("download record file failed, uuid:%s err:%v", record.UUID, err)
	}
}

// clearRecords removes all current user records and files, and advances the version watermark to notify clients to fully re-sync
func (s *Server) clearRecordsHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	var purgedVersion int64
	// Table clear and version/purgedVersion advancement must happen in the same transaction:
	// without advancing purgedVersion, already-synced clients' lastSyncedVersion would never be below the threshold,
	// so a full re-sync would never be triggered and local data would remain orphaned after the server clears everything
	err := s.db.ExecInTransaction(func(tx *sql.Tx) error {
		if _, err := tx.Exec("DELETE FROM record_" + strconv.FormatInt(user.UserID, 10)); err != nil {
			return err
		}
		// Increment version first, then advance purgedVersion to the new value,
		// ensuring all already-synced clients (lastSyncedVersion <= old version) are strictly below the threshold
		if _, err := tx.Exec("UPDATE user SET version = version + 1 WHERE id = ?", user.UserID); err != nil {
			return err
		}
		return tx.QueryRow("UPDATE user SET purgedVersion = version WHERE id = ? RETURNING purgedVersion", user.UserID).Scan(&purgedVersion)
	})
	if err != nil {
		http.Error(w, "DB error", http.StatusInternalServerError)
		return
	}
	// Delete all record files (log only on failure; DB is committed, and a future full sync will never reference these files again).
	// Also drop the user's share folder — every shared file is tied to a record, and clearing records invalidates all links.
	if err := s.deleteRecordFilesByUser(user.UserID); err != nil {
		log.Printf("clear records: delete files failed, userId:%d err:%v", user.UserID, err)
	}
	os.RemoveAll(s.getShareFolder(user.UserID))
	user.PurgedVersion.Store(purgedVersion)
	w.WriteHeader(http.StatusOK)
}
