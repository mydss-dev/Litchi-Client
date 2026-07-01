# Litchi 多租户打包机器人

Telegram 机器人负责授权、绑定客户 OSS、签名远程配置并触发
`.github/workflows/white-label-build.yml`。真正的 Windows、macOS 和 Android
构建在 GitHub Actions 中完成。

本地运行使用 Node.js 22；Docker 镜像已经固定到 Node 22。

每个客户在机器人内部固定拥有：

- 内部 `APP_ID`（只用于数据库索引、任务和派生原生安装身份）
- `REMOTE_CONFIG_URL`
- Ed25519 配置签名密钥
- Android applicationId
- macOS Bundle ID
- GitHub Actions request ID

客户端本身只编入该客户的 `REMOTE_CONFIG_URL` 和 Ed25519 公钥；名称、Logo、
API 地址等业务配置全部从客户 OSS 获取。内部 `APP_ID` 不会写入 Dart 客户端。

## 配置

```bash
cd bot
cp .env.example .env
npm ci
```

至少填写：

```env
BOT_TOKEN=Telegram Bot Token
BOT_ADMINS=管理员的 Telegram 数字 ID
GITHUB_TOKEN=可触发 Actions 的 GitHub Token
GITHUB_REPO=mydss-dev/Litchi-Client
GITHUB_REF=main
GITHUB_WORKFLOW_ID=white-label-build.yml
BUILD_VERSION=1.2.7
DOWNLOAD_BASE_URL=https://download.example.com
DB_PATH=./data/bot.sqlite
KEY_ENCRYPTION_KEY=使用 openssl rand -hex 32 生成的 64 位十六进制密钥
BUILD_RATE_LIMIT_MAX=2
BUILD_RATE_LIMIT_HOURS=24
```

`BUILD_VERSION` 是必填项，机器人直接把它交给 GitHub Actions，不读取
`pubspec.yaml`。发布新版本时修改 `.env` 后重启机器人。

## Cloudflare R2 自动下载

在 R2 Bucket 的设置中绑定公开自定义域名，并把这个域名写入机器人 `.env`：

```env
DOWNLOAD_BASE_URL=https://download.example.com
```

在 GitHub 仓库的 Actions secrets 中配置：

- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET`

R2 API Token 只授予目标 Bucket 的 Object Read & Write 权限。构建成功后，工作流会
上传到 `packages/<APP_ID>/<platform>/<version>/<request-id>.<ext>`，同时计算安装包
SHA-256 并写入对象元数据。机器人随后返回公开下载地址和 SHA-256。
`DOWNLOAD_BASE_URL` 是机器人生成下载地址和 `update.json` 的必要配置，不能为空。

`BOT_ADMINS` 不能为空，否则机器人会拒绝启动。直接运行：

```bash
npm run bot
```

或使用 Docker：

```bash
docker compose up -d --build
```

## 签名密钥备份

客户签名私钥使用 `KEY_ENCRYPTION_KEY` 加密后保存在 SQLite。必须分别备份：

- `bot/data/bot.sqlite`
- `.env` 中的 `KEY_ENCRYPTION_KEY`

丢失任意一项，已经交付的客户端都无法再接受新的 `config.json` 或 `update.json`。
Docker 部署可在升级前执行：

```bash
cd bot
docker compose stop bot
cp data/bot.sqlite "data/bot.sqlite.backup-$(date +%F-%H%M%S)"
docker compose start bot
```

数据库备份和 `.env` 应复制到服务器之外的受控存储，不要只留在同一块磁盘。

## GitHub Actions 准备

Android 正式包需要在仓库中设置以下 Actions secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

同一个客户后续升级必须保持 applicationId 和签名证书不变。当前工作流使用一套
发行证书签署所有独立 applicationId；如果需要客户独享证书，应进一步接入外部密钥库，
不要把私钥作为 workflow input 传递。

## 使用流程

1. 用户发送 `/myid`，管理员使用 `/authorize` 授权。
2. 用户发送 `/bindoss`，绑定自己的 HTTPS OSS 地址。
3. 用户发送 `/config`，机器人发送标准 `config.template.json`，并在消息中逐项说明字段。
4. 用户填写模板并发回；机器人校验、签名并立即发送基础 `config.json`。
5. 用户需要生成安装包时发送 `/build`，机器人使用已保存配置并询问打包平台。
6. 机器人展示软件名、版本和平台，用户确认后才触发 GitHub Actions。
7. 同版本重打只更新之后的新下载包；已安装用户的系统图标和原生软件名称不会变化，
   必须等下次提高版本并下载安装更新后才会生效。
8. 工作流使用内联签名配置构建，上传安装包并计算 SHA-256。
9. 配置校验后机器人立即发送签名 `config.json`，用户上传一次即可。
10. 打包成功后机器人把版本、下载地址和 SHA 写入独立签名 `update.json`。
11. 用户上传 `update.json` 后本次更新才生效；不上传则不会向已有用户发布更新，
    且整个过程无需再次上传 `config.json`。

私钥始终只留在机器人。GitHub Actions 收到的是已经签名、可以公开的配置，不会收到
签名私钥。Android 的客户下载地址只发布一个 arm64 APK；32 位兼容包仅保留在
GitHub Artifact，不进入 R2。

工作流会先使用该客户的公钥验证 Bot 随任务传入的签名配置；旧任务仍可回退读取 OSS。
验签失败、配置字段非法或没有生成最终安装包时，任务会直接失败，不会上传空产物。

## Logo 素材规范

客户只需要在配置的 `logo_url` 提供一张图片：

- PNG 格式
- `1024×1024` 像素，必须为正方形
- 建议透明背景，主体四周预留约 15% 安全边距
- 文件不超过 10 MB
- 必须使用公开可访问的 HTTPS URL

工作流会自动生成软件内 Logo、Windows EXE/安装器图标、Android/macOS 图标，以及
Windows 托盘的连接彩色图标和断开灰色图标。Windows 最终产物是包含完整运行时的
单个 `Setup.exe`，不是便携 ZIP。

## 本地检查

```bash
npm run check
npm test
```

SQLite 中保存了配置签名私钥。部署时务必保护 `bot/data` 目录及备份，不要把数据库
提交到 Git。
