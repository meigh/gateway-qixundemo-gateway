# Cloud Migration Phase 1 总结与对齐手册

## 1. 本次开发成果、经验教训、踩坑点

### 1.1 本次开发成果

本轮工作已经完成两条主线。

#### 主线 A：Cloud Migration Phase 1 主链路打通

已完成：

- `openclaw-poc-gateway` 已部署到 Cloud Run
- `openclaw-poc-runtime` 已部署到 Cloud Run
- `https://gateway.qixundemo.com/runtime/message` 已打通
- Edge Gateway 已能把 `/runtime/message` 正确 rewrite 到 runtime 的 `/message`

最终验证结果：

- `GET https://gateway.qixundemo.com/runtime/`
  - 返回 `404 {"detail":"Not Found"}`
  - 这是合理现象，因为 runtime 根路径未定义
- `POST https://gateway.qixundemo.com/runtime/message`
  - 返回 `200`
  - runtime 已实际处理请求并返回 JSON

#### 主线 B：网关安全收口

已完成：

- `qixundemo-gateway` 的 `.htpasswd` 已从镜像内置迁移到 Secret Manager 文件挂载
- `Dockerfile` 已不再包含 `.htpasswd`
- `auth_basic_user_file` 已改为：
  - `/etc/nginx/secrets/.htpasswd`
- Cloud Run 已通过 Secret Manager 挂载：
  - `qixundemo-gateway-htpasswd`
- 迁移后功能验证通过，Basic Auth 仍然正常工作

#### 主线 C：仓库与 Git 规范收口

已完成：

- `conf.d/routes/*.conf` 已纳入 Git
- `.htpasswd` 已通过 `.gitignore` 排除，不再进 Git
- `conf.d/` 不再整体忽略
- `docs/cloud-migration-phase1-acceptance.md` 已落库并推送到 GitHub
- `docs/cloud-run-secrets-and-security.md` 已落库并推送到 GitHub

### 1.2 经验教训

#### 经验 1：Phase 1 要先打通“最短主链路”
先确认 runtime、gateway、Edge Gateway 三段都能跑，再补安全收口，这条路径是对的。

#### 经验 2：Cloud Run 私有访问与 Nginx 代理是两层问题
实际遇到的是两层：
- 第一层：Nginx Basic Auth
- 第二层：Cloud Run 私有服务认证

#### 经验 3：先用真实验证结果反推架构，比空想更快
最终验证出 runtime 真正入口是 `POST /message`，所以外部 `/runtime/message` 应由 Edge Gateway rewrite。

#### 经验 4：Secret 挂载最好保持“路径兼容”或“最小改动”
最终采用：
- Nginx 读取 `/etc/nginx/secrets/.htpasswd`
- Cloud Run secret 挂到 `/etc/nginx/secrets`

### 1.3 踩坑点

- 旧 Dockerfile 不适配当前 `gateway/`、`runtime/` 目录结构
- `gcloud builds submit` 不支持 `--file`
- WSL 下 `gcloud auth login` 不会自动打开浏览器
- `proxy_pass https://$upstream` 容易引发 502
- Basic Auth 的 `Authorization` 头会被转发到上游
- Cloud Run Secret 挂载到 `/etc/nginx` 会遮住原目录内容
- `.gitignore` 一开始把整个 `conf.d/` 都忽略了

## 2. 目前 Cloud Run 上运行的服务主要信息总结

### 2.1 `qixundemo-gateway`
用途：
- Edge Gateway
- 对外承接：
  - `gateway.qixundemo.com`
  - `api.qixundemo.com`

当前特征：
- 通过 Basic Auth 保护入口
- `.htpasswd` 已改为 Secret Manager 挂载
- 已新增 `/runtime/*` 路由
- `/runtime/message` 可桥接到 `openclaw-poc-runtime`

域名映射：
- `gateway.qixundemo.com -> qixundemo-gateway`
- `api.qixundemo.com -> qixundemo-gateway`

关键配置点：
- `conf.d/default.conf`
- `conf.d/routes/15-openclaw-poc-runtime.conf`

### 2.2 `openclaw-poc-runtime`
用途：
- openclaw runtime 服务
- 当前 Phase 1 主链路真正处理端

Cloud Run 信息：
- Region：`asia-northeast1`
- URL：`https://openclaw-poc-runtime-369629851192.asia-northeast1.run.app`

已验证接口：
- `POST /message`：正常
- `GET /`：404，合理
- `/healthz`：线上与本地预期有差异，后续收口

当前状态：
- 为打通 Phase 1，当前 runtime 为临时允许公开访问
- 后续建议收回为私有访问，并设计正式 service-to-service 认证

### 2.3 `openclaw-poc-gateway`
用途：
- openclaw gateway 服务
- 当前是独立 Cloud Run 服务，但不是 `/runtime/message` 的最终处理端

Cloud Run 信息：
- Region：`asia-northeast1`
- URL：`https://openclaw-poc-gateway-369629851192.asia-northeast1.run.app`

已验证接口：
- `GET /v1/tools/list`：正常
- `GET /healthz`：线上与本地代码存在差异

### 2.4 其他现有 Cloud Run 服务
当前项目里还存在：
- `api-v11`
- `poc01`
- `realestate-bot`
- `realestate-bot-v1-2`

## 3. 主要 CLI（命令行）总结

### 3.1 GCP 登录与基础配置
```bash
gcloud auth login --no-browser
gcloud config set project aesthetic-vent-480806-g6
gcloud auth list
gcloud config list project
```

### 3.2 Artifact Registry / Docker 认证
```bash
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

### 3.3 `openclaw-poc` 镜像构建
```bash
docker build -f Dockerfile.gateway -t "${IMG_URI}" .
docker push "${IMG_URI}"

docker build -f Dockerfile.runtime -t "${IMG_URI}" .
docker push "${IMG_URI}"
```

### 3.4 `qixundemo-gateway` 部署
```bash
gcloud run deploy qixundemo-gateway \
  --image "${IMG_URI}" \
  --region "asia-northeast1" \
  --platform managed \
  --project "aesthetic-vent-480806-g6" \
  --allow-unauthenticated
```

### 3.5 Cloud Run 服务测试
```bash
gcloud auth print-identity-token
```

```bash
curl -i \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "https://openclaw-poc-runtime-369629851192.asia-northeast1.run.app/message"
```

### 3.6 当前主链路验证命令
```bash
curl -i \
  -u 'USERNAME:你的密码' \
  -X POST \
  -H "Content-Type: application/json" \
  https://gateway.qixundemo.com/runtime/message \
  -d '{"chat_id":"smoke-test","message":"hello"}'
```

```bash
curl -i \
  -u 'USERNAME:你的密码' \
  https://gateway.qixundemo.com/runtime/
```

### 3.7 Secret Manager 相关命令
```bash
gcloud secrets create qixundemo-gateway-htpasswd \
  --replication-policy=automatic \
  --project aesthetic-vent-480806-g6
```

```bash
gcloud secrets versions add qixundemo-gateway-htpasswd \
  --data-file=conf.d/.htpasswd \
  --project aesthetic-vent-480806-g6
```

```bash
gcloud run services describe qixundemo-gateway \
  --region asia-northeast1 \
  --project aesthetic-vent-480806-g6 \
  --format='value(spec.template.spec.serviceAccountName)'
```

```bash
gcloud secrets add-iam-policy-binding qixundemo-gateway-htpasswd \
  --member="serviceAccount:369629851192-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project aesthetic-vent-480806-g6
```

### 3.8 Git / GitHub 相关命令
```bash
git status
git commit -m "phase1: add runtime bridge route and acceptance docs"
git push origin main
```

## 4. 主要操作总结

### 4.1 Cloud Run 部署侧
已完成：
- `openclaw-poc-gateway` / `openclaw-poc-runtime` 已部署到 Cloud Run
- 两者镜像均已推到 Artifact Registry
- `qixundemo-gateway` 已重新构建并部署新镜像，使 `/runtime/*` 路由生效

### 4.2 Edge Gateway 路由侧
已完成：
- 新增 `conf.d/routes/15-openclaw-poc-runtime.conf`
- `/runtime` -> `301 /runtime/`
- `/runtime/message` -> rewrite 到 runtime `/message`
- 新增追踪头：
  - `X-Qixun-Gateway`
  - `X-Qixun-Channel`
  - `X-Qixun-Version`

关键技术修正：
- `proxy_pass` 改为固定 Cloud Run 主机名，避免变量 upstream 带来的 502
- 加入：
  ```nginx
  proxy_set_header Authorization "";
  ```
  避免客户端 Basic Auth 头透传到 Cloud Run

### 4.3 安全配置侧
已完成：
- `qixundemo-gateway` 的 `.htpasswd` 已从镜像内置迁移到 Secret Manager 挂载
- Dockerfile 已不再包含 `.htpasswd`
- Nginx `auth_basic_user_file` 已改为：
  - `/etc/nginx/secrets/.htpasswd`
- Cloud Run 通过 Secret Manager 挂载：
  - `qixundemo-gateway-htpasswd`

当前仍需记住：
- `openclaw-poc-runtime` 当前是临时允许公开访问
- 后续应收回到私有访问

### 4.4 Git / 仓库治理侧
已完成：
- `conf.d/routes/*.conf` 已纳入 Git
- `conf.d/.htpasswd` 被 `.gitignore` 正确排除
- `.gitignore` 已从“整体忽略 `conf.d/`”改为“只排除敏感文件”
- Phase 1 验收文档已入库
- Secret / 安全文档已入库
- 所有本轮核心修改已 push 到 GitHub

### 4.5 当前可快速对齐的核心事实

服务与域名：
- `gateway.qixundemo.com` / `api.qixundemo.com` -> `qixundemo-gateway`
- `openclaw-poc-runtime` 是 `/runtime/message` 的实际处理端
- `openclaw-poc-gateway` 当前主要暴露 `/v1/...`

当前主链路：
- 外部：
  - `https://gateway.qixundemo.com/runtime/message`
- 内部：
  - `https://openclaw-poc-runtime-369629851192.asia-northeast1.run.app/message`

当前安全结构：
- Edge Gateway：Basic Auth
- `.htpasswd`：Secret Manager 挂载
- runtime：当前临时公开访问
- 后续目标：runtime 收回 private + 正式 service-to-service 认证

## 5. 一句话总括

本轮工作已经完成两项核心目标：

- Cloud Migration Phase 1 主链路打通
- `qixundemo-gateway` 的 `.htpasswd` 从镜像内置迁移到 Secret Manager 挂载

当前最重要、最值得记住的一句话是：

**`https://gateway.qixundemo.com/runtime/message` 已成功桥接到 `openclaw-poc-runtime /message`，且 `qixundemo-gateway` 的 Basic Auth 已完成 Secret Manager 化。**
