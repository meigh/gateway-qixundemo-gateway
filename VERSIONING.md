# Qixun Realestate-Bot Versioning & Release Strategy

本文档定义 Realestate-Bot 网关的版本发布、冻结、稳定映射规则，确保上线升级时不影响历史版本和用户体验。

---

## 1. Version Types（版本类型）

系统区分三种版本类型：

| 类型 | 路径示例 | 说明 |
|---|---|---|
| **Legacy（冻结版）** | `/realestate-bot/v1.0-legacy/` | 永久冻结，不再改动 |
| **Stable（当前对外稳定版）** | `/realestate-bot/` | 稳定对外 API（随业务升级） |
| **Next / Beta（预发布版，可选）** | `/realestate-bot/beta/` | 可用于试验或灰度（可关闭） |

---

## 2. UI + API 绑定原则

每个版本包含两套资源：

✔ UI (HTML/JS/CSS 等前端)  
✔ API (REST JSON)

绑定关系如下：

| 版本 | UI | API |
|---|---|---|
| `v1.0-legacy` | 旧 UI | 旧 API |
| `v1.2 stable` | 新 UI | 新 API |

Legacy 永远绑定它诞生当下的 API，不随 Stable 变化。

---

## 3. 路由策略（网关层）

### 3.1 Legacy 冻结策略

特点：

- 不允许改动原始服务路径
- 不随 Cloud Run 修改
- UI + API 一起冻结

示例路径：

/realestate-bot/v1.0-legacy/

网关配置原则：

rewrite /realestate-bot/v1.0-legacy/(.*) → /$1
proxy_pass → legacy Cloud Run host
proxy_set_header Host → legacy Cloud Run host


因此：

- **不使用** `$upstream`
- Cloud Run 必须看到原始 Host
- 不得指向 stable/next

---

### 3.2 Stable 映射策略

Stable 为正在对外的 API/UI，例如：

/realestate-bot/

Stable 会随业务升级进行版本切换：

| 时间点 | stable 指向 |
|---|---|
| 2024Q4 | v1.0 |
| 2025Q1 | v1.2 |
| 未来 | v1.3 / v1.4 / ... |

映射规则：

/realestate-bot/ → 当前 Stable Cloud Run 版本

即 Stable 是一个 **alias**。

---

### 3.3 Beta / Next（可选）

如果存在：

/realestate-bot/beta/

可做功能预览或 A/B Test  
上线 stable 后可关闭或删除。

---

## 4. 发布流程（不影响 Legacy 的前提下）

### **永不破坏 Legacy 的发布流程**

稳定升级步骤：

**Step 1: 冻结当前版本为 Legacy（仅第一次创建）**
/realestate-bot/v1.0-legacy/ → 绑定旧 Cloud Run

**Step 2: 部署新 Cloud Run（例如 v1.2）**

**Step 3: 将 Stable 映射切换到新 Cloud Run**

/realestate-bot/ → v1.2

**Step 4: 可选关闭 Beta**

/realestate-bot/beta → 410 或 remove

全过程中：

❗ **Legacy 永不修改**  
❗ **Stable 改映射，不改 Legacy**

---

## 5. Freeze 规则（冻结原则）

Legacy 必须满足以下条件：

UI 不变
✓ API 不变
✓ Cloud Run host 不变
✓ proxy_set_header Host 指向 legacy host
✓ rewrite 去掉 version 前缀后仍匹配 legacy API


禁止行为：

✗ Stable 反向代理到 Legacy
✗ Legacy 指向 Stable
✗ Legacy 指向 Latest
✗ 修改 legacy Cloud Run


---

## 6. Cloud Run 映射规范

Legacy 使用固定 Host：

realestate-bot-xxxxxxxx.asia-northeast1.run.app


Stable 使用版本化 Host：



realestate-bot-v1-2-xxxxxxxx.asia-northeast1.run.app


未来版本示例：



realestate-bot-v1-3-xxxxxxxx.asia-northeast1.run.app
realestate-bot-v1-4-xxxxxxxx.asia-northeast1.run.app


---

## 7. 网关测试检查表（QA Checklist）

发布前必须检查：

### ✔ Legacy 检查



curl -I https://api.qixundemo.com/realestate-bot/v1.0-legacy/

curl -u admin:pwd https://api.qixundemo.com/realestate-bot/v1.0-legacy/


验证：

☑ HTTP 200/401（取决于是否需要认证）  
☑ UI 能展示  
☑ API 正常返回  
☑ X-Qixun-Legacy header 存在  
☑ Host header 为 legacy Cloud Run host  

### ✔ Stable 检查



curl -I https://api.qixundemo.com/realestate-bot/health


验证：

☑ 返回 `"version": "v1.2"`  
☑ 200 OK

---

## 8. 未来升级方法（v1.3 示例）

当 v1.3 准备上线：



Deploy Cloud Run (v1.3)
Switch /realestate-bot/ → v1.3


无需 Touch：



/realestate-bot/v1.0-legacy/


因此 Legacy 不会受到任何影响。

---

## 9. 回滚策略

Stable 支持快速回滚：



/realestate-bot/ → v1.2


Legacy 永远无需回滚。

---

## 10. Why Legacy Exists?

Legacy 的存在保障：

- 产品 Demo 可回溯
- UI 不被破坏
- API 不随业务变化
- 客户可以同时看多个版本

---

## 11. 版本命名规范（推荐）

| 类型 | 示例 |
|---|---|
| Legacy | `v1.0-legacy` |
| Stable | `v1.2` |
| Next | `v1.3-beta` |

---

## End

此策略已验证支持：

✔ UI 冻结  
✔ API 冻结  
✔ Cloud Run 多版本  
✔ 多年向后兼容  
✔ 快速 stable 升级  
✔ 无需影响 legacy