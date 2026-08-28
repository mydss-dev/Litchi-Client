# 环境配置

本文档说明 Litchi Client 的构建、配置签名与发布环境。

项目不会在源码中保存生产环境 URL、签名私钥或其他敏感值。构建与发布配置由 GitHub Actions 通过 Repository Variables、Repository Secrets 和 GitHub Environments 注入。Remote Config 与 Update Manifest 使用两套相互独立的 Ed25519 信任根。

## 配置模型

项目只维护一个 CDN 根地址：

```text
CDN_BASE_URL=https://cdn.example.com
```

构建和发布流程会基于该地址自动派生公开资源路径：

```text
Remote Config        https://cdn.example.com/config.json
Update Manifest      https://cdn.example.com/update.json
安装包下载            https://cdn.example.com/download/<filename>
```

Cloudflare R2 的对象结构应保持为：

```text
/
├── config.json
├── update.json
└── download/
    ├── Litchi-Setup-<version>.exe
    ├── Litchi-<version>.apk
    └── Litchi-<version>.dmg
```

`download` 路径统一使用小写。

## 信任域

Remote Config 与应用更新必须独立签名。

| 文件 | 签名私钥 | 验签公钥 |
|---|---|---|
| `config.json` | `REMOTE_CONFIG_PRIVATE_KEY` | `REMOTE_CONFIG_PUBLIC_KEY` |
| `update.json` | `UPDATE_PRIVATE_KEY` | `UPDATE_PUBLIC_KEY` |

两套密钥必须分别独立生成。Remote Config 密钥不得用于 Update Manifest 签名，Update 密钥也不得被 Remote Config 验签逻辑接受。

## GitHub Repository Variables

配置位置：

`Settings → Secrets and variables → Actions → Variables`

| Variable | 是否必需 | 说明 |
|---|---:|---|
| `CDN_BASE_URL` | 是 | 对外公开的 HTTPS CDN 根地址，不附加 `config.json`、`update.json` 或 `download`。 |
| `REMOTE_CONFIG_PUBLIC_KEY` | 是 | Base64URL 编码的 Ed25519 公钥，用于验证 `config.json`。 |
| `UPDATE_PUBLIC_KEY` | 是 | Base64URL 编码的 Ed25519 公钥，用于验证 `update.json`。 |
| `REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY` | 否 | Remote Config 上一把公钥，仅在密钥轮换期间使用。 |
| `UPDATE_PREVIOUS_PUBLIC_KEY` | 否 | Update 上一把公钥，仅在密钥轮换期间使用。 |

新部署只需要前三项。`*_PREVIOUS_PUBLIC_KEY` 在未执行密钥轮换时保持未配置即可。

## GitHub Repository Secrets

配置位置：

`Settings → Secrets and variables → Actions → Secrets`

| Secret | 是否必需 | 说明 |
|---|---:|---|
| `API_BASE` | Tag Release 必需 | 编译进正式版本的面板 API 根地址。 |
| `ANDROID_KEYSTORE_BASE64` | Android Tag Release 必需 | Base64 编码的 Android 签名 Keystore。 |
| `ANDROID_KEYSTORE_PASSWORD` | Android Tag Release 必需 | Android Keystore 密码。 |
| `ANDROID_KEY_ALIAS` | Android Tag Release 必需 | Android 签名密钥别名。 |
| `ANDROID_KEY_PASSWORD` | Android Tag Release 必需 | Android 签名密钥密码。 |
| `APP_NAME` | 否 | 应用显示名称，未设置时默认为 `Litchi`。 |
| `LOGO_URL` | 否 | 可选品牌 Logo 地址，未设置时使用项目内置资源。 |

Ed25519 公钥属于公开验证材料，应放在 Repository Variables，而不是 Repository Secrets。

## GitHub Environments

发布流程使用两个独立的 GitHub Environment 隔离签名凭证与上传凭证。

配置位置：

`Settings → Environments`

需要创建：

```text
release-signing
release-upload
```

### `release-signing`

Environment Secret：

| Secret | 说明 |
|---|---|
| `UPDATE_PRIVATE_KEY` | 仅用于签名 `update.json` 的 Ed25519 私钥。 |

该 Environment 不应包含 R2 凭证，也不应包含 `REMOTE_CONFIG_PRIVATE_KEY`。

### `release-upload`

Environment Secrets：

| Secret | 说明 |
|---|---|
| `R2_ACCOUNT_ID` | Cloudflare Account ID。 |
| `R2_ACCESS_KEY_ID` | R2 API Access Key ID。 |
| `R2_SECRET_ACCESS_KEY` | R2 API Secret Access Key。 |
| `R2_BUCKET` | R2 Bucket 名称。 |

该 Environment 不应包含任何签名私钥。

## 生成签名密钥

在项目根目录安装依赖：

```bash
flutter pub get
```

### Remote Config 密钥

生成 Remote Config 专用密钥：

```bash
dart run tool/sign_remote_config.dart generate
```

命令会输出：

```text
PRIVATE_KEY=<base64url-private-key>
PUBLIC_KEY=<base64url-public-key>
```

保存位置：

```text
PRIVATE_KEY → REMOTE_CONFIG_PRIVATE_KEY → 离线保存
PUBLIC_KEY  → REMOTE_CONFIG_PUBLIC_KEY  → GitHub Repository Variable
```

`REMOTE_CONFIG_PRIVATE_KEY` 不参与当前 GitHub Release Workflow。建议保存在密码管理器、离线密钥文件或其他可信密钥管理系统中，不得提交到 Git、上传 CDN 或写入客户端。

### Update 密钥

再次独立生成一套 Update 专用密钥：

```bash
dart run tool/sign_update_manifest.dart generate
```

保存位置：

```text
PRIVATE_KEY → UPDATE_PRIVATE_KEY → release-signing Environment Secret
PUBLIC_KEY  → UPDATE_PUBLIC_KEY  → GitHub Repository Variable
```

两套密钥不得复用。

## Remote Config 配置文件

仓库根目录提供：

[`config.example.json`](./config.example.json)

该文件是 **Remote Config 的未签名模板**。正式部署时不要直接上传模板，而应先复制、修改并签名。

### 1. 创建实际配置

Windows PowerShell：

```powershell
Copy-Item .\config.example.json .\config.local.json
```

Linux/macOS：

```bash
cp config.example.json config.local.json
```

随后编辑 `config.local.json`。

典型内容：

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

`config_version` 用于防止配置回滚。每次正式发布新的 Remote Config 时，应递增该值，例如 `1 → 2 → 3`，不要重复使用更低版本号。

`panel_type` 当前支持：

```text
v2board
xiao_v2board
xboard
```

`api_base_list`、`logo_url`、`avatar_url`、`invite_url_base` 等 URL 必须使用 HTTPS。

### 2. 对配置进行签名

Remote Config 使用 `REMOTE_CONFIG_PRIVATE_KEY` 签名，并由客户端内置的 `REMOTE_CONFIG_PUBLIC_KEY` 验证。

这里执行的是 **数字签名，不是内容加密**。

最终 `config.json` 的结构类似：

```json
{
  "payload_b64": "...",
  "signature": "..."
}
```

`payload_b64` 只是 Base64URL 编码，任何人都可以解码。因此 Remote Config 中不得放置密码、API Secret、Token、私钥或其他需要保密的数据。

#### Windows PowerShell

先仅在当前终端会话设置密钥：

```powershell
$env:REMOTE_CONFIG_PRIVATE_KEY="<REMOTE_CONFIG_PRIVATE_KEY>"
$env:REMOTE_CONFIG_PUBLIC_KEY="<REMOTE_CONFIG_PUBLIC_KEY>"
```

然后执行签名：

```powershell
cmd /c "dart run tool/sign_remote_config.dart sign-env config.local.json > config.json"
```

使用 `cmd /c` 是为了避免 Windows PowerShell 5 的 `>` 重定向将文件写成 UTF-16。生成的 `config.json` 必须保持 UTF-8 JSON。

签名完成后可检查文件：

```powershell
Get-Content .\config.json
```

#### Linux/macOS

```bash
export REMOTE_CONFIG_PRIVATE_KEY='<REMOTE_CONFIG_PRIVATE_KEY>'
export REMOTE_CONFIG_PUBLIC_KEY='<REMOTE_CONFIG_PUBLIC_KEY>'

dart run tool/sign_remote_config.dart sign-env config.local.json > config.json
```

也可以直接将密钥作为参数传入：

```bash
dart run tool/sign_remote_config.dart sign \
  config.local.json \
  <REMOTE_CONFIG_PRIVATE_KEY> \
  <REMOTE_CONFIG_PUBLIC_KEY> \
  > config.json
```

### 3. 上传 `config.json`

只上传签名后的：

```text
config.json
```

不要上传：

```text
config.example.json
config.local.json
REMOTE_CONFIG_PRIVATE_KEY
```

在 Cloudflare R2 中将 `config.json` 放到 Bucket **根目录**，与 `update.json` 同级：

```text
/
├── config.json
├── update.json
└── download/
```

如果使用 Cloudflare Dashboard，可进入对应 R2 Bucket 后直接上传 `config.json` 到根目录。

建议响应头：

```text
Content-Type: application/json
Cache-Control: no-cache, max-age=300
```

上传后必须能够通过下面的地址访问：

```text
${CDN_BASE_URL}/config.json
```

例如：

```text
https://cdn.example.com/config.json
```

### 4. 验证发布结果

浏览器或命令行访问：

```text
https://cdn.example.com/config.json
```

返回内容应为签名封装：

```json
{
  "payload_b64": "...",
  "signature": "..."
}
```

不应直接返回原始配置字段。

客户端启动后会使用编译进客户端的 `REMOTE_CONFIG_PUBLIC_KEY` 验证签名。签名无效、配置被篡改、URL 无效或公钥不匹配时，Remote Config 会被拒绝。

## 构建配置

CI 根据 `CDN_BASE_URL` 自动派生 Remote Config URL，并通过 `--dart-define` 将公开配置注入 Flutter 构建。

例如：

```text
CDN_BASE_URL=https://cdn.example.com
```

CI 自动派生：

```text
REMOTE_CONFIG_URL=https://cdn.example.com/config.json
```

UpdateService 将 `update.json` 解析为 `config.json` 的同级文件，因此无需单独维护 Update Manifest URL。

以下配置不再作为独立 GitHub Variable 或 Secret 使用：

```text
REMOTE_CONFIG_URL
DOWNLOAD_BASE_URL
UPDATE_MANIFEST_URL
```

## 应用发布流程

应用发布由两个 Workflow 组成：

1. `.github/workflows/ci.yml`：构建各平台安装包，并在 `v*` Tag 上创建 GitHub Release。
2. `.github/workflows/publish.yml`：签名 `update.json`，然后将发布文件上传到 R2。

`Publish` Workflow 通过 `workflow_dispatch` 手动触发，并传入目标 Release Tag，例如：

```text
v1.2.3
```

### 签名阶段

`sign` Job 运行在 `release-signing` Environment 中：

- 从指定 GitHub Release 下载发布安装包；
- 计算安装包哈希与版本元数据；
- 使用 `UPDATE_PRIVATE_KEY` 签名 `update.json`；
- 将签名结果交给上传阶段。

`sign` Job 不持有任何 R2 写入凭证。

### 上传阶段

`upload` Job 运行在 `release-upload` Environment 中，上传：

```text
/update.json
/download/<windows-package>.exe
/download/<android-package>.apk
/download/<macos-package>.dmg
```

安装包会先于 `update.json` 上传，避免客户端先读取到新版本清单，却无法下载对应安装包。

`upload` Job 不持有任何签名私钥。

## Release 校验

正式 `v*` Tag Release 使用 Fail Closed 配置校验。

以下配置必须存在：

```text
CDN_BASE_URL
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
API_BASE
```

Android Tag Release 还必须提供：

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

`CDN_BASE_URL` 必须是绝对 HTTPS URL。当前 Ed25519 公钥必须能够解码为有效的 32 字节公钥。

正式发布前应确认目标 Tag 的 CI 完成。随后运行 `Publish` Workflow，并确认：

```text
sign    success
upload  success
```

发布完成后，CDN 应能够访问：

```text
/config.json
/update.json
/download/<release-files>
```

## 密钥轮换

初始部署不需要配置 Previous Key。

需要轮换信任根时，可临时配置：

```text
REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY
UPDATE_PREVIOUS_PUBLIC_KEY
```

每个验签器只能接受自己所属信任域的当前公钥和上一把公钥。Remote Config 与 Update 的密钥在轮换期间仍必须保持完全隔离。

迁移窗口结束后，应删除对应的 `*_PREVIOUS_PUBLIC_KEY`。

## 安全要求

以下安全边界属于当前发布架构的一部分：

- 生产环境 URL 不得硬编码在源码中；
- 签名私钥不得提交到 Git 仓库；
- Remote Config 不得包含任何需要保密的数据；
- 公钥通过 GitHub Repository Variables 注入；
- `config.json` 与 `update.json` 必须使用两套独立 Ed25519 密钥；
- Update 签名 Job 不得持有 R2 写入凭证；
- R2 上传 Job 不得持有任何签名私钥；
- GitHub Actions 的 `uses:` 必须固定到完整 Commit SHA；
- Release 缺少必要配置或配置无效时必须直接失败，不允许降级发布。

修改 CI、签名工具或部署流程时，应保持以上安全边界不变。
