# Note123

> 自托管笔记同步 — Go + SQLite（**零基础设施**）+ Flutter 客户端。
> 跨平台：Windows · Linux · macOS · Android · iOS。
> 版本控制、冲突解决、墓碑清理。
> 适合个人和小团队部署使用。

[English](README.md)

---

## 为什么选 Note123？

三个设计选择保持 Note123 轻量简洁：

- **Go 单二进制** — 服务端编译出来就是一个文件，没有运行时，没有解释器，冷启动毫秒级
- **嵌入式 SQLite** — 没有数据库进程，没有连接池调优，数据就是一个 `.db` 文件
- **零解释型语言** — 没有 JS、没有 Electron、没有 Node、没有 WebView、没有 HTML，全编译型代码

核心设计：

- **文件级版本控制** — `fileVersion` + MD5 完整性校验
- **增量同步版本向量** — 只拉取上次同步后有变化的部分
- **自动墓碑清理** — 清理 `purgedVersion` 之前的远端条目，防止删除记录无限堆积
- **TOCTOU 防护** — baseVersion 在 HTTP handler 和 DB 事务内双重校验
- **单笔记加密** — 每条笔记可选 AES-256 加密，密钥零存储，忘记密码即无法解密

---

## 体积与占用

| 产物 | 大小 |
|---|---|
| 服务端二进制 (Linux) | **9.3 MB** |
| Docker 容器内存 | **~12 MB** |
| Windows/Linux 客户端 | **~15 MB** |
| Android APK | **~24 MB** |

---

## 特性

### 服务端 (Go)

| 特性 | 说明 |
|---|---|
| 存储 | 单个 SQLite 文件，按用户分表 |
| 鉴权 | 随机 token（32 字节 hex），30 天 TTL，内存缓存 |
| 多设备 | 同账号最多保留 N 个活跃 token（默认 3），超出踢最老 |
| Token 失效 | 401 + X-Auth-Reason 头区分"过期"和"无效"，客户端自动 relogin |
| 同步协议 | 版本向量 (version + purgedVersion)，增量拉取，purge 时全量重拉 |
| 冲突检测 | baseVersion 乐观锁，HTTP handler 预检 + DB 事务内再检 |
| 资源保护 | MaxBytesReader (100MB)，UUID 校验防路径穿越 |
| 管理界面 | 内置 HTML，Session Cookie + SameSite=Strict — `http://host:7000/admin` |
| HTTPS | 服务端纯 HTTP，如需 HTTPS 可自行部署 Nginx / Caddy 反代 |

### 客户端 (Flutter)

| 特性 | 说明 |
|---|---|
| 平台 | Windows, macOS, Linux, Android, iOS（一套代码） |
| 编辑器 | AppFlowy Editor（自定义 fork）— 块级富文本：段落、标题、列表、代码块（自动识别语言）、待办、链接、图片 |
| Markdown 导入 | 批量导入 `.md` / `.txt` 文件 — 标题、列表、链接、代码围栏（语言识别）转为原生块 |
| 离线可用 | 本地优先 — 完整 Drift (SQLite) 缓存，无网络可读写，重连自动同步（需先登录） |
| 冲突 UI | 自动检测，Diff 视图，手动解决 |
| 本地存储 | Drift (SQLite) — DB 本身就是 outbox，不需要额外队列表 |
| 文件缓存 | work/ + base/ 双文件 — work 放编辑稿，base 放下载原件 |
| 鉴权持久化 | SharedPreferences 存 userId / token / 密码 |
| 错误处理 | errorCode → l10n 文案映射，登录失效自动弹登录框 |
| 国际化 | 中文 / 英文 |

---

## 快速开始

### 源码构建

**服务端:**
```bash
cd server_go/src
go mod download
go run .
```

**客户端:**
```bash
cd client_flutter
flutter pub get
flutter run
```

### 本地服务配置文件

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

**参数说明:**
- `NOTE_ADMIN_USER` / `NOTE_ADMIN_PASS`: 管理界面登录凭据
- `NOTE_PORT`: HTTP 监听端口（默认 10001）
- `NOTE_DATA_DIR`: 数据目录，存放 SQLite 和上传文件
- `NOTE_VERSION_DIR`: 客户端升级包目录，存放各平台安装包和 `versions.json`（默认 `./version`）
- `NOTE_MAX_DEVICES`: 同账号最多保留的活跃 token 数，超出后自动踢掉最老的 token
- `NOTE_MAX_FILE_SIZE`: 单条目最大上传文件大小，单位 MB（默认 100）
- 同名环境变量优先于 config.ini（以设置了 `NOTE_ADMIN_USER` 为准）

### Docker 服务配置文件

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

### 首次使用

1. 启动服务端，浏览器打开 `http://host:port/admin`
2. 用上面配置的 admin 账号登录
3. 在管理界面创建用户账号（用户名 + 密码）
4. 打开 Note123 客户端 → **设置** → 填入服务端地址（如 `http://your-server:10001`）和刚才创建的用户名密码
5. 登录成功，多端同步笔记

---

## 客户端版本升级部署

客户端在 **设置 → 版本** 中通过服务端检查和下载更新，升级文件统一放在 `NOTE_VERSION_DIR` 指向的目录（Docker 部署即挂载的 `./version`）。

### 检查与下载接口

- `GET /upgrade/check?platform=android` — 查询指定平台的最新版本（无需鉴权）
- `GET /upgrade/download/<file>` — 下载安装包（无需鉴权）

`platform` 取值：`windows`、`linux`、`android`、`ios`。

### 目录结构

```
version/
├── versions.json                              # 版本清单
├── note123-client-windows-x64.zip             # Windows 安装包
├── note123-client-linux-x64-v1.0.1.tar.gz     # Linux 安装包
└── note123-android-arm64-v8a.apk              # Android APK
```

- Windows：下载 zip 解压覆盖原目录后自动重启
- Android：下载 APK 后调起系统安装
- iOS：不走服务端下载，需通过 App Store 更新
- 目录里没有的平台不会出现在检查结果中

### versions.json 格式

顶层 `versions` 数组存放所有版本共用的更新日志（取第 0 条），其余键名与 `platform` 一一对应，只存放该平台安装包信息：

```json
{
  "versions": [
    {
      "version": "v1.0.1",
      "versionCode": 2,
      "changelog": "- feat: 新增布局模式切换\n- fix: 修复同步问题",
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

字段说明：

- `versionCode`：整数构建号，客户端用它比较大小，必须随版本递增
- `md5`：安装包 MD5（大写），供完整性校验
- `file`：`NOTE_VERSION_DIR` 下的文件名，也是下载路径的一部分
- 发布新版本只需替换安装包、更新（或新增）对应平台条目，无需重启服务端

Windows 上可用 `pack/build_*.bat` 构建、`pack/update_versions_json.ps1` 自动生成/更新 `versions.json`。

---

## API

需要鉴权的接口必须带请求头: `X-User-Id` + `X-Token`.

| 方法 | 路径 | 说明 | 鉴权 |
|---|---|---|---|
| POST | `/user/register` | 注册用户 | 否 |
| POST | `/user/login` | 登录, 获取 token | 否 |
| POST | `/record/update` | 创建或更新条目 (baseVersion 做冲突检测) | 是 |
| POST | `/record/delete` | 删除条目 | 是 |
| GET | `/record/list` | 查询条目 (按版本增量拉取) | 是 |
| GET | `/record/download` | 下载条目文件 | 是 |
| POST | `/record/clear` | 清空当前用户所有条目 | 是 |
| GET | `/api_stat/list` | 查询 API 调用统计 | 是 |
| GET | `/upgrade/check` | 检查客户端更新（参数 `platform`） | 否 |
| GET | `/upgrade/download/{file}` | 下载安装包 | 否 |
| POST | `/admin/login` | 管理端登录 | 否 |
| GET | `/admin` | 管理界面 | 否 (session cookie) |

---

## License

MIT
