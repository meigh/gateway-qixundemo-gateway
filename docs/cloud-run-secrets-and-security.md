# Cloud Migration Phase 1：Cloud Run Secret Manager 配置与安全操作手册

## 1. 文档目的

本文将以下两部分内容合并为一个可直接落库的单文件版本：

1. Secret Manager 命名表 + Cloud Run 注入表 + 安全检查清单
2. Cloud Run 控制台逐步操作清单（专门用于将 `.htpasswd` 挂载到 `qixundemo-gateway`）

本文面向当前项目的 Cloud Migration Phase 1，使用中文说明；涉及 GCP 控制台术语时，尽量同时给出英文原词，便于在中文界面中对照查找。

---

## 2. 适用范围

当前已确认的环境信息：

- GCP Project ID：`aesthetic-vent-480806-g6`
- Region：`asia-northeast1`
- Artifact Registry Repo：`qixun`
- 现有边缘入口服务：`qixundemo-gateway`
- 计划新增服务：
  - `openclaw-poc-gateway`
  - `openclaw-poc-runtime`

当前已确认的安全决策：

- `openclaw-poc-gateway`：**不要匿名开放**
- `openclaw-poc-runtime`：**不要匿名开放**
- `GEMINI_API_KEY`、`TOKEN_KEY`、`ADMIN_PASSWORD`、`.htpasswd`：统一进入 **Secret Manager**
- 单值字符串类 secret：通过 **环境变量** 注入
- 文件型 secret（如 `.htpasswd`）：通过 **挂载文件** 注入

---

## 3. 已确认决策

### 3.1 Cloud Run 访问策略

以下服务不允许匿名访问：

- `openclaw-poc-gateway`
- `openclaw-poc-runtime`

执行原则：

- Cloud Run 控制台中选择 **Require authentication**
  - 中文界面可能显示为：**需要身份验证** / **要求身份验证**
- `gcloud run deploy` 时不使用：

```bash
--allow-unauthenticated
```

- 如需显式声明，可使用：

```bash
--no-allow-unauthenticated
```

### 3.2 Secret 统一管理策略

以下敏感信息统一存入 **Secret Manager**：

- `.htpasswd`
- `GEMINI_API_KEY`
- `TOKEN_KEY`
- `ADMIN_PASSWORD`
- 其他第三方 API Key / 数据库密码 / 回调密钥

禁止出现真实 secret 的位置：

- Git 仓库
- `docs/`
- `conf.d/`
- `Dockerfile`
- 镜像层
- 已提交到版本库的 `.env`

---

## 4. Secret Manager 命名表

建议统一采用：

```text
<service>-<purpose>
```

| Secret 名称 | 用途 | 对应服务 | 注入方式 | 备注 |
|---|---|---|---|---|
| `qixundemo-gateway-basic-auth-htpasswd` | Nginx Basic Auth 文件 | `qixundemo-gateway` | 挂载文件 | 用于 `auth_basic_user_file` |
| `openclaw-poc-gateway-basic-auth-htpasswd` | Nginx Basic Auth 文件 | `openclaw-poc-gateway` | 挂载文件 | 仅在该服务也启用 Basic Auth 时使用 |
| `openclaw-poc-runtime-gemini-api-key` | Gemini API Key | `openclaw-poc-runtime` | 环境变量 | 映射为 `GEMINI_API_KEY` |
| `openclaw-poc-runtime-token-key` | Runtime 内部 token key | `openclaw-poc-runtime` | 环境变量 | 映射为 `TOKEN_KEY` |
| `openclaw-poc-runtime-admin-password` | 管理页面/后台密码 | `openclaw-poc-runtime` | 环境变量 | 映射为 `ADMIN_PASSWORD` |
| `openclaw-poc-gateway-admin-password` | 网关后台密码（如有） | `openclaw-poc-gateway` | 环境变量 | 映射为 `ADMIN_PASSWORD` |

说明：

- 如果 `Admin PW` 只是网页登录密码，它本质上也是 secret，统一放 Secret Manager。
- 如果某个服务根本不需要 `ADMIN_PASSWORD`，则不要预先创建。

---

## 5. Cloud Run 注入表

### 5.1 单值字符串型 secret（推荐用环境变量）

适用范围：

- `GEMINI_API_KEY`
- `TOKEN_KEY`
- `ADMIN_PASSWORD`
- 其他单个字符串密码 / token / key

| Secret Manager 名称 | Cloud Run 环境变量名 | 对应服务 | 注入方式 |
|---|---|---|---|
| `openclaw-poc-runtime-gemini-api-key` | `GEMINI_API_KEY` | `openclaw-poc-runtime` | 环境变量 |
| `openclaw-poc-runtime-token-key` | `TOKEN_KEY` | `openclaw-poc-runtime` | 环境变量 |
| `openclaw-poc-runtime-admin-password` | `ADMIN_PASSWORD` | `openclaw-poc-runtime` | 环境变量 |
| `openclaw-poc-gateway-admin-password` | `ADMIN_PASSWORD` | `openclaw-poc-gateway` | 环境变量 |

控制台建议填写方式：

- 页面：Cloud Run → 服务详情 → **编辑并部署新修订版本**
- 常见区域：**容器、卷、网络、安全性**
  - 英文常见为：`Container(s), Volumes, Networking, Security`
- 在“环境变量和密钥”区域添加 Secret 引用
- 变量名填写应用程序实际读取的环境变量名，例如：`GEMINI_API_KEY`

### 5.2 文件型 secret（推荐用挂载文件）

适用范围：

- `.htpasswd`
- JSON 配置文件
- PEM / CRT / KEY 类证书文件

#### 推荐挂载路径

以 `qixundemo-gateway` 的 `.htpasswd` 为例：

- 挂载目录（Mount path）：

```text
/var/run/secrets/basic-auth
```

- 文件名（Path）：

```text
.htpasswd
```

- 容器内最终文件路径：

```text
/var/run/secrets/basic-auth/.htpasswd
```

#### Nginx 配置示例

```nginx
auth_basic "Restricted";
auth_basic_user_file /var/run/secrets/basic-auth/.htpasswd;
```

注意：

- 这里的路径不是 GCP 预先给定的固定路径，而是部署时由我们自己指定。
- `Mount path` 是目录；`Path` 是文件名。
- 不要把 secret 挂载到已有业务文件目录，避免覆盖或隐藏原目录内容。

---

## 6. 服务账号权限要求

每个 Cloud Run 服务的运行 Service Account 必须具备其所需 Secret 的读取权限。

建议最少权限：

- `Secret Manager Secret Accessor`

建议做法：

- `qixundemo-gateway` 的运行账号只读取它自己的 `.htpasswd`
- `openclaw-poc-runtime` 的运行账号只读取它自己的 `GEMINI_API_KEY` / `TOKEN_KEY` / `ADMIN_PASSWORD`
- 不要让一个服务账号拥有整个项目所有 secret 的访问权

---

## 7. Secret 轮换规则

### 7.1 API Key / Token / Password

轮换步骤：

1. 在 Secret Manager 中为原有 secret 新增一个版本
2. Cloud Run 部署新 revision，绑定新版本
3. 验证新 revision 正常运行
4. 暂时禁用旧版本
5. 观察无异常后，再决定是否销毁旧版本

### 7.2 `.htpasswd`

轮换步骤：

1. 本地生成新的 `.htpasswd`
2. 上传为 Secret Manager 的新版本
3. Cloud Run 挂载该 secret 的新版本并部署新 revision
4. 验证 Basic Auth 正常
5. 禁用旧版本

---

## 8. 安全检查清单

### 8.1 部署前检查

- [ ] `openclaw-poc-gateway` 不匿名开放
- [ ] `openclaw-poc-runtime` 不匿名开放
- [ ] 所有真实 secret 已从 Git 仓库剥离
- [ ] `.htpasswd` 不在仓库、镜像、Dockerfile 中
- [ ] `GEMINI_API_KEY` / `TOKEN_KEY` / `ADMIN_PASSWORD` 已进入 Secret Manager
- [ ] 服务运行账号已授予所需 secret 的读取权限
- [ ] Nginx 配置中的 `auth_basic_user_file` 指向挂载后的实际路径

### 8.2 部署后检查

- [ ] Cloud Run → Security 中显示为 **Require authentication**
- [ ] 未使用 `--allow-unauthenticated`
- [ ] 服务 revision 正常启动
- [ ] 目标环境变量已成功注入
- [ ] `.htpasswd` 文件成功挂载
- [ ] Basic Auth 正常生效
- [ ] 访问受保护路径时，未认证请求被拒绝
- [ ] 应用调用 Gemini / 上游服务正常

### 8.3 日志与异常流量检查

建议持续检查：

- Cloud Run Requests 日志中的 4xx / 5xx
- 异常访问路径：
  - `/runtime/message`
  - `/admin`
  - `/login`
  - `/robots.txt`
  - `/favicon.ico`
- 单一 IP 短时间高频访问
- 非预期 User-Agent
- 审计日志中的以下操作：
  - 服务被修改
  - IAM 被修改
  - Secret 被读取、禁用或轮换

---

## 9. 本地开发机规则

本地机不长期保存生产 secret；若确需临时保存，只允许放在项目外目录。

建议目录：

```text
~/.secrets/gateway-qixundemo-gateway/
```

建议权限：

```bash
chmod 700 ~/.secrets
chmod 700 ~/.secrets/gateway-qixundemo-gateway
chmod 600 ~/.secrets/gateway-qixundemo-gateway/*
```

本地目录中允许临时保存：

- `basic-auth.htpasswd`
- `admin.password`
- `runtime.token`
- `.env.local`

但这些文件：

- 不进入 Git
- 不复制到项目目录
- 不进入 Docker build context

---

# 10. Cloud Run 控制台逐步操作清单：将 `.htpasswd` 挂载到 `qixundemo-gateway`

## 10.1 目标

把 `qixundemo-gateway` 当前使用的 Basic Auth 凭据从本地文件/镜像中迁移到 **Secret Manager**，并通过 **Cloud Run 控制台挂载文件** 的方式提供给容器中的 Nginx。

最终目标路径：

```text
/var/run/secrets/basic-auth/.htpasswd
```

Nginx 使用：

```nginx
auth_basic "Restricted";
auth_basic_user_file /var/run/secrets/basic-auth/.htpasswd;
```

---

## 10.2 前提信息

当前已知：

- Project ID：`aesthetic-vent-480806-g6`
- Region：`asia-northeast1`
- Cloud Run 服务：`qixundemo-gateway`
- 服务 URL：`https://qixundemo-gateway-369629851192.asia-northeast1.run.app`

建议 Secret 名称：

```text
qixundemo-gateway-basic-auth-htpasswd
```

---

## 10.3 第一步：本地生成新的 `.htpasswd`

如果本地已有旧文件，也建议重新生成一份并轮换。

示例：

```bash
htpasswd -c ./htpasswd.new admin
```

说明：

- `admin` 是用户名，可按需改成你们约定的用户名
- 执行后会提示输入密码
- 生成结果会类似：

```text
admin:$apr1$......
```

生成完成后，确认文件内容正常即可，不要把该文件提交到 Git。

---

## 10.4 第二步：在 Secret Manager 创建 secret

### 10.4.1 进入页面

路径建议：

- Google Cloud 控制台
- 搜索 **Secret Manager**
  - 中文界面可能显示为：**Secret Manager** / **机密管理器** / **机密管理**

### 10.4.2 创建 secret

点击：

- **创建 Secret**
  - 英文一般为：`Create secret`

填写：

- Secret 名称：

```text
qixundemo-gateway-basic-auth-htpasswd
```

- Secret 值：把 `.htpasswd` 文件内容粘贴进去

也可以用“上传文件”方式直接上传 `.htpasswd` 文件内容。

创建完成后，记下 secret 名称即可。

---

## 10.5 第三步：确认 Cloud Run 运行账号有权限读取 secret

### 10.5.1 查看运行账号

进入：

- Cloud Run
- 点击 `qixundemo-gateway`
- 查看“安全性 / Security”或“修订版本详情”中的 Service account

记下运行账号邮箱。

### 10.5.2 授权

进入：

- Secret Manager
- 点击 `qixundemo-gateway-basic-auth-htpasswd`
- 打开“权限 / Permissions”
- 给 `qixundemo-gateway` 的运行 Service Account 添加角色：

```text
Secret Manager Secret Accessor
```

如果没有这一步，Cloud Run 即使配置了挂载，也可能在运行时无法读取 secret。

---

## 10.6 第四步：在 Cloud Run 控制台挂载 `.htpasswd`

### 10.6.1 打开服务编辑页

路径：

- Cloud Run
- 点击 `qixundemo-gateway`
- 点击：

```text
编辑并部署新修订版本
```

英文常见为：

```text
Edit and deploy new revision
```

---

### 10.6.2 找到“容器、卷、网络、安全性”页签

英文常见为：

```text
Container(s), Volumes, Networking, Security
```

在中文界面里，通常会看到以下几块：

- 容器
- 卷
- 网络
- 安全性

如果不是完全一致，也请优先寻找“卷”相关区域。

---

### 10.6.3 新增一个 Secret 卷（Volume）

进入“卷”区域后：

1. 点击 **添加卷** / **Add volume**
2. 卷类型选择：

```text
Secret
```

中文界面里通常可理解为：

- 机密
- Secret
- 机密卷

3. 选择 Secret：

```text
qixundemo-gateway-basic-auth-htpasswd
```

4. 设定文件名（Path）：

```text
.htpasswd
```

这里要特别注意：

- **Path 不是目录**
- 这里填的是这个 secret 在卷里呈现的**文件名**

建议给这个 volume 起名，例如：

```text
basic-auth-htpasswd-vol
```

---

### 10.6.4 在容器中挂载这个卷

接着进入“容器”区域，找到“卷挂载”或类似位置。

英文常见为：

```text
Volume mounts
```

中文界面可能会显示为：

- 卷挂载
- 挂载卷
- 装载卷

执行：

1. 点击 **挂载卷** / **Mount volume**
2. 选择刚才创建的 volume，例如：

```text
basic-auth-htpasswd-vol
```

3. 挂载目录（Mount path）填写：

```text
/var/run/secrets/basic-auth
```

注意：

- 这里填的是**目录路径**
- 不要把 `.htpasswd` 写在这里
- 最终文件路径会自动变成：

```text
/var/run/secrets/basic-auth/.htpasswd
```

---

### 10.6.5 检查最终路径关系

这一组配置的逻辑是：

- Mount path：

```text
/var/run/secrets/basic-auth
```

- Path：

```text
.htpasswd
```

组合后的最终结果就是：

```text
/var/run/secrets/basic-auth/.htpasswd
```

这个路径需要和 Nginx 配置里的 `auth_basic_user_file` 完全一致。

---

### 10.6.6 部署新修订版本

确认以下内容无误后，点击部署：

- 已选中正确的 Secret
- 文件名（Path）为 `.htpasswd`
- 挂载目录（Mount path）为 `/var/run/secrets/basic-auth`
- Nginx 配置已使用：

```nginx
auth_basic_user_file /var/run/secrets/basic-auth/.htpasswd;
```

然后点击：

- **部署** / **Deploy**

---

## 10.7 第五步：部署后检查

部署完成后，建议立即检查：

### 10.7.1 Cloud Run 修订版本状态

确认：

- 新 revision 已就绪
- 服务无启动失败日志
- 未出现读取 secret 失败

### 10.7.2 Basic Auth 是否生效

访问受保护路径，检查：

- 未输入账号密码时，应该被拒绝
- 输入正确账号密码后，可以访问
- 输入错误密码时，应拒绝访问

### 10.7.3 Cloud Logging

查看最近日志，确认没有出现：

- secret 挂载失败
- 权限不足
- Nginx 找不到 `.htpasswd`

如果出现类似“permission denied”或“file not found”，优先排查：

1. Service Account 是否有 `Secret Manager Secret Accessor`
2. `Mount path` 是否正确
3. `Path` 是否写成了 `.htpasswd`
4. Nginx 配置路径是否与挂载后的实际路径一致

---

## 11. 推荐的最终定稿

### 11.1 Secret 使用规则

- `GEMINI_API_KEY` → Secret Manager → Cloud Run 环境变量
- `TOKEN_KEY` → Secret Manager → Cloud Run 环境变量
- `ADMIN_PASSWORD` → Secret Manager → Cloud Run 环境变量
- `.htpasswd` → Secret Manager → Cloud Run 挂载文件

### 11.2 新服务开放策略

- `openclaw-poc-gateway`：不要匿名开放
- `openclaw-poc-runtime`：不要匿名开放

### 11.3 网关配置规则

- `.htpasswd` 不进入 Git
- `.htpasswd` 不进入 Dockerfile
- `.htpasswd` 不写入镜像层
- `auth_basic_user_file` 固定指向挂载路径：

```nginx
auth_basic_user_file /var/run/secrets/basic-auth/.htpasswd;
```

---

## 12. 可直接落库的文件建议

建议将本文保存到仓库路径：

```text
docs/cloud-run-secrets-and-security.md
```

如需拆分，也可拆回：

- `docs/cloud-run-secret-manager-and-security-checklist.md`
- `docs/cloud-run-htpasswd-mount-qixundemo-gateway.md`
