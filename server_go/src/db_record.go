package main

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

// normalizeReminder converts empty JSON arrays ("[]") or "null" to "", so the
// stored/returned reminder field never carries a meaningless empty array.
func normalizeReminder(s string) string {
	t := strings.TrimSpace(s)
	if t == "[]" || t == "null" {
		return ""
	}
	return s
}

type Record struct {
	UUID        string `json:"uuid"`
	Path        string `json:"path"`
	Name        string `json:"name"`
	CreateAt    int64  `json:"createAt"`
	EditAt      int64  `json:"editAt"`
	DeleteAt    int64  `json:"deleteAt"`
	Version     int64  `json:"version"`     // note record version; incremented each time the note is modified
	MD5         string `json:"md5"`         // md5 hash of the note file
	FileEditAt  int64  `json:"fileEditAt"`  // last-edit time of the note file, in milliseconds
	FileVersion int64  `json:"fileVersion"` // note file version; 0 without file content, first content is 1, then +1 on each change
	Locked      int64  `json:"locked"`      // whether the note is locked; 0 = unlocked, non-0 = lock timestamp
	Reminder    string `json:"reminder"`    // JSON array of reminder tasks, "" means no reminders
}

const recordColumns = "uuid, path, name, md5, version, createAt, editAt, deleteAt, fileEditAt, fileVersion, locked, reminder"

func (e *Record) scanTargets() []interface{} {
	return []interface{}{
		&e.UUID, &e.Path, &e.Name, &e.MD5, &e.Version,
		&e.CreateAt, &e.EditAt, &e.DeleteAt, &e.FileEditAt, &e.FileVersion, &e.Locked, &e.Reminder,
	}
}

func NewRecord(uuid, path, name, md5 string, createAt, editAt, deleteAt, version, fileEditAt, fileVersion, locked int64, reminder string) *Record {
	return &Record{
		UUID:        uuid,
		Path:        path,
		Name:        name,
		CreateAt:    createAt,
		EditAt:      editAt,
		DeleteAt:    deleteAt,
		Version:     version,
		MD5:         md5,
		FileEditAt:  fileEditAt,
		FileVersion: fileVersion,
		Locked:      locked,
		Reminder:    reminder,
	}
}

func createRecordTableSql(userId int64) string {
	return fmt.Sprintf(`
		CREATE TABLE IF NOT EXISTS record_%d (
			uuid TEXT NOT NULL PRIMARY KEY,
			path TEXT NOT NULL,
			name TEXT NOT NULL,
			createAt INTEGER NOT NULL DEFAULT 0,
			editAt INTEGER NOT NULL DEFAULT 0,
			deleteAt INTEGER NOT NULL DEFAULT 0,
			version INTEGER NOT NULL DEFAULT 0,
			md5 TEXT NOT NULL DEFAULT '',
			fileEditAt INTEGER NOT NULL DEFAULT 0,
			fileVersion INTEGER NOT NULL DEFAULT 0,
			locked INTEGER NOT NULL DEFAULT 0,
			reminder TEXT NOT NULL DEFAULT ''
		);
		CREATE INDEX IF NOT EXISTS idx_record_version_%d ON record_%d (version);`, userId, userId, userId)
}

func dropRecordTableSql(userId int64) string {
	return fmt.Sprintf("DROP TABLE IF EXISTS record_%d;", userId)
}

// RecordUpsert carries the fields for an upsert operation.
// Numeric fields use 0 as the "not provided" sentinel (skip update on conflict).
// Locked and Reminder use pointers because 0 / "" are meaningful values for them.
// Path and Name are required (non-empty); MD5 is "" when no file was uploaded.
type RecordUpsert struct {
	UUID        string
	Path        string
	Name        string
	MD5         string
	CreateAt    int64
	EditAt      int64
	FileEditAt  int64
	Locked      *int64
	Reminder    *string
	BaseVersion int64
}

// UpsertRecord inserts or updates a record.
// baseVersion is the server-side version known locally by the client (pass 0 for a new record).
// If the current server version > baseVersion, another device has already pushed; return ResultErrorRecordConflict.
//
// Field update rules on conflict (update):
//   - path/name:    only update when non-empty; on create, empty path/name is rejected
//   - createAt:     never modified on update; on insert, 0 falls back to server time
//   - editAt:       always updated
//   - md5:          updated only when non-empty (file uploaded)
//   - fileEditAt:   only update when non-zero
//   - fileVersion:  auto-incremented when md5 changes
//   - locked:       only update when provided (pointer)
//   - reminder:     update when provided (empty string clears it)
func (db *DB) UpsertRecord(userId int64, u *RecordUpsert) (*Record, ResultCode) {
	tableName := fmt.Sprintf("record_%d", userId)
	reminder := ""
	if u.Reminder != nil {
		reminder = normalizeReminder(*u.Reminder)
	}
	var resultRecord *Record
	var conflictRecord *Record
	var bizResult ResultCode = ResultSuccess
	err := db.ExecInTransaction(func(tx *sql.Tx) error {
		// Conflict detection: reject overwrite when server version > client baseVersion.
		// Tombstones are exempt: any upsert onto a deleted record means re-creation/restore,
		// so revive it directly instead of returning a conflict (the client no longer knows
		// the tombstone version after restore).
		exist := &Record{}
		querySql := "SELECT " + recordColumns + " FROM " + tableName + " WHERE uuid=?"
		qErr := tx.QueryRow(querySql, u.UUID).Scan(exist.scanTargets()...)
		isNew := errors.Is(qErr, sql.ErrNoRows)
		if !isNew && qErr != nil {
			return qErr
		}
		if !isNew && exist.DeleteAt == 0 && exist.Version > u.BaseVersion {
			conflictRecord = exist
			bizResult = ResultErrorRecordConflict
			return nil
		}

		// New row with file content starts at fileVersion 1, otherwise 0
		insertFileVersion := int64(0)
		if u.MD5 != "" {
			insertFileVersion = 1
		}
		// Capture server time once to keep createAt/editAt consistent within the same request
		nowMs := time.Now().UnixMilli()

		// --- Resolve INSERT values (used when the row does not exist) ---
		// New records require non-empty path and name (DB columns are NOT NULL with no default)
		if isNew && (u.Path == "" || u.Name == "") {
			bizResult = ResultErrorParams.with("path and name are required for new records")
			return nil
		}
		// On create, a zero createAt falls back to server time
		if isNew && u.CreateAt == 0 {
			u.CreateAt = nowMs
		}
		// editAt is required; if the client sends 0, fall back to server time
		if u.EditAt == 0 {
			u.EditAt = nowMs
		}
		// If a file was uploaded, fileEditAt must be non-zero; fall back to server time
		if u.MD5 != "" && u.FileEditAt == 0 {
			u.FileEditAt = nowMs
		}
		lockedVal := int64(0)
		if u.Locked != nil {
			lockedVal = *u.Locked
		}

		// Version increment and row update must happen in the same transaction and same connection
		version, err := db.IncrementUserVersion(tx, userId)
		if err != nil {
			return err
		}

		// --- Build conditional SET clauses (columns only updated when provided) ---
		var setClauses []string
		if u.Path != "" {
			setClauses = append(setClauses, "path = excluded.path")
		}
		if u.Name != "" {
			setClauses = append(setClauses, "name = excluded.name")
		}
		if u.MD5 != "" {
			setClauses = append(setClauses, "md5 = excluded.md5")
		}
		if isNew {
			setClauses = append(setClauses, "createAt = excluded.createAt")
		} // never modify createAt on update
		if u.FileEditAt != 0 {
			setClauses = append(setClauses, "fileEditAt = excluded.fileEditAt")
		}
		if u.Locked != nil {
			setClauses = append(setClauses, "locked = excluded.locked")
		}
		if u.Reminder != nil {
			setClauses = append(setClauses, "reminder = excluded.reminder")
		}
		conditionalSet := strings.Join(setClauses, ", ")
		if conditionalSet != "" {
			conditionalSet = ", " + conditionalSet
		}

		sqlStmt := fmt.Sprintf(`
			INSERT INTO record_%d (`+recordColumns+`)
			VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?)
			ON CONFLICT(uuid) DO UPDATE SET
				version    = excluded.version,
				deleteAt   = 0,
				editAt     = excluded.editAt,
				fileVersion = CASE WHEN ? AND excluded.md5 != md5 THEN fileVersion + 1 ELSE fileVersion END`+conditionalSet+`
		`, userId)
		args := []interface{}{
			u.UUID, u.Path, u.Name, u.MD5, version, u.CreateAt, u.EditAt, u.FileEditAt, insertFileVersion, lockedVal, reminder,
			u.MD5 != "", // for the fileVersion CASE WHEN
		}
		_, err = tx.Exec(sqlStmt, args...)
		if err != nil {
			return err
		}
		resultRecord = &Record{}
		return tx.QueryRow("SELECT "+recordColumns+" FROM "+tableName+" WHERE uuid=?", u.UUID).Scan(resultRecord.scanTargets()...)
	})
	if err != nil {
		return nil, ResultCodeError(nil, ResultErrorDatabase, err)
	}
	if bizResult != ResultSuccess {
		return conflictRecord, bizResult
	}
	return resultRecord, ResultSuccess
}

func (db *DB) DeleteRecord(userId int64, uuid string) (*Record, int64, ResultCode) {
	now := time.Now().UnixMilli()
	var purgedVersion int64 = 0
	var outRecord *Record
	var bizResult ResultCode = ResultSuccess
	err := db.ExecInTransaction(func(tx *sql.Tx) error {
		// Existence check must happen within the same transaction: avoid TOCTOU window
		record := &Record{}
		querySql := fmt.Sprintf("SELECT "+recordColumns+" FROM record_%d WHERE uuid=?", userId)
		queryErr := tx.QueryRow(querySql, uuid).Scan(record.scanTargets()...)
		if queryErr != nil {
			if errors.Is(queryErr, sql.ErrNoRows) {
				bizResult = ResultErrorRecordNotFound
				return nil
			}
			return queryErr
		}
		outRecord = record

		// Idempotent: repeated deletion of the same uuid returns the current tombstone directly, no version consumed
		if record.DeleteAt > 0 {
			return nil
		}

		version, err := db.IncrementUserVersion(tx, userId)
		if err != nil {
			return err
		}

		if (version % 1000) == 0 {
			purgedVersion = version
			if _, err := tx.Exec("UPDATE user SET purgedVersion=? WHERE id=?", purgedVersion, userId); err != nil {
				return err
			}
			if _, err := tx.Exec(fmt.Sprintf("DELETE FROM record_%d WHERE deleteAt > 0 AND version <= ?", userId), purgedVersion); err != nil {
				return err
			}
		}

		sqlStmt := fmt.Sprintf("UPDATE record_%d SET deleteAt=?, version=? WHERE uuid=?", userId)
		if _, err := tx.Exec(sqlStmt, now, version, uuid); err != nil {
			return err
		}
		record.DeleteAt = now
		record.Version = version
		return nil
	})
	if err != nil {
		return nil, 0, ResultCodeError(nil, ResultErrorDatabase, err)
	}
	if bizResult != ResultSuccess {
		return nil, 0, bizResult
	}
	return outRecord, purgedVersion, ResultSuccess
}

func (db *DB) GetRecord(userId int64, uuid string) (*Record, ResultCode) {
	sqlStmt := fmt.Sprintf("SELECT "+recordColumns+" FROM record_%d WHERE uuid=?", userId)
	record := &Record{}
	err := db.conn.QueryRow(sqlStmt, uuid).Scan(record.scanTargets()...)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ResultErrorRecordNotFound
		}
		return nil, ResultErrorDatabase.with(err.Error())
	}
	return record, ResultSuccess
}

func (db *DB) QueryRecords(userId int64) ([]*Record, ResultCode) {
	sqlStmt := fmt.Sprintf("SELECT "+recordColumns+" FROM record_%d WHERE deleteAt = 0 ORDER BY createAt ASC", userId)
	rows, err := db.conn.Query(sqlStmt)
	if err != nil {
		return nil, ResultErrorDatabase.with(err.Error())
	}
	defer rows.Close()
	var records []*Record
	for rows.Next() {
		record := &Record{}
		if err := rows.Scan(record.scanTargets()...); err != nil {
			return nil, ResultErrorDatabase.with(err.Error())
		}
		records = append(records, record)
	}
	if len(records) == 0 {
		records = []*Record{}
	}
	return records, ResultSuccess
}

func (db *DB) QueryRecordsByVersion(userId int64, version, limit int64) ([]*Record, ResultCode) {
	sqlStmt := fmt.Sprintf(`
    	SELECT `+recordColumns+`
		FROM record_%d 
		WHERE version > ? ORDER BY version ASC LIMIT ?`, userId)
	rows, err := db.conn.Query(sqlStmt, version, limit)
	if err != nil {
		return nil, ResultErrorDatabase.with(err.Error())
	}
	defer rows.Close()
	var records []*Record
	for rows.Next() {
		record := &Record{}
		if err := rows.Scan(record.scanTargets()...); err != nil {
			return nil, ResultErrorDatabase.with(err.Error())
		}
		records = append(records, record)
	}
	if len(records) == 0 {
		records = []*Record{}
	}
	return records, ResultSuccess
}
