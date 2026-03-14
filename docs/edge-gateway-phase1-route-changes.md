# Edge Gateway Phase 1 Route Changes

## 1. Purpose

This document defines the minimal Edge Gateway route changes required for Cloud Migration Phase 1.

Phase 1 goal:

- keep local QQ ingress unchanged
- move backend services to cloud
- use Edge Gateway as the cloud ingress layer
- preserve existing business/API-facing routes
- preserve the `/poc...` contract

---

## 2. Current Known Domain Roles

### `gateway.qixundemo.com`
Role:
- Edge Gateway main ingress
- future bridge-facing cloud entry

### `api.qixundemo.com`
Role:
- business/API-facing domain
- continues serving business/demo paths such as `/realestate`

Both domains currently map to:

- `qixundemo-gateway`
- region: `asia-northeast1`

---

## 3. Phase 1 Route Goal

Add a Runtime-facing route for the bridge path:

```text
https://gateway.qixundemo.com/runtime/message

This route should forward to:

https://openclaw-poc-runtime-<hash>-asia-northeast1.run.app/message

At the same time:

existing business-facing routes on api.qixundemo.com must remain intact

existing stable/legacy/beta route behavior must not be broken

4. Required Route Change Summary
4.1 Add bridge-facing Runtime route

Add a new route that handles:

host: gateway.qixundemo.com

path prefix: /runtime/

Expected forwarding rule:

/runtime/message → upstream Runtime /message

/runtime/healthz → upstream Runtime /healthz (optional but recommended)

4.2 Preserve business/API-facing route behavior

Keep existing api.qixundemo.com product/demo routes unchanged, including patterns such as:

https://api.qixundemo.com/realestate

These should continue routing to business-facing upstreams, not to the new Runtime route by default.

4.3 Do not proxy Runtime → Gateway through Edge

Runtime internal calls to Gateway must continue using direct backend URL via GATEWAY_URL.

Do not introduce:

gateway.qixundemo.com/gateway/...

Runtime → Edge → Gateway internal chaining

in Phase 1.

5. Recommended Nginx Route Intent
5.1 New runtime route file

Suggested new route file name:

conf.d/routes/15-openclaw-poc-runtime.conf

Reason:

ordered after health

before business/demo routes

explicit purpose

5.2 Route matching intent

Recommended matching logic:

if host is gateway.qixundemo.com

and path starts with /runtime/

proxy to cloud Runtime upstream

Path rewrite intent

Option A:

/runtime/message → upstream /message

Option B:

/runtime/... preserved on backend

Recommendation

Use rewrite so Runtime backend still sees its existing native paths:

/runtime/message → /message

/runtime/healthz → /healthz

This minimizes backend changes.

6. Upstream Planning

The route should target:

https://openclaw-poc-runtime-<hash>-asia-northeast1.run.app

Use the actual deployed Runtime URL after deployment.

Suggested config placeholder:

OPENCLAW_POC_RUNTIME_UPSTREAM

If the gateway repo uses direct literal upstreams instead of env templating, replace with the actual Runtime Cloud Run URL when implementing.

7. Existing Files Likely Affected

The exact final changes depend on current Nginx layout, but Phase 1 should stay minimal.

Likely touched files:

conf.d/routes/15-openclaw-poc-runtime.conf (new)

possibly conf.d/default.conf if shared proxy defaults are required

possibly no change to nginx.conf if current include structure already works

Files that should ideally remain unchanged unless necessary:

legacy business route files

existing realestate business route files

canary/stable route files unrelated to Runtime bridge ingress

8. Validation Requirements After Route Change

After adding the Runtime route, verify:

Edge ingress checks

https://gateway.qixundemo.com/runtime/healthz

https://gateway.qixundemo.com/runtime/message

Backend checks

Runtime receives /message correctly

Runtime still calls Gateway via direct internal GATEWAY_URL

no accidental business route collision

Contract checks

local qq_bridge.py can later point to:

https://gateway.qixundemo.com/runtime

/poc... behavior remains unchanged after bridge retarget

9. Non-Goals

Phase 1 route changes should not:

redesign business/demo routing

change stable/beta/legacy strategy globally

move product URLs to a new domain

expose Gateway internal APIs publicly

add control-plane semantics to the Edge Gateway

modify QQ ingress behavior

10. Rollback Plan

If the new Runtime route causes issues:

disable or revert the new Runtime route file

redeploy Edge Gateway

keep business/API-facing routes untouched

keep local backend available

keep bridge target on local backend until cloud route is proven stable

Fast rollback priority:

rollback edge route first

do not combine with backend rollback unless necessary

11. Immediate Next Route Work

Before implementation:

confirm actual Runtime Cloud Run URL

decide exact rewrite rule for /runtime/*

identify whether current route files already use host-based separation

add the new Runtime route as an isolated file

validate with health and message path checks before bridge retarget
```
