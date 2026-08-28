# 签名密钥管理：两套独立信任根

P0-2 要求 Remote Config 与 Update Manifest 使用**两套完全独立**的 Ed25519 keypair，禁止共享 private key 或 public key。

## 信任根划分

```text
Remote Config
  → REMOTE_CONFIG_PRIVATE_KEY     （签名，仅签 config.json）
  → REMOTE_CONFIG_PUBLIC_KEY      （客户端内置，仅验 config.json）
  → REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY （轮换用旧公钥，可为空）

Update Manifest
  → UPDATE_PRIVATE_KEY            （签名，仅签 update.json）
  → UPDATE_PUBLIC_KEY             （客户端内置，仅验 update.json）
  → UPDATE_PREVIOUS_PUBLIC_KEY    （轮换用旧公钥，可为空）
```

**硬性规则：**

- **Remote Config key 绝不允许签署 update manifest。**
- **Update Manifest key 绝不允许签署 remote config。**

## 为什么必须拆开

原先 `REMOTE_CONFIG_PUBLIC_KEY` 同时验证 remote config 与 update manifest，二者共享一个信任根。持有那把私钥的人可以：

- 签发 remote config → 把客户端 API 地址指到攻击者服务器 → 收割 token；
- 签发 update manifest → 指向攻击者托管、通过 SHA 校验的安装包 → 推送恶意二进制。

拆分后，即使 update signing key 泄漏，也无法篡改 remote config（反之亦然），把「全客户端沦陷」降级为「单侧沦陷 + 可轮换恢复」。

## 架构：构建 / 签名 / 上传 三分离

| 工作流 | 触发 | 接触的 secret |
|---|---|---|
| `.github/workflows/ci.yml` | push / PR / tag | 仅公钥（vars 里的 `REMOTE_CONFIG_PUBLIC_KEY`、`UPDATE_PUBLIC_KEY` 及各自 previous） |
| `.github/workflows/publish.yml` `sign` | 手动 `workflow_dispatch` | `UPDATE_PRIVATE_KEY`（公钥走 vars） |
| `.github/workflows/publish.yml` `upload` | 手动 | `R2_*` |

- 签名 job 不碰 R2 凭证；上传 job 不碰任何签名私钥。产物通过 GitHub Artifact 传递。
- 签名 job 里**禁止动态 `pip install`**。boto3 只在 upload job 安装，版本锁定于 `tool/requirements-release.txt`。

## Secret / Variable 放置位置

**GitHub Variables（非敏感，供 ci.yml 构建用）：**

| Variable | 用途 |
|---|---|
| `CDN_BASE_URL` | 唯一的 CDN 根 URL（公开，如 `https://cdn.example.com`） |
| `REMOTE_CONFIG_PUBLIC_KEY` | 验 config.json 的公钥（公开） |
| `REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY` | 轮换用旧公钥（公开，可为空） |
| `UPDATE_PUBLIC_KEY` | 验 update.json 的公钥（公开） |
| `UPDATE_PREVIOUS_PUBLIC_KEY` | 轮换用旧公钥（公开，可为空） |

**GitHub Environments（敏感）：**

| Environment | 放的 secret |
|---|---|
| `release-signing` | `UPDATE_PRIVATE_KEY` |
| `release-upload` | `R2_ACCOUNT_ID`、`R2_ACCESS_KEY_ID`、`R2_SECRET_ACCESS_KEY`、`R2_BUCKET` |

**严禁把私钥放到 Variables**——Variables 是明文、非保护环境。每个 environment 建议配 required reviewers。

## CDN 布局

只维护一个 `CDN_BASE_URL`：

```text
{CDN_BASE_URL}/config.json    ← remote config（root）
{CDN_BASE_URL}/update.json    ← update manifest（root）
{CDN_BASE_URL}/download/*     ← 安装包
```

客户端在构建期注入 `REMOTE_CONFIG_URL = {CDN_BASE_URL}/config.json`，并在运行时把 update manifest 作为其 sibling（`{CDN_BASE_URL}/update.json`）解析。安装包下载 URL 由签名脚本写为 `{CDN_BASE_URL}/download/<name>`。

## 生成 keypair

```bash
dart run tool/sign_remote_config.dart generate      # Remote Config keypair
dart run tool/sign_update_manifest.dart generate     # Update Manifest keypair
```

两个 keypair 必须是**各自独立生成**的，绝不能用同一个私钥复制成两个 secret 名。

## 常规发版流程（非轮换）

1. 打 tag `v1.2.3` 推送到 GitHub。
2. `ci.yml` 构建三种安装包并创建 GitHub Release（只烘焙公钥；正式 tag 会 fail-closed 校验 `CDN_BASE_URL` 与两个公钥）。
3. 手动触发 `publish.yml`，`tag` 填 `v1.2.3`：
   - `sign` 用 UPDATE key 签 `update.json`；
   - `upload` 上传安装包 + `update.json` 到 R2（安装包落在 `download/` 前缀下）。
4. 审批通过后自动完成。`config.json` 由 remote-config key 手动签名并单独上传到 root。

## 轮换：Remote Config key

1. 生成新 keypair：`NEW_PRIV` / `NEW_PUB`，旧的记为 `OLD_PRIV` / `OLD_PUB`。
2. **过渡期构建**：`REMOTE_CONFIG_PUBLIC_KEY=NEW_PUB`、`REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY=OLD_PUB`（改 variables 即可）。
3. 仍用 `OLD_PRIV` 签 config.json，直到覆盖绝大多数客户端。
4. 切换为 `NEW_PRIV` 签名。
5. 收尾：移除 `REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY`，销毁 `OLD_PRIV`。

## 轮换：Update Manifest key

1. 生成新 keypair：`NEW_PRIV` / `NEW_PUB`，旧的记为 `OLD_PRIV` / `OLD_PUB`。
2. **过渡期构建**：`UPDATE_PUBLIC_KEY=NEW_PUB`、`UPDATE_PREVIOUS_PUBLIC_KEY=OLD_PUB`。
3. `release-signing` 环境仍用 `OLD_PRIV` 签 `update.json`。
4. 覆盖后切换为 `NEW_PRIV` 签名，收尾移除 `UPDATE_PREVIOUS_PUBLIC_KEY`、销毁 `OLD_PRIV`。

## 泄漏应急

**Remote Config key 泄漏：**

1. 立即执行 Remote Config 轮换流程，但**跳过过渡期**（不设 previous，直接用新私钥签 config.json）。
2. 用新私钥重签并覆盖线上 config.json。
3. 审计 `release-upload` 与签名环境的相关日志与审批记录。
4. 通知用户强制升级到携带新公钥的版本。

**Update Manifest key 泄漏：**

1. 立即执行 Update Manifest 轮换流程，跳过过渡期。
2. 用新私钥重签并覆盖线上 `update.json`。
3. 审计 `release-signing` 的访问日志与审批记录。
4. 通知用户强制升级到携带新公钥的版本。

> 拆分信任根的价值在此时体现：一个 key 泄漏不会同时危及 remote config 与 update manifest。
