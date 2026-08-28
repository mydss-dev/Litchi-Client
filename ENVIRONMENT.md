# Litchi Client — GitHub 环境配置清单

> 目标：以后**不在源码里填写真实 URL / 公钥 / 私钥**。  
> 日常只维护 GitHub Variables / Secrets。  
> 当前项目是新项目，不需要 Legacy Bridge / `update-v2.json`。

---

## 1. 最终 URL 规则

只维护一个：

```text
CDN_BASE_URL=https://cdn.example.com
```

项目自动派生：

```text
Remote Config:
https://cdn.example.com/config.json

Update Manifest:
https://cdn.example.com/update.json

安装包:
https://cdn.example.com/download/xxx.exe
https://cdn.example.com/download/xxx.apk
https://cdn.example.com/download/xxx.dmg
```

R2 目录结构：

```text
/
├── config.json
├── update.json
└── download/
    ├── Litchi-Setup-x.x.x.exe
    ├── Litchi-x.x.x.apk
    └── Litchi-x.x.x.dmg
```

`download` 必须小写。

---

# 2. Repository Variables

位置：

```text
GitHub Repository
→ Settings
→ Secrets and variables
→ Actions
→ Variables
```

## 必填

| 状态 | Variable | 填什么 |
|---|---|---|
| ☐ | `CDN_BASE_URL` | CDN 根地址，例如 `https://cdn.example.com`，不要填 `/config.json` |
| ☐ | `REMOTE_CONFIG_PUBLIC_KEY` | Remote Config 的 Ed25519 公钥 |
| ☐ | `UPDATE_PUBLIC_KEY` | Update Manifest 的 Ed25519 公钥 |

## 暂时不要创建

新项目现在不需要密钥轮换，所以先不要建：

```text
REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY
UPDATE_PREVIOUS_PUBLIC_KEY
```

以后真正换密钥时再使用。

---

# 3. 生成两套独立密钥

**必须生成两次。不要共用同一套密钥。**

先在项目根目录执行：

```bash
flutter pub get
```

## A. Remote Config 密钥

执行：

```bash
dart run tool/sign_remote_config.dart generate
```

会输出：

```text
PRIVATE_KEY=xxxxxxxx
PUBLIC_KEY=xxxxxxxx
```

对应关系：

```text
PRIVATE_KEY
→ REMOTE_CONFIG_PRIVATE_KEY
→ 私钥，不能提交 Git

PUBLIC_KEY
→ REMOTE_CONFIG_PUBLIC_KEY
→ 放 Repository Variables
```

### Remote Config 私钥怎么保存

当前 GitHub Release workflow **不需要** `REMOTE_CONFIG_PRIVATE_KEY`。

推荐：

```text
REMOTE_CONFIG_PRIVATE_KEY
→ 本地离线保存 / 密码管理器保存
```

不要放源码，不要发到群里，不要和 Update 私钥共用。

---

## B. Update 密钥

执行：

```bash
dart run tool/sign_update_manifest.dart generate
```

会输出：

```text
PRIVATE_KEY=yyyyyyyy
PUBLIC_KEY=yyyyyyyy
```

对应关系：

```text
PRIVATE_KEY
→ UPDATE_PRIVATE_KEY
→ release-signing Environment Secret

PUBLIC_KEY
→ UPDATE_PUBLIC_KEY
→ Repository Variables
```

### 硬要求

```text
REMOTE_CONFIG_PUBLIC_KEY != UPDATE_PUBLIC_KEY
REMOTE_CONFIG_PRIVATE_KEY != UPDATE_PRIVATE_KEY
```

必须是两次独立生成。

---

# 4. GitHub Environments

位置：

```text
GitHub Repository
→ Settings
→ Environments
```

创建两个 Environment：

```text
release-signing
release-upload
```

---

## Environment 1：release-signing

进入：

```text
Settings
→ Environments
→ release-signing
```

在 **Environment secrets** 添加：

| 状态 | Secret | 用途 |
|---|---|---|
| ☐ | `UPDATE_PRIVATE_KEY` | 只用于签名 `update.json` |

这里只放 Update 私钥。

**不要放：**

```text
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
REMOTE_CONFIG_PRIVATE_KEY
```

---

## Environment 2：release-upload

进入：

```text
Settings
→ Environments
→ release-upload
```

在 **Environment secrets** 添加：

| 状态 | Secret | 用途 |
|---|---|---|
| ☐ | `R2_ACCOUNT_ID` | Cloudflare R2 Account ID |
| ☐ | `R2_ACCESS_KEY_ID` | R2 Access Key |
| ☐ | `R2_SECRET_ACCESS_KEY` | R2 Secret Key |
| ☐ | `R2_BUCKET` | R2 Bucket 名称 |

这里只负责上传。

**不要放：**

```text
UPDATE_PRIVATE_KEY
REMOTE_CONFIG_PRIVATE_KEY
```

---

# 5. Repository Secrets

位置：

```text
GitHub Repository
→ Settings
→ Secrets and variables
→ Actions
→ Secrets
```

下面这些属于普通 CI / 应用构建配置。

## 正式 Tag Release 必需

| 状态 | Secret | 说明 |
|---|---|---|
| ☐ | `API_BASE` | 客户端编译时 API fallback；当前 `v*` Tag Release 要求必须存在 |

## Android 正式 Release 必需

如果要发布 Android：

| 状态 | Secret |
|---|---|
| ☐ | `ANDROID_KEYSTORE_BASE64` |
| ☐ | `ANDROID_KEYSTORE_PASSWORD` |
| ☐ | `ANDROID_KEY_ALIAS` |
| ☐ | `ANDROID_KEY_PASSWORD` |

缺少这些时，正式 `v*` Android Release 会失败。

## 可选

| Secret | 说明 |
|---|---|
| `APP_NAME` | 不填默认 `Litchi` |
| `LOGO_URL` | 不填使用内置图标 |

---

# 6. 最终应该长这样

## Repository Variables

```text
CDN_BASE_URL
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
```

### 暂不需要

```text
REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY
UPDATE_PREVIOUS_PUBLIC_KEY
```

---

## Repository Secrets

```text
API_BASE

ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD

APP_NAME          # 可选
LOGO_URL          # 可选
```

---

## release-signing / Environment Secrets

```text
UPDATE_PRIVATE_KEY
```

---

## release-upload / Environment Secrets

```text
R2_ACCOUNT_ID
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
R2_BUCKET
```

---

## 本地离线保存

```text
REMOTE_CONFIG_PRIVATE_KEY
```

---

# 7. 可以删除的旧配置

新架构已经不再需要：

```text
REMOTE_CONFIG_URL
DOWNLOAD_BASE_URL
UPDATE_MANIFEST_URL
```

也不要再把下面两个公钥放 Secrets：

```text
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
```

它们应该在：

```text
Actions → Variables
```

如果旧 Secrets 中存在同名公钥：

1. 先确认 Variables 已经创建并填写正确；
2. 再删除 Secrets 里的旧公钥。

---

# 8. Remote Config：生成 config.json

`config.json` 使用：

```text
REMOTE_CONFIG_PRIVATE_KEY
+
REMOTE_CONFIG_PUBLIC_KEY
```

签名。

例如本地：

```bash
dart run tool/sign_remote_config.dart sign payload.json YOUR_REMOTE_PRIVATE_KEY YOUR_REMOTE_PUBLIC_KEY > config.json
```

或者先在本地临时设置环境变量，再使用：

```bash
dart run tool/sign_remote_config.dart sign-env payload.json > config.json
```

**注意：**

生成后的 `config.json` 可以上传 CDN/R2。

私钥不能上传 CDN。

---

# 9. Update：update.json

正式发布时，GitHub `publish.yml` 会：

```text
GitHub Release 安装包
        ↓
release-signing
        ↓
UPDATE_PRIVATE_KEY 签名
        ↓
update.json
        ↓
release-upload
        ↓
R2
```

最终：

```text
/update.json
/download/*.exe
/download/*.apk
/download/*.dmg
```

Update 验签只使用：

```text
UPDATE_PUBLIC_KEY
```

Remote Config 验签只使用：

```text
REMOTE_CONFIG_PUBLIC_KEY
```

两套密钥不能交叉。

---

# 10. 填完以后怎么验证

## 第一步：普通 CI

进入：

```text
GitHub
→ Actions
→ CI
→ Run workflow
→ main
```

检查：

```text
Resolve release config
```

Windows / Android / macOS 都不应该报配置错误。

> 普通 `main` 构建不是最终生产配置校验，因为严格校验主要发生在 `v*` Tag Release。

---

## 第二步：正式 Tag 前检查

确认：

```text
CDN_BASE_URL
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
API_BASE
Android signing secrets
```

全部存在。

并确认两个公钥是**两次独立生成**的。

---

## 第三步：Publish

正式 Tag 的 GitHub Release 产生安装包后，再运行：

```text
Actions
→ Publish
→ Run workflow
```

输入：

```text
v1.2.3
```

预期：

```text
sign       ✅
upload     ✅
```

R2 最终应该看到：

```text
config.json
update.json
download/...
```

---

# 11. 最简 Checklist

按顺序打勾：

```text
[ ] 创建 CDN_BASE_URL
[ ] 生成 Remote Config keypair
[ ] REMOTE_CONFIG_PUBLIC_KEY → Variables
[ ] REMOTE_CONFIG_PRIVATE_KEY → 离线保存

[ ] 生成第二套 Update keypair
[ ] UPDATE_PUBLIC_KEY → Variables
[ ] UPDATE_PRIVATE_KEY → release-signing

[ ] 创建 release-signing Environment
[ ] 创建 release-upload Environment

[ ] R2_ACCOUNT_ID → release-upload
[ ] R2_ACCESS_KEY_ID → release-upload
[ ] R2_SECRET_ACCESS_KEY → release-upload
[ ] R2_BUCKET → release-upload

[ ] API_BASE 已存在
[ ] Android 4 个签名 Secret 已存在

[ ] 删除旧 REMOTE_CONFIG_URL
[ ] 删除旧 DOWNLOAD_BASE_URL
[ ] 公钥不再放 Secrets

[ ] CI 验证
[ ] 创建正式 Tag
[ ] Publish 验证
[ ] 检查 R2 /config.json
[ ] 检查 R2 /update.json
[ ] 检查 R2 /download/
```

---

# 12. 当前配置的核心原则

只记住这张表即可：

| 文件 / 功能 | 私钥 | 公钥 |
|---|---|---|
| `config.json` | `REMOTE_CONFIG_PRIVATE_KEY` | `REMOTE_CONFIG_PUBLIC_KEY` |
| `update.json` | `UPDATE_PRIVATE_KEY` | `UPDATE_PUBLIC_KEY` |

以及：

```text
URL → Variables
Public Key → Variables
Private Key → Secrets / Offline
R2 凭证 → release-upload Secrets
Update 私钥 → release-signing Secret
```

不要在源码中填写任何真实部署值。
