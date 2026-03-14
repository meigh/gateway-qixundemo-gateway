# Cloud Run Implementation Checklist

## 1. Purpose

This checklist is for the actual implementation of Cloud Migration Phase 1.

It is intended to be used immediately before and during deployment.

---

## 2. Pre-Deployment Checklist

### Architecture
- [ ] `cloud-edge-architecture.md` reviewed
- [ ] `cloud-phase1-implementation-plan.md` reviewed
- [ ] `cloud-run-deployment-matrix.md` reviewed

### Service naming
- [ ] `qixundemo-gateway` confirmed as Edge Gateway
- [ ] `openclaw-poc-runtime` confirmed
- [ ] `openclaw-poc-gateway` confirmed

### URL plan
- [ ] `gateway.qixundemo.com` confirmed as bridge-facing edge ingress
- [ ] `api.qixundemo.com` confirmed as business/API-facing domain
- [ ] future bridge target confirmed as `https://gateway.qixundemo.com/runtime/message`

### Environment and secrets
- [ ] `GEMINI_API_KEY` available in Secret Manager
- [ ] `GEMINI_MODEL` decided
- [ ] `GATEWAY_URL` value planned for Runtime
- [ ] local fallback path kept available

---

## 3. Gateway Deployment Checklist

- [ ] build gateway image
- [ ] push gateway image
- [ ] deploy `openclaw-poc-gateway`
- [ ] capture deployed Gateway URL
- [ ] verify `/healthz`
- [ ] verify `/v1/agents/list`
- [ ] verify `/v1/tools/list?agent_id=realestate`
- [ ] verify `/v1/tools/execute`

Gateway must be healthy before Runtime deploy proceeds.

---

## 4. Runtime Deployment Checklist

- [ ] build runtime image
- [ ] push runtime image
- [ ] deploy `openclaw-poc-runtime`
- [ ] set `GATEWAY_URL` to cloud Gateway URL
- [ ] capture deployed Runtime URL
- [ ] verify `/healthz`
- [ ] verify `/message`
- [ ] verify `/agents`
- [ ] verify `/whoami`
- [ ] verify `/tools`
- [ ] verify `/recommend-text`

Runtime must be healthy before Edge Gateway route change proceeds.

---

## 5. Edge Gateway Route Checklist

- [ ] `15-openclaw-poc-runtime.conf` created
- [ ] runtime upstream host replaced with actual Cloud Run Runtime host
- [ ] route for `/runtime/*` reviewed
- [ ] rewrite behavior reviewed
- [ ] `nginx -t` passes
- [ ] gateway image rebuilt/redeployed if required
- [ ] `https://gateway.qixundemo.com/runtime/healthz` verified
- [ ] `https://gateway.qixundemo.com/runtime/message` verified

---

## 6. Bridge Retarget Checklist

Do not do this before the previous sections pass.

- [ ] local `qq_bridge.py` target prepared
- [ ] `RUNTIME_BASE_URL=https://gateway.qixundemo.com/runtime`
- [ ] bridge target changed from local Runtime to cloud edge ingress
- [ ] local fallback target still available
- [ ] no QQ command semantics changed

---

## 7. Validation Checklist

### Main smoke
- [ ] `acceptance/smoke/run_all.sh` passes

### QQ bridge smoke
- [ ] `acceptance/qq/run_bridge_smoke.sh` passes

### Manual QQ checks
- [ ] `/pocdiag`
- [ ] `/pocagents`
- [ ] `/poctools`
- [ ] `/pocwhoami`
- [ ] `/pocagent realestate`
- [ ] `/pocagent not-exist`
- [ ] `/poc <natural language>`

### Contract checks
- [ ] allowlist enforcement still works
- [ ] schema validation still works
- [ ] multilingual behavior still works
- [ ] `/poc...` namespace remains unchanged

---

## 8. Rollback Readiness Checklist

Before declaring success:

- [ ] local backend path still available
- [ ] bridge target can be switched back quickly
- [ ] previous Edge Gateway config is retained
- [ ] previous backend image tags are known
- [ ] rollback owner/operator is clear

---

## 9. Success Criteria

Phase 1 implementation is successful only if:

- [ ] cloud Gateway is deployed and verified
- [ ] cloud Runtime is deployed and verified
- [ ] Edge Gateway routes correctly to cloud Runtime
- [ ] local bridge target successfully uses cloud ingress
- [ ] smoke tests pass
- [ ] QQ bridge smoke tests pass
- [ ] live QQ `/poc...` behavior is still correct

---
