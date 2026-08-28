# 签名密钥管理：两套独立信任根

P0-2 要求 Remote Config 与 Update Manifest 使用**两套完全独立**的 Ed25519 keypair，禁止共享 private key 或 public key。

## 信任根划分

```text
Remote Config
  → REMOTE_CONFIG_PRIVATE_KEY     （签名，仅签 remote_config.json）
  → REMOTE_CONFIG_PUBLIC_KEY      （客户端内置，仅验 remote_config.json）
  → REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY （轮换用旧公钥，可为空）

Update Manifest
  → UPDATE_PRIVATE_KEY            （签名，仅签 update-v2.json）
  → UPDATE_PUBLIC_KEY             （客户端内置，仅验 update-v2.json）
  → UPDATE_PREVIOUS_PUBLIC_KEY    （轮换用旧公钥，可为空）
```

**硬性规则：**

- **Remote Config key 绝不允许签署 update manifest。**
- **Update Manifest key 绝不允许签署 remote config。**

（唯一的临时例外见下方「Bridge 迁移」——legacy `update.json` 在过渡期仍由旧 remote-config key 签名，用于把旧客户端升级到 Bridge Release，迁移完成后删除。）

## 为什么必须拆开

原先 `REMOTE_CONFIG_PUBLIC_KEY` 同时验证 remote config 与 update.json，二者共享一个信任根。持有那把私钥的人可以：

- 签发 remote config → 把客户端 API 地址指到攻击者服务器 → 收割 token；
- 签发 update.json → 指向攻击者托管、通过 SHA 校验的安装包 → 推送恶意二进制。

拆分后，即使 update signing key 泄漏，也无法篡改 remote config（反之亦然），把「全客户端沦陷」降级为「单侧沦陷 + 可轮换恢复」。

## 架构：构建 / 签名 / 上传 三分离

| 工作流 | 触发 | 接触的 secret |
|---|---|---|
| `.github/workflows/ci.yml` | push / PR / tag | 仅公钥（REMOTE_CONFIG_PUBLIC_KEY、UPDATE_PUBLIC_KEY 及各自 previous） |
| `.github/workflows/publish.yml` `sign` | 手动 `workflow_dispatch` | UPDATE_PRIVATE_KEY、UPDATE_PUBLIC_KEY |
| `.github/workflows/publish.yml` `sign-legacy` | 手动（bridge 期） | REMOTE_CONFIG_PRIVATE_KEY、REMOTE_CONFIG_PUBLIC_KEY |
| `.github/workflows/publish.yml` `upload` | 手动 | R2_*、DOWNLOAD_BASE_URL |

- 签名 job 不碰 R2 凭证；上传 job 不碰任何签名私钥。产物通过 GitHub Artifact 传递。
- 签名 job 里**禁止动态 `pip install`**。boto3 只在 upload job 安装，版本锁定于 `tool/requirements-release.txt`。

## Secret 放置位置（GitHub Environments）

| Environment | 放的 secret |
|---|---|
| `release-signing` | `UPDATE_PRIVATE_KEY`、`UPDATE_PUBLIC_KEY` |
| `release-legacy`（bridge 期，之后删） | `REMOTE_CONFIG_PRIVATE_KEY`、`REMOTE_CONFIG_PUBLIC_KEY` |
| `release-upload` | `R2_ACCOUNT_ID`、`R2_ACCESS_KEY_ID`、`R2_SECRET_ACCESS_KEY`、`R2_BUCKET` |

仓库级（非敏感，供 ci.yml 构建用）：`REMOTE_CONFIG_PUBLIC_KEY`、`REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY`、`UPDATE_PUBLIC_KEY`、`UPDATE_PREVIOUS_PUBLIC_KEY`、`DOWNLOAD_BASE_URL`（公开 URL）。

每个 environment 建议配 required reviewers。不要把签名私钥放到仓库级 secret。

## 生成 keypair

```bash
dart run tool/sign_remote_config.dart generate      # Remote Config keypair
dart run tool/sign_update_manifest.dart generate     # Update Manifest keypair
```

两个 keypair 必须是**各自独立生成**的，绝不能用同一个私钥复制成两个 secret 名。

## 常规发版流程（非轮换）

1. 打 tag `v1.2.3` 推送到 GitHub。
2. `ci.yml` 构建三种安装包并创建 GitHub Release（只烘焙公钥）。
3. 手动触发 `publish.yml`，`tag` 填 `v1.2.3`：
   - `sign` 用 UPDATE key 签 `update-v2.json`；
   - `sign-legacy`（bridge 期）用 remote-config key 签 legacy `update.json`；
   - `upload` 上传安装包 + 两个 manifest 到 R2。
4. 审批通过后自动完成。

## 轮换：Remote Config key

1. 生成新 keypair：`NEW_PRIV` / `NEW_PUB`，旧的记为 `OLD_PRIV` / `OLD_PUB`。
2. **过渡期构建**：`REMOTE_CONFIG_PUBLIC_KEY=NEW_PUB`、`REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY=OLD_PUB`（ci.yml 里改 secret 即可）。
3. `release-legacy` 环境（或签名 remote config 的地方）仍用 `OLD_PRIV` 签 remote config。
4. 等一个完整发布周期覆盖绝大多数客户端后，切换为 `NEW_PRIV` 签名。
5. 收尾：移除 `REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY`，销毁 `OLD_PRIV`。

## 轮换：Update Manifest key

1. 生成新 keypair：`NEW_PRIV` / `NEW_PUB`，旧的记为 `OLD_PRIV` / `OLD_PUB`。
2. **过渡期构建**：`UPDATE_PUBLIC_KEY=NEW_PUB`、`UPDATE_PREVIOUS_PUBLIC_KEY=OLD_PUB`。
3. `release-signing` 环境仍用 `OLD_PRIV` 签 `update-v2.json`。
4. 覆盖后切换为 `NEW_PRIV` 签名，收尾移除 `UPDATE_PREVIOUS_PUBLIC_KEY`、销毁 `OLD_PRIV`。

## Bridge 迁移：把旧客户端平滑切到独立 Update key

旧客户端只认 `REMOTE_CONFIG_PUBLIC_KEY`，并同时用它验 remote config 和 `update.json`。不能直接把唯一 `update.json` 换成 UPDATE key 签名，否则旧客户端更新断链。

迁移步骤：

1. **生成 Update keypair**（`UPDATE_PRIV` / `UPDATE_PUB`）。
2. **发布 Bridge Release**：客户端同时内置 `REMOTE_CONFIG_PUBLIC_KEY` 与 `UPDATE_PUBLIC_KEY`；Remote Config 走 remote key，Update Manifest 走 update key。
3. **同时发布两份 manifest**：
   - `update.json` → 仍用旧 remote-config key 签名（`sign-legacy` job），供旧客户端升级到 Bridge；
   - `update-v2.json` → 用 UPDATE key 签名（`sign` job），供 Bridge+ 客户端使用。
   - Bridge 客户端请求 `update-v2.json`（`REMOTE_CONFIG_URL` 的 sibling，或 remote config 里的 `update_manifest_v2_url`）。
4. **等待覆盖**：等绝大多数旧客户端升级到 Bridge Release（已携带 `UPDATE_PUBLIC_KEY`）。
5. **停止 legacy**：删除 `sign-legacy` job、停止发布 `update.json`，remote-config key 从此只签 remote config。

**何时删除 legacy manifest / previous key：** 当线上存量旧客户端（只认 remote key 的版本）占比已降到可接受水平——通常是一个完整发布周期之后——即可停止 `update.json` 并删除 `sign-legacy` job；轮换用的 previous key 则在下一轮切换完成、旧签名不再被需要时删除。

## 泄漏应急

**Remote Config key 泄漏：**

1. 立即执行 Remote Config 轮换流程，但**跳过过渡期**（不设 previous，直接用新私钥签 remote config）。
2. 用新私钥重签并覆盖线上 remote_config.json。
3. 审计 `release-legacy` 的访问日志与审批记录。
4. 通知用户强制升级到携带新公钥的版本。

**Update Manifest key 泄漏：**

1. 立即执行 Update Manifest 轮换流程，跳过过渡期。
2. 用新私钥重签并覆盖线上 `update-v2.json`。
3. 审计 `release-signing` 的访问日志与审批记录。
4. 通知用户强制升级到携带新公钥的版本。

> 拆分信任根的价值在此时体现：一个 key 泄漏不会同时危及 remote config 与 update manifest。
