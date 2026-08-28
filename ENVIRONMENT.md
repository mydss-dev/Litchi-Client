# Litchi Client 部署教程

本文档只保留实际操作步骤。按顺序完成即可。

## 1. 准备本地环境

需要：

```text
Flutter
Dart（Flutter SDK 已自带）
Git
```

项目根目录执行：

```powershell
flutter pub get
```

确认：

```powershell
flutter --version
dart --version
```

---

## 2. 生成 Remote Config 密钥

执行：

```powershell
dart run tool/sign_remote_config.dart generate
```

输出：

```text
PRIVATE_KEY=xxxxxxxx
PUBLIC_KEY=xxxxxxxx
```

保存：

```text
PRIVATE_KEY → REMOTE_CONFIG_PRIVATE_KEY → 本地离线保存
PUBLIC_KEY  → REMOTE_CONFIG_PUBLIC_KEY  → GitHub Repository Variable
```

注意：

- 私钥不要提交 GitHub；
- 私钥不要上传 R2/CDN；
- 公钥可以公开。

---

## 3. 生成 Update 密钥

再生成一套完全独立的密钥：

```powershell
dart run tool/sign_update_manifest.dart generate
```

保存：

```text
PRIVATE_KEY → UPDATE_PRIVATE_KEY → release-signing Environment Secret
PUBLIC_KEY  → UPDATE_PUBLIC_KEY  → GitHub Repository Variable
```

Remote Config 和 Update 不能共用同一套密钥。

---

## 4. 配置 GitHub Repository Variables

位置：

```text
GitHub Repository
→ Settings
→ Secrets and variables
→ Actions
→ Variables
```

创建：

| Variable | 内容 |
|---|---|
| `CDN_BASE_URL` | CDN 根地址，例如 `https://cdn.example.com` |
| `REMOTE_CONFIG_PUBLIC_KEY` | 第 2 步生成的 Remote Config 公钥 |
| `UPDATE_PUBLIC_KEY` | 第 3 步生成的 Update 公钥 |

初次部署不需要：

```text
REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY
UPDATE_PREVIOUS_PUBLIC_KEY
```

项目会自动使用：

```text
${CDN_BASE_URL}/config.json
${CDN_BASE_URL}/update.json
${CDN_BASE_URL}/download/<filename>
```

---

## 5. 创建 `config.json`

仓库根目录提供模板：

[`config.example.json`](./config.example.json)

第一次配置时复制：

```powershell
Copy-Item .\config.example.json .\config.json
```

以后直接编辑：

```text
config.json
```

不需要创建任何 `config.local.json`、`config-payload.json` 等中间文件。

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

`panel_type` 支持：

```text
v2board
xiao_v2board
xboard
```

每次发布新的 Remote Config 时递增：

```text
config_version
```

例如：

```text
1 → 2 → 3
```

---

## 6. 临时加载 Remote Config 密钥

这一步的目的只是让签名程序在当前 PowerShell 窗口读取密钥。

执行：

```powershell
$env:REMOTE_CONFIG_PRIVATE_KEY='这里填写第 2 步生成的 PRIVATE_KEY'
$env:REMOTE_CONFIG_PUBLIC_KEY='这里填写第 2 步生成的 PUBLIC_KEY'
```

这里只会写入**当前 PowerShell 进程的临时环境变量**：

```text
当前 PowerShell 窗口有效
关闭窗口后自动消失
不会写入 Windows 系统环境变量
不会写入 GitHub
不会写入项目文件
```

不要使用：

```text
setx
```

`setx` 会把变量持久写入 Windows 环境变量，不需要这样做。

可以只检查长度，不打印真实密钥：

```powershell
$env:REMOTE_CONFIG_PRIVATE_KEY.Length
$env:REMOTE_CONFIG_PUBLIC_KEY.Length
```

两个结果都必须大于 `0`。

---

## 7. 签名 `config.json`

完整顺序就是：

```text
编辑 config.json
        ↓
临时输入 REMOTE_CONFIG_PRIVATE_KEY
临时输入 REMOTE_CONFIG_PUBLIC_KEY
        ↓
执行签名
        ↓
原地覆盖 config.json
        ↓
上传 config.json
```

这里执行的是 **Ed25519 数字签名**，不是内容加密。

### Windows PowerShell

执行：

```powershell
$utf8 = New-Object System.Text.UTF8Encoding($false)
$signed = (& dart run tool/sign_remote_config.dart sign-env .\config.json) -join [Environment]::NewLine
[System.IO.File]::WriteAllText((Resolve-Path .\config.json), $signed + [Environment]::NewLine, $utf8)
```

不要执行：

```text
dart run tool/sign_remote_config.dart sign-env config.json > config.json
```

这种写法可能先清空输入文件。

签名完成后检查：

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

此时 `config.json` 已经是最终上传文件。

`payload_b64` 只是编码，不是加密，因此原始配置中不要填写密码、Token、API Secret、私钥等敏感信息。

---

## 8. 清理当前 PowerShell 中的 Remote Config 密钥

签名完成后可以立即执行：

```powershell
Remove-Item Env:REMOTE_CONFIG_PRIVATE_KEY -ErrorAction SilentlyContinue
Remove-Item Env:REMOTE_CONFIG_PUBLIC_KEY -ErrorAction SilentlyContinue
```

确认已经清除：

```powershell
$env:REMOTE_CONFIG_PRIVATE_KEY
$env:REMOTE_CONFIG_PUBLIC_KEY
```

应为空。

如果直接关闭当前 PowerShell 窗口，也会自动清除。

---

## 9. 上传 `config.json`

将签名后的：

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

最终访问地址：

```text
https://你的CDN域名/config.json
```

浏览器打开后应该看到：

```json
{
  "payload_b64": "...",
  "signature": "..."
}
```

而不是原始配置字段。

---

## 10. 配置 GitHub Repository Secrets

位置：

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

公钥不要放 Secrets：

```text
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
```

公钥放 Repository Variables。

---

## 11. 创建 `release-signing` Environment

位置：

```text
Settings
→ Environments
→ New environment
```

创建：

```text
release-signing
```

Environment Secret：

```text
UPDATE_PRIVATE_KEY
```

这里只放 Update 私钥，不放 R2 凭证。

---

## 12. 创建 `release-upload` Environment

创建：

```text
release-upload
```

Environment Secrets：

```text
R2_ACCOUNT_ID
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
R2_BUCKET
```

这里不要放：

```text
UPDATE_PRIVATE_KEY
REMOTE_CONFIG_PRIVATE_KEY
```

---

## 13. 构建正式版本

创建 `v*` Tag，例如：

```text
v1.0.0
```

CI 会检查：

```text
CDN_BASE_URL
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
API_BASE
```

Android 还会检查 Android 签名配置。

CI 成功后会生成 GitHub Release 和安装包。

---

## 14. 发布 `update.json` 和安装包

进入：

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

流程：

```text
GitHub Release 安装包
        ↓
UPDATE_PRIVATE_KEY 签名
        ↓
update.json
        ↓
上传 R2
```

最终 R2：

```text
/
├── config.json
├── update.json
└── download/
    ├── *.exe
    ├── *.apk
    └── *.dmg
```

---

## 15. 最终验证

确认：

```text
https://你的CDN域名/config.json
https://你的CDN域名/update.json
https://你的CDN域名/download/<安装包文件名>
```

GitHub Actions：

```text
CI       success
sign     success
upload   success
```

客户端使用：

```text
REMOTE_CONFIG_PUBLIC_KEY → 验证 config.json
UPDATE_PUBLIC_KEY        → 验证 update.json
```

两套密钥互不通用。

---

## 16. 后续修改 Remote Config

以后改配置只需要：

```text
1. 从 config.example.json 重新复制出明文 config.json
2. 填写新的配置
3. 增加 config_version
4. 在当前 PowerShell 临时输入 Remote Config 私钥和公钥
5. 执行第 7 节签名命令
6. 清理当前 PowerShell 临时密钥
7. 用新的 config.json 覆盖 R2 根目录旧文件
```

修改普通 Remote Config 不需要重新构建客户端。
