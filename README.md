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
| Platform | Windows, macOS, Linux, Android, iOS (one codebase), responsive layout |
| Editor | AppFlowy Editor (custom fork) — block-based rich text: paragraphs, headings, lists, code blocks (with language detection), todos, links, images |
| Markdown Import | Batch import `.md` / `.txt` files — headings, lists, links, code fences (language-aware) converted to native blocks |
| Offline-first | Full local Drift (SQLite) cache — read/write without server, sync on reconnect |
| Tags | Per-record tags, virtual tag folders, filter by tag, tag editor dialog, auto-sync with tag edits |
| Reminders | Tasks with repeat modes (once / weekly / monthly / yearly), lunar calendar support, calendar view, today badge count |
| Recycle Bin | Soft delete → restore → permanently purge; capture into bin on delete, restore keeps uuid |
| Note Info | Metadata dialog: uuid, path, version, timestamps, conflict, lock status |
| Conflict UI | Auto-detect, diff view, manual resolve (keep local / keep remote) |
| Encryption | Per-note AES-256 encryption — optional, zero key storage, lost password means lost data |
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

- `GET /upgrade/check?platform=android` — query the latest version for a platform (no auth). Returns the full download URL.
- `GET /upgrade/download/{version}/{file}` — download an install package (no auth, static file serve).

`platform` values: `windows`, `linux`, `macos`, `android`, `ios`.

### Directory layout

Each release goes into its own subdirectory. The server determines the latest version by reading the root `version.ini`, then looks inside `{version}/` for platform info.

```
version/
├── version.ini                                    # latest=1.1.2
├── 1.1.2/
│   ├── version.json                               # per-platform md5 + filename
│   ├── changelog.txt                              # plain-text release notes
│   ├── note123-client-windows-x64-v1.1.2.zip
│   ├── note123-client-macos-silicon-v1.1.2.zip
│   ├── note123-client-linux-x64-v1.1.2.tar.gz
│   └── note123-android-arm64-v8a-v1.1.2.apk
└── 1.1.1/
    └── ...
```

- `version.ini` — single line `latest=X.Y.Z`, server reads this first.
- `{version}/version.json` — per-platform `{md5, file}` entries, plus top-level `updatedAt`.
- `{version}/changelog.txt` — optional plain-text release notes, returned verbatim in the check response.
- macOS platform key is `macos` (not `darwin`); server handles it the same as the others.
- iOS is accepted as a platform key but no macOS/iOS package is produced by the build scripts.

### version.ini and version.json format

**version.ini** — one line:
```ini
latest=1.1.2
```

**version.json** inside a version subdirectory:
```json
{
  "updatedAt": "2026-10-12T21:49:26Z",
  "windows": {
    "md5": "0AB9CC48BB1777B9657F245D67ECA0AF",
    "file": "note123-client-windows-x64-v1.1.2.zip"
  },
  "linux": {
    "md5": "476123BE55F4B5C9E2B8E47FED54A6B5",
    "file": "note123-client-linux-x64-v1.1.2.tar.gz"
  },
  "android": {
    "md5": "7CFD9EF9F65F301AA20DED96EDD72BE3",
    "file": "note123-android-arm64-v8a-v1.1.2.apk"
  },
  "macos": {
    "md5": "EC4492A621F29E00CA04138F3CC1E4FE",
    "file": "note123-client-macos-silicon-v1.1.2.zip"
  }
}
```

Notes:
- `md5`: uppercase MD5 of the install package, returned to the client for integrity checks.
- `file`: filename inside the version subdirectory; the server builds the download URL as `/upgrade/download/{version}/{file}`.
- `updatedAt`: optional metadata field, the server doesn't consume it.

### Publishing a new release

Run `pack/publish_release.ps1` with a git tag and the server's version directory:
```powershell
powershell -ExecutionPolicy Bypass -File pack\publish_release.ps1 -Version 1.1.2 -ServerVersionDir 'Y:\note123\version'
```

The script:
1. Tags the repo and pushes → GitHub Actions builds all packages.
2. Waits for CI, downloads artifacts to `pack/build/{version}/`.
3. Generates `version.json` + `changelog.txt` from the GitHub Release body.
4. Writes `version.ini` (`latest={version}`).
5. Copies the whole release directory plus the updated `version.ini` to the server.

No server restart is needed after copying — the next client check picks up the new `version.ini` and reads the new subdirectory automatically.

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
| GET | `/upgrade/download/{version}/{file}` | Download install package (static file) | No |
| POST | `/admin/login` | Admin login | No |
| GET | `/admin` | Admin UI | No (session cookie) |

---

## License

MIT
