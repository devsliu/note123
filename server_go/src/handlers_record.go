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
	return filepath.Join(s.recordsFolder, filepath.Join("user_"+strconv.FormatInt(userId, 10)))
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
		return "", ResultErrorFileSave.with(err.Error())
	}
	// Unique temp file: a fixed .tmp path would overwrite concurrent uploads of the same uuid, producing corrupt files
	tmp, err := os.CreateTemp(filepath.Dir(absPath), filepath.Base(absPath)+".*.tmp")
	if err != nil {
		return "", ResultErrorFileSave.with(err.Error())
	}
	tmpPath := tmp.Name()
	if _, err := io.Copy(tmp, file); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		return "", ResultErrorFileSave.with(err.Error())
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpPath)
		return "", ResultErrorFileSave.with(err.Error())
	}
	return tmpPath, ResultSuccess
}

// commitRecordTempFile: after DB commit succeeds, atomically replace the target file with the temp file; clean up the temp file on failure
func (s *Server) commitRecordTempFile(userId int64, recordUuid, tmpPath string) ResultCode {
	absPath := s.getRecordAbsPath(userId, recordUuid)
	// os.Rename atomically replaces an existing target file on Windows and within the same partition
	if err := os.Rename(tmpPath, absPath); err != nil {
		os.Remove(tmpPath)
		return ResultErrorFileSave.with(err.Error())
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

// updateRecord updates or creates a record
func (s *Server) updateRecordHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	uuid := r.URL.Query().Get("uuid")
	if !isValidRecordUUID(uuid) {
		http.Error(w, "invalid uuid", ResultErrorParams.Value)
		return
	}
	// Limit upload size; FormFile returns an error on oversized requests to avoid filling the disk
	r.Body = http.MaxBytesReader(w, r.Body, s.maxFileSize)
	createAt, err := getFormInt64(r, "createAt")
	if err != nil {
		http.Error(w, "invalid createAt", ResultErrorParams.Value)
		return
	}
	editAt, err := getFormInt64(r, "editAt")
	if err != nil {
		http.Error(w, "invalid editAt", ResultErrorParams.Value)
		return
	}
	fileEditAt, err := getFormInt64(r, "fileEditAt")
	if err != nil {
		http.Error(w, "invalid fileEditAt", ResultErrorParams.Value)
		return
	}
	locked, err := getFormInt64(r, "locked")
	if err != nil {
		locked = 0
	}
	// baseVersion: the server-side version known locally by the client, used for conflict detection (pass 0 for new records)
	baseVersion, _ := getFormInt64(r, "version")
	if baseVersion < 0 {
		baseVersion = 0
	}
	md5sum := ""
	path := r.FormValue("path")
	name := r.FormValue("name")
	file, fileHeader, formFileErr := r.FormFile("file")
	// Multipart parse failures (including size limit) must report an error; otherwise they would silently be treated as a "metadata-only update" and return success
	if formFileErr != nil && formFileErr != http.ErrMissingFile {
		http.Error(w, "multipart parse failed or file exceeds "+strconv.FormatInt(s.maxFileSize>>20, 10)+"MB limit", ResultErrorParams.Value)
		return
	}
	var tmpPath string
	hasTempFile := false
	if file != nil {
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
		tmpPath, rc = s.writeRecordTempFile(user.UserID, uuid, file)
		if rc != ResultSuccess {
			http.Error(w, rc.Message, rc.Value)
			return
		}
		hasTempFile = true
	}

	// 2. DB commit (version, md5, and metadata are persisted in one transaction)
	// The DB transaction MUST complete BEFORE the file commit. Otherwise, on a concurrent conflict the disk file would be overwritten
	// but the DB md5 would point to a different request's content, causing md5 mismatch during download (disk content ≠ DB md5).
	// UpsertRecord already includes full conflict detection (atomicity is guaranteed by the transaction).
	record, result := s.db.UpsertRecord(user.UserID, uuid, path, name, md5sum, createAt, editAt, fileEditAt, locked, baseVersion)
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
	// If rename fails: DB is committed but disk still has the old file; the client gets an error and retries, achieving eventual consistency
	if hasTempFile {
		if rc := s.commitRecordTempFile(user.UserID, uuid, tmpPath); rc != ResultSuccess {
			http.Error(w, rc.Message, rc.Value)
			return
		}
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(record)
}

// deleteRecord deletes a record
func (s *Server) deleteRecordHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	uuid := r.URL.Query().Get("uuid")
	if !isValidRecordUUID(uuid) {
		http.Error(w, "invalid uuid", ResultErrorParams.Value)
		return
	}
	// Existence check, version increment, and soft delete all happen within the same transaction of DeleteRecord (with TOCTOU protection and idempotency).
	// Physical files are removed after DB succeeds, to avoid the "record exists but file is missing" state caused by DB failure.
	record, purgedVersion, result := s.db.DeleteRecord(user.UserID, uuid)
	if result != ResultSuccess {
		http.Error(w, result.Message, result.Value)
		return
	}
	os.Remove(s.getRecordAbsPath(user.UserID, record.UUID))

	// Only update the cache when a milestone is triggered: non-milestone deletes return purgedVersion=0,
	// and a direct assignment would clear the already-advanced cache value, causing old clients to miss tombstone cleanup and skip a full re-sync
	if purgedVersion > 0 {
		user.PurgedVersion.Store(purgedVersion)
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(record)
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
	// Delete all files (log only on failure; DB is committed, and a future full sync will never reference these files again)
	if err := s.deleteRecordFilesByUser(user.UserID); err != nil {
		log.Printf("clear records: delete files failed, userId:%d err:%v", user.UserID, err)
	}
	user.PurgedVersion.Store(purgedVersion)
	w.WriteHeader(http.StatusOK)
}
