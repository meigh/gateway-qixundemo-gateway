# gateway-qixundemo-gateway

An **Edge Gateway** template for AI assistant services, built with **Nginx** and designed for **Cloud Run / upstream routing**, **version switching**, and **rollback-friendly ingress management**.

This repository is **not** the assistant control plane itself.  
It is the **outer ingress layer** that sits in front of backend services such as `openclaw-poc`.

---

## 1. Role and Scope

This repository is positioned as an **Edge Gateway**.

It is responsible for:

- public ingress routing
- stable / beta / legacy version switching
- Cloud Run / upstream routing
- authentication and access control
- rollback-friendly release management
- basic access logging and request tracing
- path-based routing for web and API traffic

It is **not** intended to become:

- an agent control plane
- a session system
- a tool orchestration layer
- a business workflow engine
- an OpenClaw Gateway replacement

In the broader architecture:

- **Edge Gateway** handles ingress, routing, auth, rollout, and rollback
- **OpenClaw / openclaw-poc Gateway + Runtime** handle sessions, command routing, tool governance, and business orchestration
- **Executors / data / model services** handle actual business execution

---

## 2. Relationship to openclaw-poc

This repository should be used together with `openclaw-poc`, not as a replacement for it.

### Recommended layering

```text
User / QQ / Web / Mobile / Third-party
                |
                v
+--------------------------------------+
| Edge Gateway                         |
|--------------------------------------|
| auth / routing / stable / beta       |
| rollback / request-id / access logs  |
+--------------------------------------+
                |
                v
+--------------------------------------+
| OpenClaw Gateway + Runtime           |
|--------------------------------------|
| sessions / commands / tools / agent  |
| routing / orchestration / control    |
+--------------------------------------+
                |
                v
+--------------------------------------+
| Executors / Data / Models            |
+--------------------------------------+

Design principle

This repository owns the outer ingress layer.

openclaw-poc owns the control plane and business logic.

For the broader cloud architecture direction, see:

openclaw-poc/docs/cloud-edge-architecture.md

3. Current Repository Contents
.
├── Dockerfile
├── VERSIONING.md
├── conf.d
│   ├── default.conf
│   └── routes
│       ├── 05-realestate-bot-beta.conf
│       ├── 10-health.conf
│       ├── 20-realestate-web.conf
│       ├── 25-realestate-bot-v1_0-legacy.conf
│       ├── 30-realestate-bot-stable.conf
│       ├── 40-realestate-bot-v1_1.conf
│       ├── 45-realestate-bot-v1_2.conf
│       ├── 55-realestate-bot-canary.conf
│       ├── 90-openapi-fallback.conf
│       └── 99-catchall-404.conf
└── nginx.conf
Meaning of the main files

Dockerfile
Builds the Nginx-based Edge Gateway image.

nginx.conf
Main Nginx configuration entry.

conf.d/default.conf
Shared/default gateway behavior.

conf.d/routes/*.conf
Route-specific configuration files, including:

health route

web route

stable bot route

legacy version route

explicit version routes

beta/canary route

fallback route

catch-all 404

VERSIONING.md
Explains the versioning and routing policy for Stable / Legacy / Beta / Canary.

4. What This Gateway Is Good At

This repository is a strong fit for:

exposing a stable public entrypoint

routing different product versions by path or route

maintaining a permanent legacy path

switching the stable alias during rollout

introducing beta/canary exposure without changing backend internals

adding a simple auth boundary in front of cloud services

centralizing rollback-friendly ingress logic

Typical use cases:

demo environments

customer-facing stable entrypoints

path-based version governance

lightweight edge ingress in front of assistant backends

controlled migration from local-first backend to cloud backend

5. What This Gateway Should Not Do

This repository should not expand into:

assistant session state

active agent tracking

command parsing

tool allowlist logic

business recommendation logic

LLM prompt generation

executor dispatch

OpenClaw control-plane semantics

Those responsibilities belong in backend services such as openclaw-poc.

Rule of thumb

Edge Gateway decides how traffic enters

OpenClaw / backend services decide how requests are processed

6. Versioning Strategy

This repository is designed around explicit path/version governance.

Typical version roles are:

Legacy
Permanently preserved version for compatibility and historical stability

Stable
Main public entrypoint currently recommended for normal use

Versioned routes
Explicit fixed versions such as v1_1, v1_2

Beta / Canary
Controlled testing or preview traffic

This makes it possible to:

preserve old working versions

switch the stable route safely

test new versions without replacing the stable path

roll back by repointing a stable route instead of rebuilding all clients

See:

VERSIONING.md

7. Recommended Future Positioning

The recommended future positioning is:

Edge Gateway template for AI assistant services

That means this repository should evolve mainly in these directions:

better ingress route templates

better version/alias governance

clearer rollout and rollback policy

access logging / request ID support

basic auth / allowlist / edge policy

upstream health checks

deployment-friendly Cloud Run routing patterns

It should not evolve toward a full assistant runtime or agent orchestration platform.

8. Suggested Future Enhancements

These are reasonable future enhancements for this repository:

Good future enhancements

add request ID forwarding headers

improve access log format

add upstream response timing

add environment-specific route templates

add clearer health and readiness routes

add rollback playbooks

document Cloud Run deployment patterns

document Stable / Beta / Legacy governance more explicitly

Enhancements to avoid here

session persistence

agent workflow orchestration

tool governance logic

business-specific dispatch

LLM logic

internal control-plane code

9. How It Fits the Cloud Migration Path

This repository becomes especially useful once backend services move to the cloud.

Conservative migration path

Phase 1:

keep QQ ingress local

keep local gateway.ts + qq_bridge.py

move backend Runtime / Gateway to cloud

place this Edge Gateway in front of the cloud backend

Result:

QQ private chat
→ local qqbot plugin
→ local gateway.ts
→ local tools/qq_bridge.py
→ Edge Gateway
→ cloud Runtime / Gateway
→ backend executors / models / data
→ QQ reply

This allows:

preserving the current QQ contract

introducing cloud backend safely

using stable / beta / legacy ingress routes

minimizing migration risk

10. Local Development Notes

This repository is Nginx-based.

Typical work in this repo consists of:

editing Nginx route configuration

adjusting version mappings

changing upstream targets

refining default gateway behavior

rebuilding or redeploying the container image

This repository is configuration-driven, not application-runtime-driven.

11. Deployment Notes

This repository is intended to be containerized and deployed as an ingress layer.

Typical deployment target:

Cloud Run

container-based edge ingress environment

reverse-proxy style service entrypoint

The exact deployment commands and environment-specific rollout mechanics can remain outside this README if they differ across environments.

12. Current Recommendation

Use this repository as:

the Edge Gateway layer

the version-routing and ingress policy layer

the rollback-friendly public entry layer

Do not use it as:

the OpenClaw control plane

the assistant runtime

the business execution layer

For cloud architecture decisions involving openclaw-poc, the source of truth should remain the architecture docs in the backend repository.

13. Related Documents

VERSIONING.md

openclaw-poc/docs/cloud-edge-architecture.md

