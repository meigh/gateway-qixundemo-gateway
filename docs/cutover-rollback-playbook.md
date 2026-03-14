# Cutover and Rollback Playbook

## 1. Purpose

This playbook describes how to cut over Phase 1 traffic to the cloud backend and how to roll back safely if problems occur.

Phase 1 principle:

- keep local QQ ingress unchanged
- change backend location only
- preserve `/poc...` contract
- keep rollback simple

---

## 2. Cutover Scope

The cutover in Phase 1 is **not**:

- moving qqbot to the cloud
- changing `gateway.ts`
- changing `/poc...` semantics

The cutover **is**:

- changing the backend target of local `qq_bridge.py`
- from local Runtime
- to `https://gateway.qixundemo.com/runtime/message`

---

## 3. Preconditions for Cutover

Do not begin cutover until all of the following are true:

- cloud Gateway is deployed
- cloud Runtime is deployed
- Edge Gateway `/runtime/*` route is deployed
- cloud backend checks have passed
- Edge Gateway checks have passed
- main smoke tests pass
- QQ bridge smoke tests pass
- local fallback backend is still available

---

## 4. Cutover Procedure

## Step 1 — confirm current local state
- verify local backend is still working
- verify current bridge target is known
- verify rollback owner is available

## Step 2 — confirm cloud backend state
- verify cloud Gateway health
- verify cloud Runtime health
- verify Edge Gateway runtime route
- verify cloud-side functional checks

## Step 3 — update bridge target
Change local `qq_bridge.py` target so that it uses:

`https://gateway.qixundemo.com/runtime/message`

Do not change command semantics or request format.

## Step 4 — run automated validation
Immediately run:
- `acceptance/smoke/run_all.sh`
- `acceptance/qq/run_bridge_smoke.sh`

## Step 5 — run live QQ validation
Verify:
- `/pocdiag`
- `/pocagents`
- `/poctools`
- `/pocwhoami`
- `/pocagent realestate`
- `/pocagent not-exist`
- `/poc <natural language>`

## Step 6 — observe
Watch for:
- route failures
- unexpected 404s
- auth failures
- Runtime → Gateway failures
- semantic drift in replies

Only after repeated success should the cutover be treated as stable.

---

## 5. Fast Rollback Principle

Fast rollback should happen in the smallest layer necessary.

Preferred rollback order:

1. revert bridge target
2. revert edge route
3. revert backend image/config

Do not change multiple layers at once unless required.

---

## 6. Fast Rollback Procedure

## Case A — bridge cutover fails immediately
Examples:
- QQ replies fail
- bridge cannot reach cloud ingress
- `/pocdiag` breaks right after retarget

Action:
1. point bridge target back to local `http://127.0.0.1:9100`
2. re-run quick QQ validation
3. keep cloud services deployed for investigation
4. do not change edge route yet unless needed

## Case B — edge route issue
Examples:
- `/runtime/*` returns wrong result
- Edge Gateway rewrite/proxy issue
- unexpected host/path behavior

Action:
1. revert `15-openclaw-poc-runtime.conf`
2. redeploy Edge Gateway
3. if bridge was already cut over, point bridge back to local Runtime
4. keep cloud Runtime/Gateway available for debugging

## Case C — Runtime issue
Examples:
- cloud Runtime health fails
- `/message` behavior fails
- session/command handling breaks cloud-side

Action:
1. rollback Runtime image/config
2. keep Gateway unchanged unless clearly involved
3. keep bridge on local backend until Runtime is corrected

## Case D — Gateway issue
Examples:
- tool execution fails
- schema validation fails unexpectedly
- allowlist behavior breaks

Action:
1. rollback Gateway image/config
2. keep Runtime unchanged unless clearly affected
3. keep bridge on local backend until Gateway is corrected

---

## 7. Rollback Validation

After rollback:

- verify local bridge target is correct
- verify local backend path works
- run QQ validation again
- confirm `/poc...` behavior is restored
- record what layer caused rollback

Minimum validation after rollback:
- `/pocdiag`
- `/pocagents`
- `/poctools`

---

## 8. Operational Notes

- keep local backend available during early cutover
- do not delete working local path too early
- record actual deployed runtime and gateway URLs
- record previous image tags before rollout
- record previous edge config before route change

---

## 9. Success Condition

Cutover is successful only when:

- bridge uses cloud ingress
- cloud Runtime/Gateway remain healthy
- Edge Gateway route remains stable
- smoke tests pass
- QQ bridge smoke tests pass
- live QQ behavior remains correct
- no rollback is needed after observation window

---
