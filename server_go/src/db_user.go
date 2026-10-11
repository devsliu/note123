package main

import (
	"database/sql"
	"fmt"
	"time"
)

type User struct {
	ID            int64  `json:"id"`
	Name          string `json:"name"`
	Password      string `json:"password"`
	CreateAt      int64  `json:"createAt"`
	Version       int64  `json:"version"`       // incremented whenever user data changes
	PurgedVersion int64  `json:"purgedVersion"` // highest purged record version, default 0
}

// APIStat API call statistics
type APIStat struct {
	APIName      string `json:"apiName"`
	Count        int64  `json:"count"`
	LastCallTime int64  `json:"lastCallTime"`
}

func createAPIStatTableSql(userId int64) string {
	return fmt.Sprintf(`
		CREATE TABLE IF NOT EXISTS apiStat_%d (
			apiName TEXT PRIMARY KEY,
			count INTEGER NOT NULL DEFAULT 0,
			lastCallTime INTEGER NOT NULL DEFAULT 0
		);`, userId)
}

// CreateUser registers a user; creates the user row, record_N table, and apiStat_N table in a single transaction
func (db *DB) CreateUser(name, password string) (*User, error) {
	now := time.Now().UnixMilli()
	var user *User
	err := db.ExecInTransaction(func(tx *sql.Tx) error {
		res, err := tx.Exec("INSERT INTO user(name, password, createAt) VALUES (?, ?, ?)", name, password, now)
		if err != nil {
			return err
		}
		userId, err := res.LastInsertId()
		if err != nil {
			return err
		}
		if _, err := tx.Exec(createRecordTableSql(userId)); err != nil {
			return err
		}
		if _, err := tx.Exec(createAPIStatTableSql(userId)); err != nil {
			return err
		}
		user = &User{
			ID:            userId,
			Name:          name,
			Password:      password,
			CreateAt:      now,
			PurgedVersion: 0,
			Version:       0,
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return user, nil
}

// DeleteUser cascades deletion of the user row + record_N table + apiStat_N table
func (db *DB) DeleteUser(id int64) error {
	return db.ExecInTransaction(func(tx *sql.Tx) error {
		if _, err := tx.Exec(dropRecordTableSql(id)); err != nil {
			return err
		}
		if _, err := tx.Exec(fmt.Sprintf("DROP TABLE IF EXISTS apiStat_%d;", id)); err != nil {
			return err
		}
		if _, err := tx.Exec("DELETE FROM user WHERE id=?", id); err != nil {
			return err
		}
		return nil
	})
}

func (db *DB) GetUserByID(id int64) (*User, error) {
	user := &User{}
	err := db.conn.QueryRow("SELECT id, name, password, createAt, purgedVersion, version FROM user WHERE id = ?", id).
		Scan(&user.ID, &user.Name, &user.Password, &user.CreateAt, &user.PurgedVersion, &user.Version)
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (db *DB) GetUserByNamePass(name, password string) (*User, error) {
	user := &User{}
	err := db.conn.QueryRow("SELECT id, name, password, createAt, purgedVersion, version FROM user WHERE name = ? AND password = ?", name, password).
		Scan(&user.ID, &user.Name, &user.Password, &user.CreateAt, &user.PurgedVersion, &user.Version)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// UpdateUser updates name/password. When password is empty, only name is updated; original password hash is preserved
func (db *DB) UpdateUser(id int64, name, password string) error {
	if password == "" {
		_, err := db.conn.Exec("UPDATE user SET name=? WHERE id=?", name, id)
		return err
	}
	_, err := db.conn.Exec("UPDATE user SET name=?, password=? WHERE id=?", name, password, id)
	return err
}

func (db *DB) UpdateUserPurgedVersion(id, purgedVersion int64) error {
	_, err := db.conn.Exec("UPDATE user SET purgedVersion=? WHERE id=?", purgedVersion, id)
	return err
}

// IncrementUserVersion increments the user version by 1 within the given transaction and returns the new version.
func (db *DB) IncrementUserVersion(tx *sql.Tx, id int64) (int64, error) {
	var newVersion int64
	if err := tx.QueryRow("UPDATE user SET version = version + 1 WHERE id = ? RETURNING version", id).Scan(&newVersion); err != nil {
		return 0, err
	}
	return newVersion, nil
}

// ListUsers lists all users
func (db *DB) ListUsers() ([]User, error) {
	rows, err := db.conn.Query("SELECT id, name, password, createAt, purgedVersion, version FROM user")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var users []User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Name, &u.Password, &u.CreateAt, &u.PurgedVersion, &u.Version); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	if len(users) == 0 {
		users = []User{}
	}
	return users, nil
}

// ---- API Stat ----

// UpdateAPIStat updates API call statistics
func (db *DB) UpdateAPIStat(userId int64, apiName string) error {
	now := time.Now().UnixMilli()
	sqlStmt := fmt.Sprintf(`INSERT INTO apiStat_%d (apiName, count, lastCallTime) VALUES (?, 1, ?)
		ON CONFLICT(apiName) DO UPDATE SET count = count + 1, lastCallTime = ?`, userId)
	_, err := db.conn.Exec(sqlStmt, apiName, now, now)
	return err
}

// QueryAPIStats queries all API statistics
func (db *DB) QueryAPIStats(userId int64) ([]*APIStat, error) {
	sqlStmt := fmt.Sprintf("SELECT apiName, count, lastCallTime FROM apiStat_%d", userId)
	rows, err := db.conn.Query(sqlStmt)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var stats []*APIStat
	for rows.Next() {
		var stat APIStat
		if err := rows.Scan(&stat.APIName, &stat.Count, &stat.LastCallTime); err != nil {
			return nil, err
		}
		stats = append(stats, &stat)
	}
	if len(stats) == 0 {
		stats = []*APIStat{}
	}
	return stats, nil
}
