# Note123

> Self-hosted notes sync — Go + SQLite (**zero infrastructure**) + Flutter client.
> Cross-platform: Windows · Linux · macOS · Android · iOS.
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
| Windows/Linux client | **~15 MB** |
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
cd server_go/src
go mod download
go run .
```

**Client:**
```bash
cd client_flutter
flutter pub get
flutter run
```

### Local Service Config

```ini
[NOTE]
NOTE_PORT = 10001
NOTE_DATA_DIR = D://test/
NOTE_VERSION_DIR = D://test/version
NOTE_ADMIN_USER = admin
NOTE_ADMIN_PASS = admin
NOTE_MAX_DEVICES = 5
NOTE_MAX_FILE_SIZE = 100
```

**Parameters:**
- `NOTE_ADMIN_USER` / `NOTE_ADMIN_PASS`: Admin UI login credentials
- `NOTE_PORT`: HTTP listen port (default 10001)
- `NOTE_DATA_DIR`: Data directory for SQLite and uploaded files
- `NOTE_VERSION_DIR`: Client update directory holding platform packages and `versions.json` (default `./version`)
- `NOTE_MAX_DEVICES`: Max active tokens per account, oldest kicked when exceeded
- `NOTE_MAX_FILE_SIZE`: Max file upload size per record, in MB (default 100)
- Env vars with the same names take precedence over config.ini when `NOTE_ADMIN_USER` is set

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
      - NOTE_VERSION_DIR=/app/version
      - NOTE_ADMIN_USER=admin
      - NOTE_ADMIN_PASS=admin
      - NOTE_MAX_DEVICES=5
      - NOTE_MAX_FILE_SIZE=100
    volumes:
      - ./note123:/app/data
      - ./version:/app/version
    restart: always
```

### First Run

1. Start the server, then open `http://host:port/admin` in a browser
2. Login with the admin credentials configured above
3. Create a user account (username + password) in the Admin panel
4. Open the Note123 client → **Settings** → enter the server URL (e.g. `http://your-server:10001`) and the username/password you just created
5. Login and start syncing notes across all your devices

---

## Client Update Deployment

Clients check for and download updates from **Settings → Version**. Update files live in the directory pointed to by `NOTE_VERSION_DIR` (`./version` volume in Docker).

### Check and download endpoints

- `GET /upgrade/check?platform=android` — query the latest version for a platform (no auth)
- `GET /upgrade/download/<file>` — download an install package (no auth)

`platform` values: `windows`, `linux`, `android`, `ios`.

### Directory layout

```
version/
├── versions.json                              # version manifest
├── note123-client-windows-x64.zip             # Windows package
├── note123-client-linux-x64-v1.0.1.tar.gz     # Linux package
└── note123-android-arm64-v8a.apk              # Android APK
```

- Windows: downloads the zip, extracts it over the install directory, then restarts automatically
- Android: downloads the APK and opens the system installer
- iOS: not served here; updates go through the App Store
- Platforms missing from the directory are simply absent from check results

### versions.json format

The top-level `versions` array holds changelog shared across platforms (entry 0 is used). Other keys match `platform` values and hold per-platform package info:

```json
{
  "versions": [
    {
      "version": "v1.0.1",
      "versionCode": 2,
      "changelog": "- feat: add layout mode switch\n- fix: sync issue",
      "updatedAt": "2026-10-09T12:00:00Z"
    }
  ],
  "windows": {
    "version": "v1.0.1",
    "versionCode": 2,
    "md5": "9E107D9D372BB6826BD81D3542A419D6",
    "file": "note123-client-windows-x64.zip",
    "updatedAt": "2026-10-09T12:00:00Z"
  },
  "linux": {
    "version": "v1.0.1",
    "versionCode": 2,
    "md5": "...",
    "file": "note123-client-linux-x64-v1.0.1.tar.gz",
    "updatedAt": "2026-10-09T12:00:00Z"
  },
  "android": {
    "version": "v1.0.1",
    "versionCode": 2,
    "md5": "...",
    "file": "note123-android-arm64-v8a.apk",
    "updatedAt": "2026-10-09T12:00:00Z"
  }
}
```

Field notes:

- `versionCode`: integer build number used for comparison, must increase with every release
- `md5`: package MD5 (uppercase) for integrity checks
- `file`: filename inside `NOTE_VERSION_DIR`, also used as the download path
- Shipping a new release only requires replacing the package and updating/adding the platform entry — no server restart needed

On Windows, build with `pack/build_*.bat` and generate/update `versions.json` with `pack/update_versions_json.ps1`.

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
| GET | `/upgrade/check` | Check for client updates (`platform` param) | No |
| GET | `/upgrade/download/{file}` | Download install package | No |
| POST | `/admin/login` | Admin login | No |
| GET | `/admin` | Admin UI | No (session cookie) |

---

## License

MIT
