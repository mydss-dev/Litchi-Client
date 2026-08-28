# 远程配置签名密钥管理与轮换

## 为什么这把私钥是"终极凭据"

`REMOTE_CONFIG_PUBLIC_KEY` 在客户端构建时被编译进去，用于验签两样东西：

1. **remote config**（`configUrl` 指向的签名 JSON）—— 决定 API 地址、面板地址等。
2. **update manifest**（`update.json`）—— 决定下载地址与 SHA-256。

对应的私钥 `LITCHI_CONFIG_PRIVATE_KEY` 一旦泄漏，攻击者可以：

- 签发新的 remote config，把客户端 API 地址指到攻击者服务器 → 收割登录 token/凭据；
- 签发新的 `update.json`，指向攻击者托管、通过 SHA 校验的"合法"安装包 → 推送恶意二进制。

因此：**私钥 = 全客户端沦陷能力**。它的存放与使用必须被隔离，并且要能轮换。

## 架构：构建与签名分离

| 工作流 | 触发 | 是否接触私钥 |
|---|---|---|
| `.github/workflows/ci.yml` | push / PR / tag | 否（只烘焙**公钥**，产出安装包并挂到 GitHub Release） |
| `.github/workflows/publish.yml` | **手动** `workflow_dispatch` | 是（在受保护的 `release` 环境里签名 + 上传 R2） |

`ci.yml` 打 tag 时照常构建三种安装包并创建 GitHub Release；**签名和 R2 上传不再自动执行**，改由 `publish.yml` 手动触发，从该 tag 的 GitHub Release 下载安装包 → 签名 `update.json` → 上传 R2。

## 常规发版流程（非轮换）

1. 打 tag `v1.2.3` 推送到 GitHub。
2. `ci.yml` 构建 Windows/Android/macOS 安装包并创建 GitHub Release。
3. 人工触发 `publish.yml`，`tag` 填 `v1.2.3`。
4. `release` 环境要求审批（若配置了 required reviewers），审批通过后自动签名 + 上传。

## Secret 放置位置

`publish.yml` 使用 `environment: release`，这些 secret 必须放在 **仓库 Settings → Environments → release** 下（**不是**仓库级 secret），这样构建工作流永远读不到它们：

- `LITCHI_CONFIG_PRIVATE_KEY`（Ed25519 私钥，base64url）
- `LITCHI_CONFIG_PUBLIC_KEY`（对应公钥）
- `R2_ACCOUNT_ID` / `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` / `R2_BUCKET`
- `DOWNLOAD_BASE_URL`

> `ci.yml` 的构建步骤仍然需要 `REMOTE_CONFIG_PUBLIC_KEY`（公钥，非敏感）作为仓库级 secret/var。

## 密钥轮换流程（双密钥平滑过渡）

客户端会同时信任当前公钥与上一把公钥（`REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY`），因此可以平滑轮换：

1. **生成新密钥对**
   ```bash
   dart run tool/sign_remote_config.dart generate
   ```
   记下新的 `PRIVATE_KEY` 和 `PUBLIC_KEY`（记为 `NEW_PRIV` / `NEW_PUB`），旧的记为 `OLD_PRIV` / `OLD_PUB`。

2. **过渡期构建**（让新客户端同时认两把 key）
   - 构建时加 `--dart-define=REMOTE_CONFIG_PUBLIC_KEY=NEW_PUB`
     `--dart-define=REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY=OLD_PUB`。
   - 即：`REMOTE_CONFIG_PUBLIC_KEY`（仓库 secret，供 ci.yml 用）改成 `NEW_PUB`，
     并在构建命令里加 `REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY=OLD_PUB`。

3. **过渡期仍用旧私钥签名**
   - `release` 环境的 `LITCHI_CONFIG_PRIVATE_KEY` 保持 `OLD_PRIV`，照常发版。
   - 旧客户端只认 `OLD_PUB` → 正常验签；新客户端认 `NEW_PUB` + `OLD_PUB` → 也正常。

4. **等待覆盖**：等一次完整发布周期，让绝大多数旧客户端升级到携带 `NEW_PUB` 的版本。

5. **切换签名密钥**
   - 把 `release` 环境的 `LITCHI_CONFIG_PRIVATE_KEY` 改为 `NEW_PRIV`、
     `LITCHI_CONFIG_PUBLIC_KEY` 改为 `NEW_PUB`，再发版。
   - 此后签名用新私钥，携带新公钥的客户端都能验签。

6. **收尾**
   - 构建命令里移除 `REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY`（不再需要旧公钥）。
   - 彻底销毁 `OLD_PRIV`（未及时升级的存量客户端此后无法再验签——这是轮换的最终边界）。

## 泄漏应急

如果怀疑私钥已泄漏：

1. 立即执行上面的轮换流程，但**跳过过渡期**（不设 `REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY`，直接用新私钥签名）。
2. 立刻用新私钥重签并覆盖线上 `config.json` 与 `update.json`。
3. 审计 `release` 环境的访问日志与审批记录。
4. 通知用户强制升级到携带新公钥的版本。
