# 签名密钥管理：两套独立信任根

Config 与 Update Manifest 使用两套完全独立的 Ed25519 keypair，禁止共享 private key 或 public key。

## 信任根

```text
Config
  CONFIG_PRIVATE_KEY
  CONFIG_PUBLIC_KEY
  CONFIG_PREVIOUS_PUBLIC_KEY   # 轮换时可选

Update Manifest
  UPDATE_PRIVATE_KEY
  UPDATE_PUBLIC_KEY
  UPDATE_PREVIOUS_PUBLIC_KEY   # 轮换时可选
```

规则：

- Config key 只用于 `config.json`；
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

## GitHub Repository Variables

```text
CDN_BASE_URL
CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
```

轮换时可临时增加：

```text
CONFIG_PREVIOUS_PUBLIC_KEY
UPDATE_PREVIOUS_PUBLIC_KEY
```

## GitHub Repository Secrets

自动更新启用时：

```text
UPDATE_PRIVATE_KEY
R2_ACCOUNT_ID
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
R2_BUCKET
```

`CONFIG_PRIVATE_KEY` 保存在维护者本地，不进入 GitHub Actions。

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

Config：

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
   - 使用 Repository Secret `UPDATE_PRIVATE_KEY` 生成并签名 `update.json`；
   - 使用 Repository Secrets 中的 R2 凭证上传安装包到 `download/`；
   - 最后上传 `update.json` 到 R2 根目录。

## Config key 轮换

1. 生成新的 Config keypair；
2. 新版本客户端配置：

```text
CONFIG_PUBLIC_KEY=NEW_PUB
CONFIG_PREVIOUS_PUBLIC_KEY=OLD_PUB
```

3. 迁移窗口内根据客户端覆盖情况切换 `config.json` 的签名私钥；
4. 覆盖完成后删除 `CONFIG_PREVIOUS_PUBLIC_KEY`；
5. 安全销毁旧私钥。

Config 仍由维护者手工签名和上传。

## Update key 轮换

1. 生成新的 Update keypair；
2. 新版本客户端配置：

```text
UPDATE_PUBLIC_KEY=NEW_PUB
UPDATE_PREVIOUS_PUBLIC_KEY=OLD_PUB
```

3. 在 Repository Secrets 中把 `UPDATE_PRIVATE_KEY` 更新为当前应该使用的私钥；
4. 重新运行 Publish Workflow；
5. Workflow 自动重新生成、签名并上传 `update.json`；
6. 迁移完成后删除 `UPDATE_PREVIOUS_PUBLIC_KEY` 并销毁旧私钥。

## 泄漏应急

### Config private key 泄漏

1. 立即生成新的 Config keypair；
2. 构建携带新公钥的客户端；
3. 使用新 Config 私钥重新签名 `config.json`；
4. 手工覆盖 CDN/R2 根目录的 `config.json`；
5. 撤销并销毁泄漏的旧私钥。

### Update private key 泄漏

1. 立即生成新的 Update keypair；
2. 更新客户端的 Update 公钥配置；
3. 将新的 `UPDATE_PRIVATE_KEY` 写入 Repository Secrets；
4. 运行 Publish Workflow；
5. Workflow 自动生成新的签名 `update.json` 并上传；
6. 撤销并销毁泄漏的旧私钥。
