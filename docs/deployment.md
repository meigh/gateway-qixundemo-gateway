# Deployment Guide

## 1. Purpose

This document describes how to deploy `gateway-qixundemo-gateway` as an **Edge Gateway** for AI assistant services.

It focuses on:

- image build
- container deployment
- route configuration deployment
- rollout / rollback basics
- operational checks after deployment

This document does **not** cover:

- application business logic deployment
- OpenClaw control-plane deployment
- backend Runtime / Gateway internals
- session or tool orchestration

---

## 2. Deployment Role

This repository is deployed as the **outer ingress layer**.

It is responsible for:

- public ingress routing
- stable / beta / legacy version entrypoints
- upstream routing
- auth / access boundary
- rollback-friendly traffic switching

It is **not** the assistant control plane.

Backend services such as `openclaw-poc` should be deployed separately and sit behind this Edge Gateway.

---

## 3. Repository Structure Relevant to Deployment

```text
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

Deployment-critical files

Dockerfile

nginx.conf

conf.d/default.conf

conf.d/routes/*.conf

Any deployment should treat these files as the source of truth for gateway behavior.

4. Deployment Model

The recommended model is:

Build the Nginx image from this repository

Push the image to a container registry

Deploy the image to a container hosting target such as Cloud Run

Point public traffic to this gateway

Let this gateway route traffic to backend services

Typical flow:

User / Client
   |
   v
Edge Gateway (this repo)
   |
   v
Cloud backend services
   |
   v
Application response
5. Prerequisites

Before deployment, make sure you have:

a working container build environment

access to a container registry

access to the deployment platform

known upstream backend URLs / hosts

a clear version-routing plan

a rollback plan

Recommended prerequisites checklist

route config reviewed

stable/beta/legacy target mapping confirmed

upstream service health verified

auth policy confirmed

image tag decided

release note written

6. Build the Image

From the repository root:

docker build -t gateway-qixundemo-gateway:local .
Optional tagged build
docker build -t gateway-qixundemo-gateway:2026-03-14 .
What this does

The image packages:

nginx.conf

conf.d/

route configuration

into an Nginx-based gateway container.

7. Local Container Smoke Check

Before pushing to cloud, it is recommended to run the image locally:

docker run --rm -p 8080:8080 gateway-qixundemo-gateway:local

Then test basic routes:

curl -i http://127.0.0.1:8080/
curl -i http://127.0.0.1:8080/health
What to verify locally

Nginx starts successfully

syntax/config is valid

expected routes are loaded

fallback behavior works

health route responds

catch-all behavior is as expected

8. Optional Config Validation Before Deployment

It is strongly recommended to validate Nginx config before shipping:

docker run --rm gateway-qixundemo-gateway:local nginx -t

If you want to validate using the official Nginx image and the current repo contents:

docker run --rm \
  -v "$(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$(pwd)/conf.d:/etc/nginx/conf.d:ro" \
  nginx:1.29-alpine nginx -t

Deployment should not proceed if config validation fails.

9. Image Push

Example generic flow:

docker tag gateway-qixundemo-gateway:2026-03-14 <registry>/<project>/gateway-qixundemo-gateway:2026-03-14
docker push <registry>/<project>/gateway-qixundemo-gateway:2026-03-14

Replace:

<registry>

<project>

with your actual registry target.

Use immutable image tags for release builds whenever possible.

10. Cloud Deployment

This repository is suitable for container-based ingress deployment, including Cloud Run.

Generic deployment flow

Deploy the container image

set the exposed container port expected by the platform

configure domain / ingress

confirm upstream target availability

verify health route

verify stable route

verify legacy / beta route behavior

Important note

This gateway should be deployed in front of backend services.
It should not contain business logic itself.

11. Route Configuration Strategy

Route files under conf.d/routes/ should be treated as deployment-governing assets.

Recommended route priorities

health route first

explicit version routes before generic fallback

stable route clearly separated

legacy route explicitly preserved

canary/beta route isolated

catch-all route last

Recommended naming pattern

The current numeric prefix ordering is good practice:

05-...

10-...

20-...

...

99-...

Keep this pattern because it makes route load order and intent easier to review.

12. Stable / Beta / Legacy Deployment Policy

Use explicit policies for traffic exposure.

Stable

The public default entrypoint.

Use this for:

normal users

standard integrations

the currently approved release

Beta / Canary

Limited exposure.

Use this for:

internal testing

preview environments

controlled validation before stable promotion

Legacy

Preserved compatibility route.

Use this for:

historical versions

compatibility support

cases where an older stable path must remain intact

Operational rule

Do not repurpose legacy as a moving alias.
Legacy should remain fixed.

Stable may move.
Beta/canary may move.
Legacy should remain stable.

See also:

VERSIONING.md

13. Recommended Release Procedure
Step 1 — review route intent

Before release, confirm:

what stable points to

what beta points to

what legacy points to

whether any fixed version routes changed

Step 2 — validate config

Run:

nginx -t

or the containerized equivalent.

Step 3 — build tagged image

Use an immutable tag for traceability.

Step 4 — deploy to target environment

Deploy the container without changing multiple unrelated things at once.

Step 5 — verify health and key routes

At minimum verify:

health route

stable route

one fixed version route

catch-all behavior

Step 6 — monitor ingress behavior

Watch:

error rate

routing behavior

auth behavior

unexpected upstream failures

14. Recommended Rollback Procedure

Rollback should be simple and route-focused.

Preferred rollback strategy

Rollback by restoring the previous known-good image and/or previous known-good route mapping.

Minimum rollback playbook

identify last known-good image tag

restore last known-good route config

redeploy gateway

verify health route

verify stable route

confirm public behavior recovered

Important principle

Rollback should happen at the edge routing layer, not by emergency rewriting backend logic.

This repository should make rollback easier, not harder.

15. Post-Deployment Verification Checklist

After deployment, verify the following:

Health

health route responds correctly

service is reachable externally if intended

Routing

stable route goes to the intended backend

beta/canary route goes to the intended backend

legacy route still works if expected

fallback route behavior is correct

unknown routes return expected 404 behavior

Security / Access

auth policy works as expected

unauthorized access is denied where intended

no unintended public exposure exists

Observability

access logs are visible

request tracing is sufficient for debugging

upstream failures are diagnosable

16. Operational Notes
Keep this repository narrow in purpose

Avoid mixing deployment responsibilities with application business logic.

Prefer explicit route files

Do not hide important behavior in too many implicit defaults.

Keep stable/beta/legacy intent obvious

A future operator should be able to understand the traffic policy quickly from filenames and config.

Use release notes

Every deployment should have:

image tag

route intent

stable target

rollback target

17. Future Improvements

These are good future enhancements for this gateway:

request ID injection / forwarding

upstream timing in access logs

clearer health/readiness route semantics

environment-specific config overlays

documented rollout and rollback scripts

deployment examples for Cloud Run

stronger auth/access patterns if needed

These should still remain edge-layer concerns, not control-plane concerns.

18. Non-Goals for This Deployment Guide

This document does not define:

OpenClaw backend deployment internals

session persistence deployment

database topology

tool executor scaling

LLM service deployment

full production SRE procedures

Those should be documented in backend repositories or higher-level architecture docs.

19. Related Documents

README.md

VERSIONING.md

openclaw-poc/docs/cloud-edge-architecture.md