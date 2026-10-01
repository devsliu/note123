package main

import (
	_ "embed"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"gopkg.in/ini.v1"
)

//go:embed version.txt
var versionFile string

// readVersion reads the version string from the embedded version file
func readVersion() string {
	return strings.TrimSpace(versionFile)
}

func getEnvOrDefault(key, def string) string {
	val := os.Getenv(key)
	if val == "" {
		return def
	}
	return val
}

// parseMaxFileSize parses an MB string (e.g. "100") into bytes; fallback to default on invalid input
func parseMaxFileSizeMB(s string, def int64) int64 {
	n, err := strconv.ParseInt(s, 10, 64)
	if err != nil || n <= 0 {
		return def
	}
	return n << 20
}

func readArgsFromEnv() (string, string, string, string, int, int64) {
	port := getEnvOrDefault("NOTE_PORT", "10001")
	if port[0] != ':' {
		port = ":" + port
	}
	dir := getEnvOrDefault("NOTE_DATA_DIR", "./data")
	adminUser := getEnvOrDefault("NOTE_ADMIN_USER", "admin")
	adminPass := getEnvOrDefault("NOTE_ADMIN_PASS", "admin")
	maxDevices, _ := strconv.Atoi(getEnvOrDefault("NOTE_MAX_DEVICES", "3"))
	if maxDevices <= 0 {
		maxDevices = 1
	}
	maxFileSize := parseMaxFileSizeMB(os.Getenv("NOTE_MAX_FILE_SIZE"), 100<<20)

	return port, dir, adminUser, adminPass, maxDevices, maxFileSize
}

func readArgsFromInit() (string, string, string, string, int, int64) {
	cfg, err := ini.Load("config.ini")
	if err != nil {
		log.Printf("WARN: config.ini load failed (%v), using built-in defaults", err)
		return ":10001", "./data", "admin", "admin", 3, 100 << 20
	}
	s := cfg.Section("NOTE")
	port := s.Key("NOTE_PORT").MustString("10001")
	if port[0] != ':' {
		port = ":" + port
	}
	dir := s.Key("NOTE_DATA_DIR").MustString("./data")
	adminUser := s.Key("NOTE_ADMIN_USER").MustString("admin")
	adminPass := s.Key("NOTE_ADMIN_PASS").MustString("admin")
	maxDevices, _ := s.Key("NOTE_MAX_DEVICES").Int()
	if maxDevices <= 0 {
		maxDevices = 3
	}
	maxFileSize := parseMaxFileSizeMB(s.Key("NOTE_MAX_FILE_SIZE").MustString("100"), 100<<20)

	return port, dir, adminUser, adminPass, maxDevices, maxFileSize
}

func main() {
	log.Println("note123 server version:", readVersion())

	var port, dir, adminUser, adminPass = "", "", "", ""
	var maxDevices int
	var maxFileSize int64
	if os.Getenv("NOTE_ADMIN_USER") == "" {
		port, dir, adminUser, adminPass, maxDevices, maxFileSize = readArgsFromInit()
		log.Println("Loaded args from config.ini:", port, dir, adminUser, adminPass, "maxDevices=", maxDevices, "maxFileSize(MB)=", maxFileSize>>20)
	} else {
		port, dir, adminUser, adminPass, maxDevices, maxFileSize = readArgsFromEnv()
		log.Println("Loaded args from env:", port, dir, adminUser, adminPass, "maxDevices=", maxDevices, "maxFileSize(MB)=", maxFileSize>>20)
	}

	os.MkdirAll(dir, 0755)
	dbPath := filepath.Join(dir, "records.db")

	db, err := NewDB(dbPath)
	if err != nil {
		log.Fatal("Failed to initialize database:", err)
	}
	defer db.Close()

	err = StartHTTPServer(db, dir, port, adminUser, adminPass, maxDevices, maxFileSize)
	if err != nil {
		log.Fatal("Failed to start HTTP server:", err)
	}
}
