# Litchi Client 部署教程

本文档仅说明从空白环境到完成构建、Remote Config 签名、GitHub Release 和 R2 发布的实际操作步骤。

## 1. 准备环境

本地需要安装：

```text
Flutter
Dart（Flutter SDK 已自带）
Git
```

在项目根目录执行：

```powershell
flutter pub get
```

确认命令可用：

```powershell
flutter --version
dart --version
```

---

## 2. 配置 GitHub Repository Variables

进入：

```text
GitHub Repository
→ Settings
→ Secrets and variables
→ Actions
→ Variables
```

创建以下变量：

| Variable | 内容 |
|---|---|
| `CDN_BASE_URL` | CDN 根地址，例如 `https://cdn.example.com` |
| `REMOTE_CONFIG_PUBLIC_KEY` | Remote Config Ed25519 公钥 |
| `UPDATE_PUBLIC_KEY` | Update Ed25519 公钥 |

初次部署不需要创建：

```text
REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY
UPDATE_PREVIOUS_PUBLIC_KEY
```

项目会根据 `CDN_BASE_URL` 自动使用：

```text
${CDN_BASE_URL}/config.json
${CDN_BASE_URL}/update.json
${CDN_BASE_URL}/download/<filename>
```

例如：

```text
https://cdn.example.com/config.json
https://cdn.example.com/update.json
https://cdn.example.com/download/Litchi-Setup-1.0.0.exe
```

---

## 3. 生成 Remote Config 密钥

执行：

```powershell
dart run tool/sign_remote_config.dart generate
```

输出格式：

```text
PRIVATE_KEY=xxxxxxxx
PUBLIC_KEY=xxxxxxxx
```

保存方式：

```text
PRIVATE_KEY → REMOTE_CONFIG_PRIVATE_KEY → 本地离线保存
PUBLIC_KEY  → REMOTE_CONFIG_PUBLIC_KEY  → GitHub Repository Variable
```

`REMOTE_CONFIG_PRIVATE_KEY` 不要提交到 GitHub，也不要上传到 CDN/R2。

---

## 4. 生成 Update 密钥

再独立生成第二套密钥：

```powershell
dart run tool/sign_update_manifest.dart generate
```

输出格式：

```text
PRIVATE_KEY=xxxxxxxx
PUBLIC_KEY=xxxxxxxx
```

保存方式：

```text
PRIVATE_KEY → UPDATE_PRIVATE_KEY → GitHub release-signing Environment Secret
PUBLIC_KEY  → UPDATE_PUBLIC_KEY  → GitHub Repository Variable
```

Remote Config 和 Update 必须使用两套不同的密钥。

---

## 5. 创建并签名 `config.json`

仓库根目录提供：

[`config.example.json`](./config.example.json)

首次部署时复制为正式配置文件：

```powershell
Copy-Item .\config.example.json .\config.json
```

以后直接编辑：

```text
config.json
```

不需要创建 `config.local.json`、`config-payload.json` 或其他中间配置文件。

### 5.1 编辑配置

示例：

```json
{
  "config_version": 1,
  "panel_type": "xiao_v2board",
  "app_name": "Litchi VPN",
  "api_base_list": [
    "https://panel.example.com"
  ],
  "api_prefix": "/api/v1",
  "logo_url": "https://cdn.example.com/logo.png",
  "avatar_url": "https://cdn.example.com/avatar.png",
  "invite_url_base": "https://panel.example.com",
  "update_enabled": true
}
```

`panel_type` 当前支持：

```text
v2board
xiao_v2board
xboard
```

所有外部 URL 应使用 HTTPS。

每次正式更新 Remote Config 时递增：

```text
config_version
```

例如：

```text
1 → 2 → 3
```

不要降低已经发布过的版本号。

### 5.2 设置 Remote Config 密钥

PowerShell 当前窗口执行：

```powershell
$env:REMOTE_CONFIG_PRIVATE_KEY="你的 REMOTE_CONFIG_PRIVATE_KEY"
$env:REMOTE_CONFIG_PUBLIC_KEY="你的 REMOTE_CONFIG_PUBLIC_KEY"
```

这里只是设置当前 PowerShell 会话，关闭窗口后不会继续保留。

### 5.3 直接签名并覆盖 `config.json`

当前签名工具将签名结果输出到标准输出，因此不能执行：

```text
dart run tool/sign_remote_config.dart sign-env config.json > config.json
```

这样会先清空输入文件。

Windows PowerShell 使用下面三行，直接读取当前 `config.json`，完成签名后再安全覆盖原文件，不生成中间文件：

```powershell
$utf8 = New-Object System.Text.UTF8Encoding($false)
$signed = (& dart run tool/sign_remote_config.dart sign-env .\config.json) -join [Environment]::NewLine
[System.IO.File]::WriteAllText((Resolve-Path .\config.json), $signed + [Environment]::NewLine, $utf8)
```

签名后 `config.json` 会直接变成：

```json
{
  "payload_b64": "...",
  "signature": "..."
}
```

此时该文件就是最终需要上传的 Remote Config：

```text
config.json
```

> 这里是 Ed25519 数字签名，不是内容加密。`payload_b64` 可以被解码，因此 `config.json` 中不要保存密码、Token、私钥等敏感信息。

### 5.4 检查签名结果

执行：

```powershell
Get-Content .\config.json
```

应看到：

```text
payload_b64
signature
```

不应再直接看到原始配置字段。

---

## 6. 上传 `config.json`

将签名完成的：

```text
config.json
```

上传到 Cloudflare R2 Bucket 根目录。

最终结构：

```text
/
├── config.json
├── update.json
└── download/
```

不要上传 Remote Config 私钥。

建议 `config.json` 使用：

```text
Content-Type: application/json
Cache-Control: no-cache, max-age=300
```

上传完成后访问：

```text
https://你的CDN域名/config.json
```

必须能够正常返回：

```json
{
  "payload_b64": "...",
  "signature": "..."
}
```

---

## 7. 配置 GitHub Repository Secrets

进入：

```text
GitHub Repository
→ Settings
→ Secrets and variables
→ Actions
→ Secrets
```

正式 Release 至少配置：

| Secret | 用途 |
|---|---|
| `API_BASE` | 客户端 API fallback 地址 |

Android Release 需要：

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

可选：

```text
APP_NAME
LOGO_URL
```

不要把以下公钥放进 Secrets：

```text
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
```

它们应放在 Repository Variables。

---

## 8. 创建 `release-signing` Environment

进入：

```text
Settings
→ Environments
→ New environment
```

创建：

```text
release-signing
```

Environment Secret 添加：

```text
UPDATE_PRIVATE_KEY
```

这里只保存 Update 私钥。

不要加入 R2 写入密钥。

---

## 9. 创建 `release-upload` Environment

创建：

```text
release-upload
```

Environment Secrets 添加：

```text
R2_ACCOUNT_ID
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
R2_BUCKET
```

这里不要加入：

```text
UPDATE_PRIVATE_KEY
REMOTE_CONFIG_PRIVATE_KEY
```

---

## 10. 构建正式版本

创建 `v*` Tag，例如：

```text
v1.0.0
```

`.github/workflows/ci.yml` 会执行正式构建。

正式 Tag 构建会检查：

```text
CDN_BASE_URL
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
API_BASE
```

Android 还会检查签名 Keystore 配置。

CI 成功后会创建 GitHub Release 和平台安装包。

---

## 11. 发布 `update.json` 和安装包

进入：

```text
GitHub
→ Actions
→ Publish
→ Run workflow
```

输入需要发布的 Tag，例如：

```text
v1.0.0
```

Publish Workflow 会自动执行：

```text
GitHub Release 安装包
        ↓
UPDATE_PRIVATE_KEY 签名
        ↓
update.json
        ↓
上传 R2
```

最终 R2 结构：

```text
/
├── config.json
├── update.json
└── download/
    ├── *.exe
    ├── *.apk
    └── *.dmg
```

安装包目录固定为小写：

```text
download/
```

---

## 12. 最终验证

确认以下地址都能访问：

```text
https://你的CDN域名/config.json
https://你的CDN域名/update.json
https://你的CDN域名/download/<安装包文件名>
```

`config.json` 应包含：

```text
payload_b64
signature
```

`update.json` 同样应为签名后的 Update Manifest。

GitHub Actions 应确认：

```text
CI       success
sign     success
upload   success
```

完成后，客户端会使用：

```text
REMOTE_CONFIG_PUBLIC_KEY → 验证 config.json
UPDATE_PUBLIC_KEY        → 验证 update.json
```

两套密钥互不通用。

---

## 13. 后续修改 Remote Config

需要修改远程配置时：

1. 准备一个可编辑的明文 `config.json`（可从 `config.example.json` 重新复制并填写）；
2. 增加 `config_version`；
3. 设置 `REMOTE_CONFIG_PRIVATE_KEY` / `REMOTE_CONFIG_PUBLIC_KEY`；
4. 执行第 5.3 节的原地签名命令；
5. 用新的签名 `config.json` 覆盖 R2 根目录旧文件。

不需要重新构建客户端。

只有更换 `REMOTE_CONFIG_PUBLIC_KEY`、`UPDATE_PUBLIC_KEY` 或其他编译期配置时，才需要重新发布客户端。
