# Cloud Run Deploy Commands

## 1. Purpose

This document records the draft deployment commands for Cloud Migration Phase 1.

These commands are templates only.
They should be reviewed before actual execution.

---

## 2. Assumptions

- Region: `asia-northeast1`
- Edge Gateway already exists as:
  - `qixundemo-gateway`
- New backend services to deploy:
  - `openclaw-poc-gateway`
  - `openclaw-poc-runtime`

Placeholders below must be replaced before execution:

- `<PROJECT_ID>`
- `<IMAGE_TAG>`
- `<GATEWAY_IMAGE>`
- `<RUNTIME_IMAGE>`
- `<GEMINI_API_KEY>`
- `<GEMINI_MODEL>`
- `<CLOUD_GATEWAY_URL>`

---

## 3. Example Image Tags

Suggested image naming:

- `gcr.io/<PROJECT_ID>/openclaw-poc-gateway:<IMAGE_TAG>`
- `gcr.io/<PROJECT_ID>/openclaw-poc-runtime:<IMAGE_TAG>`

Example:

```bash
export PROJECT_ID=<PROJECT_ID>
export IMAGE_TAG=phase1-v1
export GATEWAY_IMAGE=gcr.io/$PROJECT_ID/openclaw-poc-gateway:$IMAGE_TAG
export RUNTIME_IMAGE=gcr.io/$PROJECT_ID/openclaw-poc-runtime:$IMAGE_TAG

4. Build Commands
Backend Gateway
docker build -t "$GATEWAY_IMAGE" .
docker push "$GATEWAY_IMAGE"
Backend Runtime

If Runtime and Gateway use the same repo/image build context, adjust Docker strategy before execution.
If separate Docker targets are introduced later, replace this section accordingly.

docker build -t "$RUNTIME_IMAGE" .
docker push "$RUNTIME_IMAGE"
5. Deploy openclaw-poc-gateway
gcloud run deploy openclaw-poc-gateway \
  --image "$GATEWAY_IMAGE" \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --set-env-vars GEMINI_MODEL=<GEMINI_MODEL> \
  --set-secrets GEMINI_API_KEY=<GEMINI_API_KEY_SECRET_NAME>:latest
Notes

Replace <GEMINI_API_KEY_SECRET_NAME> with the actual Secret Manager secret name.

If unauthenticated access is not desired, revise before execution.

6. Capture deployed Gateway URL

After deploy:

gcloud run services describe openclaw-poc-gateway \
  --region asia-northeast1 \
  --format='value(status.url)'

Store the result as:

export CLOUD_GATEWAY_URL=https://openclaw-poc-gateway-<hash>-asia-northeast1.run.app
7. Deploy openclaw-poc-runtime
gcloud run deploy openclaw-poc-runtime \
  --image "$RUNTIME_IMAGE" \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --set-env-vars GATEWAY_URL="$CLOUD_GATEWAY_URL"
8. Capture deployed Runtime URL

After deploy:

gcloud run services describe openclaw-poc-runtime \
  --region asia-northeast1 \
  --format='value(status.url)'

Store the result as:

export CLOUD_RUNTIME_URL=https://openclaw-poc-runtime-<hash>-asia-northeast1.run.app
9. Post-Deploy Verification Commands
Gateway health
curl -s "$CLOUD_GATEWAY_URL/healthz"
Gateway list agents
curl -s "$CLOUD_GATEWAY_URL/v1/agents/list"
Gateway list tools
curl -s "$CLOUD_GATEWAY_URL/v1/tools/list?agent_id=realestate"
Runtime health
curl -s "$CLOUD_RUNTIME_URL/healthz"
Runtime agents
curl -s -X POST "$CLOUD_RUNTIME_URL/message" \
  -H "Content-Type: application/json" \
  -d '{"chat_id":"cloud-test-1","message":"/agents"}'
10. Retarget Preparation for Local Bridge

Do not execute this until:

cloud Gateway is verified

cloud Runtime is verified

Edge Gateway route is ready

Future intended value:

export RUNTIME_BASE_URL=https://gateway.qixundemo.com/runtime
11. Rollback Reminder

Fast rollback path:

keep local backend path available

revert bridge target back to http://127.0.0.1:9100

rollback Cloud Run service image/config only after confirming issue source

12. Status

This file is a draft command template for Phase 1 implementation.
Review before execution.
```
