# Litchi Build Bot MVP

这个目录是白牌打包机器人的 MVP。第一版不做复杂 SaaS 面板，先跑通：

- Telegram 创建 App：`/newapp`
- 签名远程配置：`/signconfig`
- 触发 GitHub Actions 打包：`/build`
- 记录最新下载包：`/setlatest`
- 中心更新接口：`npm run server`

## 安装

```bash
cd build-bot
npm install
cp .env.example .env
```

编辑 `.env`：

```env
BOT_TOKEN=你的 Telegram Bot Token
BOT_ADMINS=你的 Telegram 数字用户 ID
GITHUB_TOKEN=你的 GitHub Token
GITHUB_REPO=Kimibit7/Litchi-Client
GITHUB_REF=main
GITHUB_WORKFLOW_ID=white-label-build.yml
UPDATE_CHECK_URL=https://你的域名/update
DB_PATH=./data/bot.sqlite
PORT=3000
```

## 运行机器人

完整打包命令版：

```bash
npx tsx src/run_build.ts
```

配置签名版：

```bash
npx tsx src/run_sign.ts
```

当前 `package.json` 的 `npm run bot` 先保留最基础入口；后续可以改成 `src/run_build.ts` 或合并入口。

## Telegram 命令

### 创建 App

```text
/newapp client_10001 https://your-oss.com/client_10001/config.json
```

机器人返回：

```text
APP_ID=client_10001
REMOTE_CONFIG_URL=https://your-oss.com/client_10001/config.json
REMOTE_CONFIG_PUBLIC_KEY=xxxxx
```

这三个值后续打包必须固定。

### 签名配置

```text
/signconfig client_10001
{
  "app_name": "Litchi Client",
  "logo_letter": "https://xxx.com/logo.png",
  "api_base_list": ["https://api.xxx.com"],
  "api_path_prefix": "/x7f3a9k",
  "support_url": "https://t.me/xxx"
}
```

机器人会自动加：

```json
{
  "config_version": 1,
  "expires_at": "..."
}
```

然后返回签名后的：

```json
{
  "payload_b64": "...",
  "signature": "..."
}
```

把这个内容保存为 `config.json` 上传到该机场主 OSS。

### 触发打包

```text
/build client_10001 windows 1.2.8
/build client_10001 android 1.2.8
```

机器人会触发 `.github/workflows/white-label-build.yml`。

## 中心更新接口

启动：

```bash
npm run server
```

接口：

```text
/update?app_id=client_10001&platform=windows&version=1.2.7
```

返回字段兼容客户端当前 `UpdateService`。

## 重要规则

同一个 APP_ID 的每次打包都必须保持一致：

- APP_ID
- REMOTE_CONFIG_URL
- REMOTE_CONFIG_PUBLIC_KEY
- Android applicationId / 签名证书
- Windows 安装器身份

更新接口只能返回同一个 APP_ID 的专属包，不能返回通用包。
