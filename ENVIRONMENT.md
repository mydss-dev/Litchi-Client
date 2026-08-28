# Litchi Client 部署教程

本文档只说明实际需要手动完成的部署步骤。

> **重要：`update.json` 不需要手工创建、编辑、签名或上传。**
>
> 使用者只需要首次配置 Update 密钥。之后每次发布版本时，GitHub `Publish` Workflow 会自动生成、签名并上传 `update.json`，同时自动上传安装包。

---

## 1. 准备本地环境

需要安装：

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

Remote Config 使用一套独立的 Ed25519 密钥。

执行：

```powershell
dart run tool/sign_remote_config.dart generate
```

输出：

```text
PRIVATE_KEY=xxxxxxxx
PUBLIC_KEY=xxxxxxxx
```

保存位置：

```text
PRIVATE_KEY → REMOTE_CONFIG_PRIVATE_KEY → 本地离线保存
PUBLIC_KEY  → REMOTE_CONFIG_PUBLIC_KEY  → GitHub Repository Variable
```

注意：

- `REMOTE_CONFIG_PRIVATE_KEY` 不提交 GitHub；
- 不上传 R2/CDN；
- 公钥可以公开。

---

## 3. 生成 Update 密钥

Update 使用另一套完全独立的 Ed25519 密钥。

执行：

```powershell
dart run tool/sign_update_manifest.dart generate
```

保存位置：

```text
PRIVATE_KEY → UPDATE_PRIVATE_KEY → release-signing Environment Secret
PUBLIC_KEY  → UPDATE_PUBLIC_KEY  → GitHub Repository Variable
```

Remote Config 与 Update 不得共用同一套密钥。

> 这一步只负责准备 Update 的签名密钥。
> 后续不需要手动执行 Update 签名工具，也不需要自己制作 `update.json`。

---

## 4. 配置 GitHub Repository Variables

进入：

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

初次部署不需要创建：

```text
REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY
UPDATE_PREVIOUS_PUBLIC_KEY
```

项目自动使用以下地址：

```text
${CDN_BASE_URL}/config.json
${CDN_BASE_URL}/update.json
${CDN_BASE_URL}/download/<filename>
```

其中：

```text
config.json → 手工维护并签名
update.json → Publish Workflow 自动生成并上传
download/   → Publish Workflow 自动上传安装包
```

---

## 5. 创建 `config.json`

仓库根目录提供模板：

[`config.example.json`](./config.example.json)

第一次部署时复制：

```powershell
Copy-Item .\config.example.json .\config.json
```

以后直接编辑：

```text
config.json
```

不需要创建 `config.local.json`、`config-payload.json` 等中间文件。

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

客户端的面板 API 地址只来自签名后的：

```text
api_base_list
```

项目不使用 `API_BASE` 编译兜底，也不需要在 GitHub 中重复配置 API 地址。

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

所有外部 URL 应使用 HTTPS。

---

## 6. 临时加载 Remote Config 密钥

签名 `config.json` 前，在当前 PowerShell 窗口临时加载 Remote Config 密钥：

```powershell
$env:REMOTE_CONFIG_PRIVATE_KEY='这里填写第 2 步生成的 PRIVATE_KEY'
$env:REMOTE_CONFIG_PUBLIC_KEY='这里填写第 2 步生成的 PUBLIC_KEY'
```

这两个变量只存在于**当前 PowerShell 进程**：

```text
当前窗口有效
关闭窗口自动消失
不会写入 Windows 系统环境变量
不会写入 GitHub
不会写入项目文件
```

不要使用：

```text
setx
```

可以只检查长度，不打印真实密钥：

```powershell
$env:REMOTE_CONFIG_PRIVATE_KEY.Length
$env:REMOTE_CONFIG_PUBLIC_KEY.Length
```

两个结果都应大于 `0`。

---

## 7. 签名 `config.json`

这里是 **Ed25519 数字签名**，不是内容加密。

Windows PowerShell 执行：

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

此时这个 `config.json` 就是最终上传文件。

`payload_b64` 只是编码，不是加密，因此配置中不要保存密码、Token、API Secret、私钥等敏感信息。

---

## 8. 清理当前 PowerShell 中的 Remote Config 密钥

签名完成后执行：

```powershell
Remove-Item Env:REMOTE_CONFIG_PRIVATE_KEY -ErrorAction SilentlyContinue
Remove-Item Env:REMOTE_CONFIG_PUBLIC_KEY -ErrorAction SilentlyContinue
```

或者直接关闭当前 PowerShell 窗口。

---

## 9. 上传 `config.json`

将签名后的：

```text
config.json
```

上传到 Cloudflare R2 Bucket 根目录。

此时只需要关心 `config.json`；不要手工创建或上传 `update.json`。

访问：

```text
https://你的CDN域名/config.json
```

应返回：

```json
{
  "payload_b64": "...",
  "signature": "..."
}
```

---

## 10. 配置 GitHub Repository Secrets

进入：

```text
GitHub Repository
→ Settings
→ Secrets and variables
→ Actions
→ Secrets
```

Android 正式 Release 需要：

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

可选品牌配置：

```text
APP_NAME
LOGO_URL
```

以下公钥放 Repository Variables，不放 Secrets：

```text
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
```

面板 API 地址不要放 Repository Secrets，统一维护在 `config.json` 的 `api_base_list` 中。

---

## 11. 创建 `release-signing` Environment

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

Environment Secret：

```text
UPDATE_PRIVATE_KEY
```

这里的私钥由 Publish Workflow 自动读取，用来自动签名 `update.json`。

不需要在本地手工使用这把私钥生成 `update.json`。

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
```

Android 还会检查 Android 签名配置。

CI 成功后会自动生成 GitHub Release 和安装包。

---

## 14. 运行 Publish Workflow

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

点击运行后，后续全部自动完成：

```text
读取 GitHub Release 安装包
        ↓
自动计算版本、文件哈希和下载地址
        ↓
自动使用 UPDATE_PRIVATE_KEY 生成并签名 update.json
        ↓
自动上传安装包到 /download/
        ↓
自动上传 update.json 到 R2 根目录
```

**这里不需要：**

```text
自己创建 update.json
自己编辑 update.json
自己运行 Update 签名命令
自己上传 update.json
自己上传安装包
```

最终 R2 结构由流程自动形成：

```text
/
├── config.json               # 你手工签名并上传
├── update.json               # Publish Workflow 自动生成/签名/上传
└── download/                 # Publish Workflow 自动上传
    ├── *.exe
    ├── *.apk
    └── *.dmg
```

---

## 15. 最终验证

只需要检查发布结果：

```text
https://你的CDN域名/config.json
https://你的CDN域名/update.json
https://你的CDN域名/download/<安装包文件名>
```

GitHub Actions 应显示：

```text
CI       success
sign     success
upload   success
```

客户端使用：

```text
REMOTE_CONFIG_PUBLIC_KEY → 验证 config.json
UPDATE_PUBLIC_KEY        → 验证自动生成的 update.json
```

---

## 16. 后续修改 Remote Config

以后只修改 Remote Config 时：

```text
1. 从 config.example.json 复制出新的明文 config.json
2. 修改配置
3. 增加 config_version
4. 当前 PowerShell 临时加载 Remote Config 密钥
5. 执行第 7 节签名命令
6. 清理临时密钥
7. 用新的 config.json 覆盖 R2 根目录旧文件
```

修改普通 Remote Config 不需要重新构建客户端，也与 `update.json` 无关。

---

## 17. 最终需要记住的区别

```text
config.json
→ 你手工维护
→ 你手工签名
→ 你手工上传

update.json
→ 不手工维护
→ 不手工签名
→ 不手工上传
→ Publish Workflow 全自动处理
```
