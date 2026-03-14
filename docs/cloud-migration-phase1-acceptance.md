# Cloud Migration Phase 1 完成状态文档 / 验收记录

## 1. 文档目的

本文档用于记录 Cloud Migration Phase 1 的当前完成状态、实际部署结果、联调结论、已知限制与下一步建议，供后续切换、回归验证与 Phase 2 继续推进时参考。

---

## 2. Phase 1 范围

本阶段目标聚焦于：

- 将 `openclaw-poc` 拆分并部署到 GCP Cloud Run
- 创建并验证：
  - `openclaw-poc-gateway`
  - `openclaw-poc-runtime`
- 通过现有 `qixundemo-gateway`（Edge Gateway）增加 `/runtime/*` 路由桥接
- 打通外部访问目标：
  - `https://gateway.qixundemo.com/runtime/message`

---

## 3. 当前环境与基础信息

### 3.1 GCP 基础参数

- Project ID: `aesthetic-vent-480806-g6`
- Region: `asia-northeast1`
- Artifact Registry Repo: `qixun`

### 3.2 现有 Edge Gateway 域名绑定

- `gateway.qixundemo.com -> qixundemo-gateway`
- `api.qixundemo.com -> qixundemo-gateway`

---

## 4. Cloud Run 服务状态

### 4.1 新建服务

本阶段已成功创建并运行以下 Cloud Run 服务：

#### openclaw-poc-runtime
- Region: `asia-northeast1`
- URL: `https://openclaw-poc-runtime-369629851192.asia-northeast1.run.app`

#### openclaw-poc-gateway
- Region: `asia-northeast1`
- URL: `https://openclaw-poc-gateway-369629851192.asia-northeast1.run.app`

### 4.2 镜像状态

Artifact Registry 中已成功生成并推送以下镜像：

- `asia-northeast1-docker.pkg.dev/aesthetic-vent-480806-g6/qixun/openclaw-poc-gateway:<tag>`
- `asia-northeast1-docker.pkg.dev/aesthetic-vent-480806-g6/qixun/openclaw-poc-runtime:<tag>`

---

## 5. 代码与镜像构建整理结果

### 5.1 openclaw-poc 仓库结构确认

已确认 `openclaw-poc` 为单仓多组件结构：

- `gateway/`：`openclaw-poc-gateway` 源码目录
- `runtime/`：`openclaw-poc-runtime` 源码目录
- `shared/`：共享模块

### 5.2 根 Dockerfile 状态

原根目录 `Dockerfile` 为旧版残留，不适配当前目录结构。

### 5.3 已新增并使用的 Dockerfile

为分别构建两个 Cloud Run 服务，已拆分为：

- `Dockerfile.gateway`
- `Dockerfile.runtime`

建议内容分别对应：

- `uvicorn gateway.app:app --host 0.0.0.0 --port ${PORT:-8080}`
- `uvicorn runtime.app:app --host 0.0.0.0 --port ${PORT:-8080}`

---

## 6. Cloud Run 服务验证结果

### 6.1 openclaw-poc-runtime

通过带认证的直接调用，已确认：

- `POST /message`：可用
- `GET /`：返回 `404 {"detail":"Not Found"}`，可接受
- `GET /healthz`：线上返回与本地代码不一致，当前未作为阻塞项处理

验证结论：

- `openclaw-poc-runtime` 核心入口为：
  - `POST /message`

### 6.2 openclaw-poc-gateway

通过带认证的直接调用，已确认：

- `GET /v1/tools/list`：可用
- `GET /healthz`：线上返回与本地 grep 结果不一致，当前未作为阻塞项处理

验证结论：

- `openclaw-poc-gateway` 基础业务接口已可用

---

## 7. Edge Gateway 路由桥接结果

### 7.1 新增路由文件

已新增并启用：

- `conf.d/routes/15-openclaw-poc-runtime.conf`

### 7.2 路由目标

外部目标：

- `https://gateway.qixundemo.com/runtime/message`

内部转发目标：

- `https://openclaw-poc-runtime-369629851192.asia-northeast1.run.app/message`

### 7.3 当前生效配置要点

已确认 Nginx 路由具备以下能力：

- `/runtime` -> `301 /runtime/`
- `/runtime/message` -> rewrite 到 `/message`
- 代理到 `openclaw-poc-runtime` Cloud Run

关键头部：

- `X-Qixun-Gateway: nginx-gateway`
- `X-Qixun-Channel: openclaw-runtime`
- `X-Qixun-Version: phase1`

### 7.4 当前有效配置中的重要修正

在联调过程中，已确认需要：

1. **不要使用变量形式的 upstream**
   - 原因：`proxy_pass https://$upstream` 可能引发解析与 502 问题
   - 处理：改为固定 `proxy_pass https://openclaw-poc-runtime-369629851192.asia-northeast1.run.app;`

2. **不要把客户端 Basic Auth 的 Authorization 头透传到 Cloud Run**
   - 已加入：
     - `proxy_set_header Authorization "";`

---

## 8. Basic Auth / Secret 当前状态

### 8.1 qixundemo-gateway 当前保护方式

当前 `qixundemo-gateway` 仍通过 Nginx Basic Auth 保护。

相关配置：

- `conf.d/default.conf`
  - `auth_basic "Restricted";`
  - `auth_basic_user_file /etc/nginx/.htpasswd;`

### 8.2 当前 .htpasswd 状态

当前 `.htpasswd` 仍然是通过 Dockerfile bake 进镜像：

- `COPY conf.d/.htpasswd /etc/nginx/.htpasswd`

这是当前联调用临时方案，**不是最终推荐方案**。

### 8.3 Secret Manager 状态

已确认后续目标：

- `GEMINI_API_KEY`、`TOKEN_KEY`、`ADMIN_PASSWORD` 等单值 secret
  - 通过 Cloud Run “变量和密钥”注入
- `.htpasswd`
  - 后续迁移到 Secret Manager，作为文件挂载注入

当前阶段：
- `GEMINI_API_KEY` 已配置到 Cloud Run
- `.htpasswd` 仍未迁移到 Secret Manager

---

## 9. 当前最终联调结果

### 9.1 访问 `/runtime/`

请求：

- `GET https://gateway.qixundemo.com/runtime/`

结果：

- 返回 `404 {"detail":"Not Found"}`

解释：

- 请求已成功进入 `openclaw-poc-runtime`
- runtime 根路径未定义，因此 404 为合理现象

### 9.2 访问 `/runtime/message`

请求：

- `POST https://gateway.qixundemo.com/runtime/message`

结果：

- `200 OK`
- 返回 JSON：
  - `reply: unknown command...`
  - `active_agent: realestate`

解释：

- Basic Auth 已通过
- Edge Gateway 新路由已生效
- rewrite 已生效：`/runtime/message -> /message`
- 请求已成功到达 `openclaw-poc-runtime`
- runtime 已完成业务处理并返回结果

---

## 10. Phase 1 验收结论

### 10.1 验收结论

**Cloud Migration Phase 1 主链路已打通，验收通过。**

### 10.2 已完成项

- `openclaw-poc-gateway` 创建完成并运行
- `openclaw-poc-runtime` 创建完成并运行
- Artifact Registry 镜像构建、推送完成
- `qixundemo-gateway` 新 runtime 路由部署完成
- `https://gateway.qixundemo.com/runtime/message`
  已成功桥接到
  `openclaw-poc-runtime /message`

### 10.3 当前可对外确认的结果

以下目标已验证成功：

- `https://gateway.qixundemo.com/runtime/message`

---

## 11. 当前限制与技术债

### 11.1 runtime 当前为“临时允许公开访问”

为快速打通 Phase 1 链路，`openclaw-poc-runtime` 当前已临时改为允许公开访问。

这属于联调阶段的临时措施，不建议作为长期生产状态保留。

### 11.2 qixundemo-gateway 仍使用镜像内置 .htpasswd

当前 `.htpasswd` 仍 bake 在镜像内，存在以下问题：

- 凭据管理不够灵活
- 轮换成本高
- 不符合后续 Secret Manager 统一管理目标

### 11.3 healthz 路由与本地代码存在偏差

线上 `openclaw-poc-runtime` 与 `openclaw-poc-gateway` 的 `/healthz` 行为与本地 grep 结果不一致，建议后续单独收敛。

---

## 12. 下一步建议

### 12.1 优先级 P1
- 将 `.htpasswd` 从镜像内置迁移到 Secret Manager 文件挂载
- 统一整理 gateway/runtime 的 Cloud Run Secret 注入方式
- 将当前 Phase 1 成功链路补充到项目文档与回滚文档中

### 12.2 优先级 P2
- 评估 `openclaw-poc-runtime` 从“临时公开访问”回收为私有访问
- 设计正式的 service-to-service 认证方案
- 避免普通 Nginx 直接访问私有 Cloud Run 时缺失 Google ID token

### 12.3 优先级 P3
- 统一修复 `/healthz` 线上行为与本地代码不一致问题
- 补充更完整的 smoke test / acceptance test 文档

---

## 13. 建议落库位置

建议存放到：

- `docs/cloud-migration-phase1-acceptance.md`

---

## 14. 一句话总结

**`https://gateway.qixundemo.com/runtime/message` 已成功桥接到 `openclaw-poc-runtime /message`，Cloud Migration Phase 1 主链路已验证通过。**
