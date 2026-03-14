# Versioning Strategy

## 1. Purpose

This document defines the versioning strategy for `gateway-qixundemo-gateway` as an **Edge Gateway**.

It explains how this gateway should handle:

- stable routes
- legacy routes
- fixed version routes
- beta / canary routes
- future cloud migration routing

This repository is the **edge ingress layer**, not the assistant control plane.

---

## 2. Core Principles

### 2.1 Stable is the main public route
Stable is the default entrypoint for normal users and integrations.

Stable may move from one backend version to another over time.

### 2.2 Legacy should remain fixed
Legacy should not be reused as a moving alias.

Legacy exists to preserve compatibility and provide a known old path that continues to work.

### 2.3 Versioned routes are explicit
Versioned routes such as `v1_1` or `v1_2` should map to one specific backend version.

These are useful for:

- explicit testing
- controlled client pinning
- rollback comparison
- release validation

### 2.4 Beta / Canary are limited exposure routes
Beta / canary routes should be used for preview or controlled exposure.

They should not silently replace stable.

### 2.5 Edge Gateway owns ingress versioning, not business logic
The gateway decides **which upstream receives traffic**.

It does not decide application behavior, session logic, tool orchestration, or assistant semantics.

---

## 3. Route Categories

## 3.1 Stable

Use stable for:

- default public entry
- the currently approved version
- normal production/demo traffic

Stable should be easy to switch during rollout.

Example:
- `/realestate-bot/` → currently mapped to `v1.2`

## 3.2 Legacy

Use legacy for:

- compatibility preservation
- old documentation references
- fallback access to a known older route

Legacy should stay fixed once published.

Example:
- `/realestate-bot-v1_0-legacy/`

## 3.3 Explicit Version Routes

Use explicit version routes for:

- validating a specific backend version
- testing upgrades without changing stable
- comparing old and new behavior

Examples:
- `/realestate-bot-v1_1/`
- `/realestate-bot-v1_2/`

## 3.4 Beta / Canary

Use beta / canary for:

- internal preview
- limited external validation
- release candidate exposure

Examples:
- `/realestate-bot-beta/`
- `/realestate-bot-canary/`

---

## 4. Domain Role Alignment

The versioning strategy must respect current domain roles.

### 4.1 `gateway.qixundemo.com`
This is the **Edge Gateway ingress domain**.

It should be used for:

- bridge-facing runtime ingress
- gateway-level routing
- future `/runtime/*` entry
- stable cloud migration ingress

### 4.2 `api.qixundemo.com`
This is the **business/API-facing domain**.

It should be used for:

- business/demo-facing URLs
- product-facing routes such as `/realestate`

The same gateway service may receive both domains, but the route semantics should remain distinct.

---

## 5. Versioning Rules for Business Routes

For business/demo-facing routes:

- stable may move
- legacy stays fixed
- explicit version routes stay fixed
- beta/canary may move or be removed

Recommended route order:

1. health
2. runtime bridge ingress
3. business web/API routes
4. legacy routes
5. stable route
6. explicit version routes
7. beta/canary routes
8. fallback
9. catch-all

If the actual route order differs for operational reasons, the intent should still remain clear.

---

## 6. Versioning Rules for Cloud Migration Phase 1

During Cloud Migration Phase 1:

- existing business/demo route strategy remains intact
- a new runtime ingress route is added
- the Edge Gateway gains a new responsibility:
  - route `/runtime/*` for local `qq_bridge.py` cutover

This does **not** change the meaning of stable/legacy/business version routes.

It adds a **bridge-facing backend ingress path**, not a new business version policy.

---

## 7. Stable Promotion Policy

Before changing stable:

1. validate the target version directly
2. validate business route behavior
3. validate health route
4. validate any dependent docs/demo paths
5. confirm rollback target exists

Only then repoint stable.

---

## 8. Rollback Policy

Preferred rollback strategy:

- rollback by repointing stable to the last known-good upstream
- preserve explicit version routes for diagnostics
- keep legacy fixed
- avoid changing multiple version categories at once

For runtime bridge ingress rollback during Phase 1:

- edge route can be reverted independently
- local `qq_bridge.py` can be pointed back to local Runtime
- backend rollback should be separate from edge rollback when possible

---

## 9. Naming Guidance

Use route names that make intent obvious.

Good examples:

- `stable`
- `legacy`
- `v1_1`
- `v1_2`
- `beta`
- `canary`
- `runtime`

Avoid ambiguous names that hide whether a route is fixed, moving, or experimental.

---

## 10. Current Recommendation

Use this versioning model:

- **Stable** = moving default entry
- **Legacy** = fixed compatibility entry
- **Versioned routes** = fixed explicit entries
- **Beta/Canary** = limited preview entries
- **Runtime ingress** = bridge/backend entry, separate from business route versioning

This keeps the edge gateway simple, diagnosable, and rollback-friendly.

---
