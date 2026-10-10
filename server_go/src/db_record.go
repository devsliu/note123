package main

import (
	"database/sql"
	"errors"
	"fmt"
	"time"
)

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

// UpsertRecord inserts or updates a record.
// baseVersion is the server-side version known locally by the client (pass 0 for a new record).
// If the current server version > baseVersion, another device has already pushed; return ResultErrorRecordConflict.
func (db *DB) UpsertRecord(userId int64, uuid, path, name, md5, reminder string, createAt, editAt, fileEditAt, locked, baseVersion int64) (*Record, ResultCode) {
	var resultRecord *Record
	var conflictRecord *Record
	var bizResult ResultCode = ResultSuccess
	err := db.ExecInTransaction(func(tx *sql.Tx) error {
		// Conflict detection: reject overwrite when server version > client baseVersion
		exist := &Record{}
		querySql := fmt.Sprintf("SELECT "+recordColumns+" FROM record_%d WHERE uuid=?", userId)
		if qErr := tx.QueryRow(querySql, uuid).Scan(exist.scanTargets()...); qErr == nil {
			if exist.Version > baseVersion {
				conflictRecord = exist
				bizResult = ResultErrorRecordConflict
				return nil
			}
		}
		// Version increment and row update must happen in the same transaction and same connection
		version, err := db.IncrementUserVersion(tx, userId)
		if err != nil {
			return err
		}
		// New row with file content starts at fileVersion 1, otherwise 0
		insertFileVersion := int64(0)
		if md5 != "" {
			insertFileVersion = 1
		}
		sqlStmt := fmt.Sprintf(`
			INSERT INTO record_%d (`+recordColumns+`)
			VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?)
			ON CONFLICT(uuid) DO UPDATE SET
				path=excluded.path,
				name=excluded.name,
				md5=CASE WHEN excluded.md5 != '' THEN excluded.md5 ELSE record_%d.md5 END,
				editAt=excluded.editAt,
				version=excluded.version,
				deleteAt=0,
				createAt=excluded.createAt,
				fileEditAt=CASE WHEN excluded.fileEditAt > 0 THEN excluded.fileEditAt ELSE record_%d.fileEditAt END,
				fileVersion=CASE WHEN excluded.md5 != '' AND excluded.md5 != record_%d.md5 THEN record_%d.fileVersion + 1 ELSE record_%d.fileVersion END,
				locked=excluded.locked,
				reminder=excluded.reminder
		`, userId, userId, userId, userId, userId, userId)
		_, err = tx.Exec(sqlStmt, uuid, path, name, md5, version, createAt, editAt, fileEditAt, insertFileVersion, locked, reminder)
		if err != nil {
			return err
		}
		resultRecord = &Record{}
		return tx.QueryRow(fmt.Sprintf("SELECT "+recordColumns+" FROM record_%d WHERE uuid=?", userId), uuid).Scan(resultRecord.scanTargets()...)
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
