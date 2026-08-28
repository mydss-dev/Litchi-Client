# Litchi Client 部署教程

本文档按实际操作顺序说明部署流程。

---

## 1. 准备环境

本地需要：

```text
Flutter
Dart（Flutter SDK 已包含）
Git
```

项目根目录执行：

```powershell
flutter pub get
flutter --version
dart --version
```

---

## 2. 生成 Remote Config 密钥

Remote Config 密钥只需要首次部署时生成一次。

执行：

```powershell
dart run tool/sign_remote_config.dart generate
```

会得到：

```text
PRIVATE_KEY=xxxxxxxx
PUBLIC_KEY=xxxxxxxx
```

保存：

```text
PRIVATE_KEY → 本地安全保存
PUBLIC_KEY  → GitHub Repository Variable: CONFIG_PUBLIC_KEY
```

以后修改 `config.json` 时继续使用同一套密钥，不需要重新执行 `generate`。

---

## 3. 创建 `config.json`

复制模板：

```powershell
Copy-Item .\config.example.json .\config.json
```

然后直接编辑 `config.json`。

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
  "update_enabled": false
}
```

主要字段：

| 字段 | 作用 |
|---|---|
| `config_version` | 每次发布新配置时递增 |
| `panel_type` | `v2board` / `xiao_v2board` / `xboard` |
| `app_name` | 应用名称 |
| `api_base_list` | 面板 API 地址列表 |
| `api_prefix` | API 路径前缀 |
| `logo_url` | Logo / 构建图标地址 |
| `avatar_url` | 默认头像地址 |
| `invite_url_base` | 邀请链接基础地址 |
| `update_enabled` | 是否启用客户端自动更新 |

如果不需要自动更新：

```json
"update_enabled": false
```

如果需要自动更新：

```json
"update_enabled": true
```

---

## 4. 签名 `config.json`

在当前 PowerShell 窗口临时加载第 2 步保存的 Remote Config 密钥：

```powershell
$env:REMOTE_CONFIG_PRIVATE_KEY='你的 PRIVATE_KEY'
$env:REMOTE_CONFIG_PUBLIC_KEY='你的 PUBLIC_KEY'
```

执行签名：

```powershell
$utf8 = New-Object System.Text.UTF8Encoding($false)
$signed = (& dart run tool/sign_remote_config.dart sign-env .\config.json) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) { throw "Remote Config 签名失败，config.json 未修改。" }
[System.IO.File]::WriteAllText((Resolve-Path .\config.json), $signed + [Environment]::NewLine, $utf8)
```

签名后检查：

```powershell
Get-Content .\config.json
```

正常结果：

```json
{
  "payload_b64": "...",
  "signature": "..."
}
```

签名完成后清理当前 PowerShell 中的临时密钥：

```powershell
Remove-Item Env:REMOTE_CONFIG_PRIVATE_KEY -ErrorAction SilentlyContinue
Remove-Item Env:REMOTE_CONFIG_PUBLIC_KEY -ErrorAction SilentlyContinue
```

`payload_b64` 可以被解码，因此 `config.json` 只用于公开配置。

---

## 5. 上传 `config.json`

将签名后的 `config.json` 上传到 CDN / Cloudflare R2 根目录。

例如：

```text
https://cdn.example.com/config.json
```

浏览器访问后应看到：

```json
{
  "payload_b64": "...",
  "signature": "..."
}
```

---

## 6. 配置 GitHub Repository Variables

进入：

```text
Repository
→ Settings
→ Secrets and variables
→ Actions
→ Variables
```

### 所有部署都填写

| Variable | 填写内容 |
|---|---|
| `CDN_BASE_URL` | CDN 根地址，例如 `https://cdn.example.com` |
| `CONFIG_PUBLIC_KEY` | 第 2 步生成的 Remote Config 公钥 |

项目会自动读取：

```text
${CDN_BASE_URL}/config.json
```

### `update_enabled: true` 时再填写

| Variable | 填写内容 |
|---|---|
| `UPDATE_PUBLIC_KEY` | 第 7 步生成的 Update 公钥 |

所以：

```text
update_enabled = false
→ CDN_BASE_URL
→ CONFIG_PUBLIC_KEY

update_enabled = true
→ CDN_BASE_URL
→ CONFIG_PUBLIC_KEY
→ UPDATE_PUBLIC_KEY
```

---

## 7. 配置 GitHub Repository Secrets

进入：

```text
Repository
→ Settings
→ Secrets and variables
→ Actions
→ Secrets
```

这里统一保存 GitHub Actions 需要使用的私密凭证。

### 自动更新开启时填写

仅当 `config.json` 中：

```json
"update_enabled": true
```

才需要下面这些。

先生成 Update 密钥：

```powershell
dart run tool/sign_update_manifest.dart generate
```

得到：

```text
PRIVATE_KEY=xxxxxxxx
PUBLIC_KEY=xxxxxxxx
```

其中：

```text
PUBLIC_KEY  → Repository Variable: UPDATE_PUBLIC_KEY
PRIVATE_KEY → Repository Secret: UPDATE_PRIVATE_KEY
```

然后在 Repository Secrets 中填写：

```text
UPDATE_PRIVATE_KEY
R2_ACCOUNT_ID
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
R2_BUCKET
```

如果 `update_enabled` 为 `false`，这一组自动更新 Secret 不需要填写。

### Android 正式发布时填写

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

Windows 当前没有额外的签名 Secret。

macOS 当前使用 ad-hoc codesign，没有 Apple Developer 证书 Secret。

---

## 8. 构建正式版本

创建版本 Tag，例如：

```text
v1.0.0
```

CI 会使用：

```text
CDN_BASE_URL
CONFIG_PUBLIC_KEY
```

读取并验证：

```text
${CDN_BASE_URL}/config.json
```

然后从签名配置中读取：

```text
app_name
logo_url
api_base_list
update_enabled
```

如果启用了自动更新，同时会把 `UPDATE_PUBLIC_KEY` 编译进客户端用于验证 `update.json`。

---

## 9. 发布自动更新

本节只在：

```json
"update_enabled": true
```

时执行。

正式版本构建完成后进入：

```text
GitHub
→ Actions
→ Publish
→ Run workflow
```

输入 Tag，例如：

```text
v1.0.0
```

Publish Workflow 会在一个 Job 中自动完成：

```text
读取 GitHub Release 安装包
        ↓
生成 update.json
        ↓
使用 UPDATE_PRIVATE_KEY 签名
        ↓
使用 R2 凭证上传安装包到 /download/
        ↓
上传 update.json 到 CDN/R2 根目录
```

最终地址：

```text
${CDN_BASE_URL}/update.json
${CDN_BASE_URL}/download/<安装包文件名>
```

如果 `update_enabled` 为 `false`，不用运行 Publish。

---

## 10. 后续修改配置

以后修改 Remote Config：

```text
1. 准备新的明文 config.json
2. 修改配置
3. 增加 config_version
4. 临时加载原来的 Remote Config 密钥
5. 签名 config.json
6. 上传覆盖 CDN/R2 根目录的 config.json
```

普通 Remote Config 修改不需要重新生成密钥。

---

## 11. 最终配置速查

### `update_enabled: false`

Repository Variables：

```text
CDN_BASE_URL
CONFIG_PUBLIC_KEY
```

Repository Secrets：

```text
Android 正式发布时：
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

### `update_enabled: true`

Repository Variables：

```text
CDN_BASE_URL
CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
```

Repository Secrets：

```text
UPDATE_PRIVATE_KEY
R2_ACCOUNT_ID
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
R2_BUCKET
```

如果同时发布 Android 正式版，再加：

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

整个项目不再需要 `release-signing` 或 `release-upload` Environment。
