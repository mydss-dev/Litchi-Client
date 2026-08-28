# 环境配置

本文档说明构建、签名和发布 Litchi Client 所需的部署配置。

项目不会在源码中保存生产环境 URL、签名私钥或其他敏感值。运行时与发布配置由 GitHub Actions 通过 Repository Variables、Repository Secrets 和 GitHub Environments 注入。Remote Config 与 Update Manifest 使用两套相互独立的 Ed25519 信任根。

## 配置模型

项目只维护一个 CDN 根地址：

```text
CDN_BASE_URL=https://cdn.example.com
```

构建和发布流程会基于该地址自动派生所有公开资源路径：

```text
Remote Config        https://cdn.example.com/config.json
Update Manifest      https://cdn.example.com/update.json
安装包下载            https://cdn.example.com/download/<filename>
```

Cloudflare R2 的预期对象结构如下：

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
| `CDN_BASE_URL` | 是 | 对外公开的 HTTPS CDN 根地址。不要附加 `config.json`、`update.json` 或 `download` 路径。 |
| `REMOTE_CONFIG_PUBLIC_KEY` | 是 | Base64URL 编码的 Ed25519 公钥，用于验证 `config.json`。 |
| `UPDATE_PUBLIC_KEY` | 是 | Base64URL 编码的 Ed25519 公钥，用于验证 `update.json`。 |
| `REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY` | 否 | Remote Config 上一把公钥，仅在密钥轮换期间使用。 |
| `UPDATE_PREVIOUS_PUBLIC_KEY` | 否 | Update 上一把公钥，仅在密钥轮换期间使用。 |

新部署只需要前三项。`*_PREVIOUS_PUBLIC_KEY` 在未执行密钥轮换时应保持未配置状态。

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
| `LOGO_URL` | 否 | 可选的品牌 Logo 地址，未设置时使用项目内置资源。 |

Ed25519 公钥属于公开配置，应放在 Repository Variables，不应放在 Repository Secrets。

## GitHub Environments

发布流程通过两个独立的 GitHub Environment 隔离签名凭证与上传凭证。

配置位置：

`Settings → Environments`

需要创建以下两个 Environment：

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

## Remote Config 私钥

当前 GitHub Release Workflow 不需要 `REMOTE_CONFIG_PRIVATE_KEY`，因为 `config.json` 与应用版本发布相互独立。

应将 `REMOTE_CONFIG_PRIVATE_KEY` 保存在离线环境或可信的密钥管理系统中。该私钥不得提交到 Git 仓库，也不得上传到 CDN 或 R2。

## 生成签名密钥

首先安装项目依赖：

```bash
flutter pub get
```

### 生成 Remote Config 密钥

执行：

```bash
dart run tool/sign_remote_config.dart generate
```

命令会输出：

```text
PRIVATE_KEY=<base64url-private-key>
PUBLIC_KEY=<base64url-public-key>
```

对应保存位置：

```text
PRIVATE_KEY → REMOTE_CONFIG_PRIVATE_KEY → 离线密钥存储
PUBLIC_KEY  → REMOTE_CONFIG_PUBLIC_KEY  → GitHub Repository Variable
```

### 生成 Update 密钥

再次独立生成一套密钥：

```bash
dart run tool/sign_update_manifest.dart generate
```

对应保存位置：

```text
PRIVATE_KEY → UPDATE_PRIVATE_KEY → release-signing Environment Secret
PUBLIC_KEY  → UPDATE_PUBLIC_KEY  → GitHub Repository Variable
```

两套密钥不得复用。

## 构建配置

CI 会根据 `CDN_BASE_URL` 自动派生 Remote Config URL，并通过 `--dart-define` 将公开配置注入 Flutter 构建。

例如：

```text
CDN_BASE_URL=https://cdn.example.com
```

CI 自动派生：

```text
REMOTE_CONFIG_URL=https://cdn.example.com/config.json
```

UpdateService 会将 `update.json` 解析为 `config.json` 的同级文件，因此无需单独维护 Update Manifest URL。

以下配置不再作为独立的 GitHub Variable 或 Secret 使用：

```text
REMOTE_CONFIG_URL
DOWNLOAD_BASE_URL
UPDATE_MANIFEST_URL
```

## 生成 `config.json`

Remote Config 使用 Remote Config 独立密钥进行签名。

假设未签名配置为 `config-payload.json`，可执行：

```bash
dart run tool/sign_remote_config.dart sign \
  config-payload.json \
  <REMOTE_CONFIG_PRIVATE_KEY> \
  <REMOTE_CONFIG_PUBLIC_KEY> \
  > config.json
```

也可以先在本地环境变量中设置密钥，再执行：

```bash
dart run tool/sign_remote_config.dart sign-env config-payload.json > config.json
```

生成后的 `config.json` 可发布到 CDN/R2 根目录：

```text
https://cdn.example.com/config.json
```

签名私钥必须始终保留在离线环境中。

## 发布流程

应用发布由两个 Workflow 组成：

1. `.github/workflows/ci.yml`：构建各平台安装包，并在 `v*` Tag 上创建 GitHub Release。
2. `.github/workflows/publish.yml`：签名 `update.json`，然后将发布文件上传到 R2。

`Publish` Workflow 通过 `workflow_dispatch` 手动触发，并传入目标 Release Tag，例如：

```text
v1.2.3
```

### 签名阶段

`sign` Job 运行在 `release-signing` Environment 中。

主要流程：

- 从指定 GitHub Release 下载 `.exe`、`.apk` 和 `.dmg`；
- 计算安装包哈希与发布元数据；
- 使用 `UPDATE_PRIVATE_KEY` 签名 `update.json`；
- 将签名后的发布产物传递给上传阶段。

`sign` Job 不持有任何 R2 写入凭证。

### 上传阶段

`upload` Job 运行在 `release-upload` Environment 中。

上传目标：

```text
/update.json
/download/<windows-package>.exe
/download/<android-package>.apk
/download/<macos-package>.dmg
```

安装包会先于 `update.json` 上传，避免客户端先读取到新版本清单，却无法下载对应安装包。

`upload` Job 不持有任何签名私钥。

## Release 校验

正式 `v*` Tag Release 采用 Fail Closed 配置校验。

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

正式发布前，应先确认目标 Tag 的 CI 全部完成。随后运行 `Publish` Workflow，并确认：

```text
sign    success
upload  success
```

发布完成后，CDN 应能访问以下资源：

```text
/config.json
/update.json
/download/<release-files>
```

## 密钥轮换

初始部署不需要配置 Previous Key。

当需要轮换信任根时，可以临时配置：

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
- 公钥通过 GitHub Repository Variables 注入；
- `config.json` 与 `update.json` 必须使用两套独立 Ed25519 密钥；
- Update 签名 Job 不得持有 R2 写入凭证；
- R2 上传 Job 不得持有任何签名私钥；
- GitHub Actions 的 `uses:` 必须继续固定到完整 Commit SHA；
- Release 缺少必要配置或配置无效时必须直接失败，不允许降级发布。

修改 CI、签名工具或部署流程时，应保持以上边界不变。
