# 签名密钥管理：两套独立信任根

Remote Config 与 Update Manifest 使用两套完全独立的 Ed25519 keypair，禁止共享 private key 或 public key。

## 信任根

```text
Remote Config
  REMOTE_CONFIG_PRIVATE_KEY
  REMOTE_CONFIG_PUBLIC_KEY
  REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY   # 轮换时可选

Update Manifest
  UPDATE_PRIVATE_KEY
  UPDATE_PUBLIC_KEY
  UPDATE_PREVIOUS_PUBLIC_KEY          # 轮换时可选
```

硬性规则：

- Remote Config key 只用于 `config.json`；
- Update key 只用于 `update.json`；
- 两套 verifier 不允许 cross-fallback；
- 私钥不得提交仓库。

## 发布职责

```text
config.json
→ 由维护者手工准备、签名并上传

update.json
→ 由 GitHub Publish Workflow 自动生成、签名并上传
```

Update 私钥只需要配置到：

```text
release-signing → UPDATE_PRIVATE_KEY
```

之后正常发版、Update key 轮换和重新发布均应继续通过 `.github/workflows/publish.yml` 完成，不手工维护线上 `update.json`。

## GitHub Variables

```text
CDN_BASE_URL
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
```

轮换时可临时增加：

```text
REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY
UPDATE_PREVIOUS_PUBLIC_KEY
```

## GitHub Environments

### `release-signing`

```text
UPDATE_PRIVATE_KEY
```

### `release-upload`

```text
R2_ACCOUNT_ID
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
R2_BUCKET
```

安全边界：

- `sign` job 不持有 R2 写入凭证；
- `upload` job 不持有任何 signing private key；
- `REMOTE_CONFIG_PRIVATE_KEY` 不进入应用 Release Workflow。

## CDN 布局

```text
{CDN_BASE_URL}/config.json
{CDN_BASE_URL}/update.json
{CDN_BASE_URL}/download/*
```

其中：

```text
config.json → 手工上传
update.json → Publish Workflow 自动上传
download/*  → Publish Workflow 自动上传
```

## 首次生成 keypair

Remote Config：

```bash
dart run tool/sign_remote_config.dart generate
```

Update：

```bash
dart run tool/sign_update_manifest.dart generate
```

两套 keypair 必须分别独立生成。

## 常规发版

1. 创建并推送 `v*` Tag；
2. `ci.yml` 构建安装包并创建 GitHub Release；
3. 运行 `Publish` Workflow，输入对应 Tag；
4. Workflow 自动：
   - 读取 GitHub Release 安装包；
   - 使用 `UPDATE_PRIVATE_KEY` 自动生成并签名 `update.json`；
   - 上传安装包到 `download/`；
   - 最后上传 `update.json` 到 R2 根目录。

正常发版时不要手工创建、编辑、签名或上传 `update.json`。

## Remote Config key 轮换

1. 生成新的 Remote Config keypair；
2. 新版本客户端配置：

```text
REMOTE_CONFIG_PUBLIC_KEY=NEW_PUB
REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY=OLD_PUB
```

3. 迁移窗口内根据客户端覆盖情况切换 `config.json` 的签名私钥；
4. 覆盖完成后删除 `REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY`；
5. 安全销毁旧私钥。

Remote Config 仍由维护者手工签名和上传。

## Update key 轮换

1. 生成新的 Update keypair；
2. 新版本客户端配置：

```text
UPDATE_PUBLIC_KEY=NEW_PUB
UPDATE_PREVIOUS_PUBLIC_KEY=OLD_PUB
```

3. 迁移窗口内，`release-signing` 继续保存当前应该使用的 Update 私钥；
4. 需要切换到新私钥时，只更新 `release-signing` 中的 `UPDATE_PRIVATE_KEY`；
5. 重新运行正常的 Publish Workflow；
6. Workflow 自动重新生成、签名并上传 `update.json`；
7. 迁移完成后删除 `UPDATE_PREVIOUS_PUBLIC_KEY` 并销毁旧私钥。

不要为了轮换手工修改线上 `update.json`。

## 泄漏应急

### Remote Config private key 泄漏

1. 立即生成新的 Remote Config keypair；
2. 构建携带新公钥的客户端；
3. 使用新 Remote Config 私钥重新签名 `config.json`；
4. 手工覆盖 CDN/R2 根目录的 `config.json`；
5. 撤销并销毁泄漏的旧私钥。

### Update private key 泄漏

1. 立即生成新的 Update keypair；
2. 更新客户端的 Update 公钥配置；
3. 将新的 `UPDATE_PRIVATE_KEY` 写入 `release-signing` Environment；
4. 运行 Publish Workflow；
5. Workflow 自动生成新的签名 `update.json` 并上传；
6. 撤销并销毁泄漏的旧私钥。

即使发生密钥泄漏，也不要跳过现有发布流水线手工维护 `update.json`，避免绕过签名/上传隔离边界。
