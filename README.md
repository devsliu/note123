# Note123

> Self-hosted notes sync — Go + SQLite (**zero infrastructure**) + Flutter client.
> Version control, conflict resolution, and tombstone cleanup.
> Suitable for personal and small team deployments.

[中文文档](README_CN.md)

---

## Why Note123?

Three design choices keep Note123 lean and simple:

- **Single Go binary** — The server compiles to one file. No runtime, no interpreter, millisecond cold start
- **Embedded SQLite** — No database process, no connection pool tuning, your data is one `.db` file
- **Zero interpreted languages** — No JS, no Electron, no Node, no WebView, no HTML. Pure compiled code

Core design:

- **File-level version control** — `fileVersion` + MD5 integrity check
- **Incremental sync with version vectors** — pulls only what changed since your last sync
- **Automatic tombstone cleanup** — deletes remote records older than `purgedVersion`, preventing deleted records from accumulating indefinitely
- **Optimistic concurrency with TOCTOU protection** — baseVersion check both at HTTP handler AND inside DB transaction
- **Per-note encryption** — optional AES-256, zero key storage — lost password means lost data

---

## Size & Footprint

| Artifact | Size |
|---|---|
| Server binary (Linux) | **9.3 MB** |
| Docker container memory | **~12 MB** |
| Windows client | **~15 MB** |
| Android APK | **~24 MB** |

---

## Features

### Server (Go)

| Feature | Detail |
|---|---|
| Storage | Single SQLite file, per-user tables |
| Auth | Random token (32 bytes hex), 30-day TTL, in-memory cache |
| Multi-device | Max N active tokens per account (default 3), oldest kicked when exceeded |
| Token expiry | 401 + `X-Auth-Reason` header distinguishes "expired" vs "invalid", client auto-relogin |
| Sync Protocol | Version vector (version + purgedVersion), incremental pull, full pull on purge |
| Conflict | baseVersion check, HTTP handler pre-check + DB transaction re-check |
| Resource Protection | MaxBytesReader (100MB), UUID validation against path traversal |
| Admin UI | Built-in HTML, session cookie + SameSite=Strict — `http://host:7000/admin` |
| HTTPS | Server speaks plain HTTP. Add Nginx / Caddy reverse proxy if you need HTTPS |

### Client (Flutter)

| Feature | Detail |
|---|---|
| Platform | Windows, macOS, Linux, Android, iOS (one codebase) |
| Editor | AppFlowy Editor (custom fork) — block-based rich text: paragraphs, headings, lists, code blocks (with language detection), todos, links, images |
| Markdown Import | Batch import `.md` / `.txt` files — headings, lists, links, code fences (language-aware) converted to native blocks |
| Offline-first | Full local Drift (SQLite) cache — read/write without server, sync on reconnect |
| Conflict UI | Auto-detect, diff view, manual resolve |
| Local Storage | Drift (SQLite) — DB itself is the outbox, no separate queue table needed |
| File Cache | work/base dual files — work for edits, base for downloaded originals |
| Auth Storage | SharedPreferences stores userId / token / password |
| Error Handling | errorCode → l10n text mapping, auth failure auto-opens login dialog |
| i18n | Chinese / English |

---

## Quick Start

### Build from source

**Server:**
```bash
cd server_go
go mod download
go run main.go
```

**Client:**
```bash
cd client_flutter
flutter pub get
flutter run
```

### Local Service Config

```ini
[admin]
username = admin
password = admin

[storage]
dir = D://test/

[server]
port = 10001
maxDevices = 5
maxFileSize = 100
```

**Parameters:**
- `admin.username` / `admin.password`: Admin UI login credentials
- `server.maxDevices`: Max active tokens per account, oldest kicked when exceeded
- `server.maxFileSize`: Max file upload size per record, in MB (default 100)

### Docker Service Config

```yaml
version: "3"
services:
  server:
    image: note123:v1.0.0
    user: "0:0"
    ports:
      - "7000:10001"
    environment:
      - NOTE_PORT=10001
      - NOTE_DATA_DIR=/app/data
      - NOTE_ADMIN_USER=admin
      - NOTE_ADMIN_PASS=admin
      - NOTE_MAX_DEVICES=5
      - NOTE_MAX_FILE_SIZE=100
    volumes:
      - ./note123:/app/data
    restart: always
```

### First Run

1. Start the server, then open `http://host:port/admin` in a browser
2. Login with the admin credentials configured above
3. Create a user account (username + password) in the Admin panel
4. Open the Note123 client → **Settings** → enter the server URL (e.g. `http://your-server:10001`) and the username/password you just created
5. Login and start syncing notes across all your devices

---

## API

Auth-required APIs need headers: `X-User-Id` + `X-Token`.

| Method | Path | Description | Auth |
|---|---|---|---|
| POST | `/user/register` | Register user | No |
| POST | `/user/login` | Login, get token | No |
| POST | `/record/update` | Create or update record (baseVersion for conflict) | Yes |
| POST | `/record/delete` | Delete record | Yes |
| GET | `/record/list` | Query records (incremental pull by version) | Yes |
| GET | `/record/download` | Download record file | Yes |
| POST | `/record/clear` | Clear all records for current user | Yes |
| GET | `/api_stat/list` | Query API call statistics | Yes |
| POST | `/admin/login` | Admin login | No |
| GET | `/admin` | Admin UI | No (session cookie) |

---

## License

MIT
