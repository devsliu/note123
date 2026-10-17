package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Share files are stored under {recordsFolder}/user_{id}/share/ named {uuid}.{random16}.{unixTime}.{lifeSeconds}.
// The download URL is /note/d/{userId}/{title}.md?token={base64}, where the token is AES-GCM(filename) keyed by
// the owning user's stored password hash. Expiry and identity are both encoded in the filename — no state required.
// Expired files are removed lazily: each new share by the same user sweeps the folder.

const (
	shareMinLife = int64(60)             // 1 minute
	shareMaxLife = int64(30 * 24 * 3600) // 30 days
)

func (s *Server) getShareFolder(userId int64) string {
	return filepath.Join(s.recordsFolder, "user_"+strconv.FormatInt(userId, 10), "share")
}

// shareKey derives a 32-byte AES key from the user's stored password hash.
// Using the per-user password means changing the password revokes all of that user's share links.
func shareKey(passwordHash string) []byte {
	k := sha256.Sum256([]byte(passwordHash))
	return k[:]
}

// encryptShareName encrypts the share filename with AES-256-GCM and returns a URL-safe base64 token.
// A random 12-byte nonce is prepended to the ciphertext before encoding.
func encryptShareName(name string, key []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}
	ct := gcm.Seal(nonce, nonce, []byte(name), nil)
	return base64.RawURLEncoding.EncodeToString(ct), nil
}

// decryptShareName reverses encryptShareName.
func decryptShareName(token string, key []byte) (string, error) {
	raw, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(raw) < gcm.NonceSize() {
		return "", io.ErrUnexpectedEOF
	}
	nonce, ct := raw[:gcm.NonceSize()], raw[gcm.NonceSize():]
	pt, err := gcm.Open(nil, nonce, ct, nil)
	if err != nil {
		return "", err
	}
	return string(pt), nil
}

// parseShareName splits {uuid}.{random16}.{unixTime}.{lifeSeconds}; returns ok=false on malformed names.
// The uuid prefix lets record deletion clean up all shares of that record.
func parseShareName(name string) (string, int64, int64, bool) {
	parts := strings.Split(name, ".")
	if len(parts) != 4 || !isValidRecordUUID(parts[0]) || len(parts[1]) != 16 {
		return "", 0, 0, false
	}
	if _, err := hex.DecodeString(parts[1]); err != nil {
		return "", 0, 0, false
	}
	unixTime, err1 := strconv.ParseInt(parts[2], 10, 64)
	life, err2 := strconv.ParseInt(parts[3], 10, 64)
	if err1 != nil || err2 != nil || unixTime <= 0 || life <= 0 {
		return "", 0, 0, false
	}
	return parts[0], unixTime, life, true
}

// deleteSharesByRecord removes every share file that belongs to the given record uuid.
func (s *Server) deleteSharesByRecord(userId int64, uuid string) {
	folder := s.getShareFolder(userId)
	matches, err := filepath.Glob(filepath.Join(folder, uuid+".*"))
	if err != nil {
		return
	}
	for _, m := range matches {
		os.Remove(m)
	}
}

// sweepExpiredShares deletes expired share files in the user's share folder.
func (s *Server) sweepExpiredShares(userId int64) {
	folder := s.getShareFolder(userId)
	entries, err := os.ReadDir(folder)
	if err != nil {
		return
	}
	now := time.Now().Unix()
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		_, unixTime, life, ok := parseShareName(e.Name())
		if ok && unixTime+life <= now {
			os.Remove(filepath.Join(folder, e.Name()))
		}
	}
}

// shareUploadHandler accepts a markdown file plus life (seconds) and returns the download URL.
func (s *Server) shareUploadHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	uuid := r.URL.Query().Get("uuid")
	if !isValidRecordUUID(uuid) {
		http.Error(w, "invalid uuid", ResultErrorParams.Value)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, s.maxFileSize)

	file, _, formFileErr := r.FormFile("file")
	if formFileErr != nil {
		http.Error(w, "file required or exceeds "+strconv.FormatInt(s.maxFileSize>>20, 10)+"MB limit", ResultErrorParams.Value)
		return
	}
	defer file.Close()

	life, err := getFormInt64(r, "life")
	if err != nil || life < shareMinLife || life > shareMaxLife {
		http.Error(w, "invalid life", ResultErrorParams.Value)
		return
	}

	// Lazy cleanup: piggyback expired-share removal on this user's share request
	s.sweepExpiredShares(user.UserID)

	dbUser, err := s.db.GetUserByID(user.UserID)
	if err != nil {
		http.Error(w, "user not found", ResultErrorParams.Value)
		return
	}
	// Filename: {uuid}.{random16}.{time}.{life} — uuid prefix enables cleanup on record delete,
	// random16 keeps links unguessable even for the same record shared multiple times
	tokenBytes := make([]byte, 8)
	if _, err := rand.Read(tokenBytes); err != nil {
		http.Error(w, err.Error(), ResultErrorFileSave.Value)
		return
	}
	name := uuid + "." + hex.EncodeToString(tokenBytes) + "." + strconv.FormatInt(time.Now().Unix(), 10) + "." + strconv.FormatInt(life, 10)
	absPath := filepath.Join(s.getShareFolder(user.UserID), name)
	if err := os.MkdirAll(filepath.Dir(absPath), 0755); err != nil {
		http.Error(w, err.Error(), ResultErrorFileSave.Value)
		return
	}
	tmp, err := os.CreateTemp(filepath.Dir(absPath), name+".*.tmp")
	if err != nil {
		http.Error(w, err.Error(), ResultErrorFileSave.Value)
		return
	}
	tmpPath := tmp.Name()
	if _, err := io.Copy(tmp, file); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		http.Error(w, err.Error(), ResultErrorFileSave.Value)
		return
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpPath)
		http.Error(w, err.Error(), ResultErrorFileSave.Value)
		return
	}
	if err := os.Rename(tmpPath, absPath); err != nil {
		os.Remove(tmpPath)
		http.Error(w, err.Error(), ResultErrorFileSave.Value)
		return
	}

	encToken, err := encryptShareName(name, shareKey(dbUser.Password))
	if err != nil {
		http.Error(w, err.Error(), ResultErrorFileSave.Value)
		return
	}

	// Path segment after userId is purely cosmetic (the note title shown to viewers);
	// the real on-disk filename is recovered from the encrypted token query param.
	display := strings.TrimSpace(r.FormValue("title"))
	display = strings.Map(func(r rune) rune {
		switch r {
		case '/', '\\', '?', '#', '&', '=', ' ', '\t', '\n', '\r', ':':
			return '_'
		}
		return r
	}, display)
	if display == "" {
		display = "note"
	}

	w.Header().Set("content-type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"url": "/note/d/" + strconv.FormatInt(user.UserID, 10) + "/" + display + ".md?token=" + encToken,
	})
}

// shareDownloadHandler serves a shared file when the token decrypts and the file is not expired.
// Route: /note/d/{userId}/{anyName}.md?token={base64}, no login required.
// The {anyName} path segment is cosmetic; the actual filename is recovered by decrypting the token.
func (s *Server) shareDownloadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	rest := strings.TrimPrefix(r.URL.Path, "/note/d/")
	slash := strings.Index(rest, "/")
	if slash <= 0 {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}
	userId, err := strconv.ParseInt(rest[:slash], 10, 64)
	if err != nil {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}

	dbUser, err := s.db.GetUserByID(userId)
	if err != nil {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}
	name, err := decryptShareName(token, shareKey(dbUser.Password))
	if err != nil {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}
	id, unixTime, life, ok := parseShareName(name)
	if !ok {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}
	if unixTime+life <= time.Now().Unix() {
		http.Error(w, "link expired", http.StatusGone)
		return
	}
	// The owning user is known from the URL, so no glob scan is needed
	absPath := filepath.Join(s.getShareFolder(userId), name)
	f, err := os.Open(absPath)
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	defer f.Close()

	w.Header().Set("content-type", "text/markdown; charset=utf-8")
	w.Header().Set("content-disposition", "inline; filename=\""+id+".md\"")
	http.ServeContent(w, r, id+".md", time.Now(), f)
}
