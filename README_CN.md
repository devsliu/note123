# Note123

> 自托管笔记同步 — Go + SQLite（**零基础设施**）+ Flutter 客户端。
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
| Windows 客户端 | **~15 MB** |
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
cd server_go
go mod download
go run main.go
```

**客户端:**
```bash
cd client_flutter
flutter pub get
flutter run
```

### 本地服务配置文件

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

**参数说明:**
- `admin.username` / `admin.password`: 管理界面登录凭据
- `server.maxDevices`: 同账号最多保留的活跃 token 数，超出后自动踢掉最老的 token
- `server.maxFileSize`: 单条目最大上传文件大小，单位 MB（默认 100）

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
      - NOTE_ADMIN_USER=admin
      - NOTE_ADMIN_PASS=admin
      - NOTE_MAX_DEVICES=5
      - NOTE_MAX_FILE_SIZE=100
    volumes:
      - ./note123:/app/data
    restart: always
```

### 首次使用

1. 启动服务端，浏览器打开 `http://host:port/admin`
2. 用上面配置的 admin 账号登录
3. 在管理界面创建用户账号（用户名 + 密码）
4. 打开 Note123 客户端 → **设置** → 填入服务端地址（如 `http://your-server:10001`）和刚才创建的用户名密码
5. 登录成功，多端同步笔记

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
| POST | `/admin/login` | 管理端登录 | 否 |
| GET | `/admin` | 管理界面 | 否 (session cookie) |

---

## License

MIT
