# ============================================================================
# RunPod Serverless Worker — InfiniteTalk (THIN image, built by RunPod)
#
# This Dockerfile extends the pre-built base image that has all models and
# custom nodes already baked in. It only copies the workflow file, so it
# builds in seconds and easily fits within RunPod's 30-min build limit.
#
# Prerequisites:
#   1. Build the base image locally:
#      docker build -f Dockerfile.base -t smokeylowkey/demohook-infinitetalk-base:latest .
#   2. Push to Docker Hub:
#      docker push smokeylowkey/demohook-infinitetalk-base:latest
#   3. Then RunPod builds THIS Dockerfile from your GitHub repo.
# ============================================================================

FROM smokeylowkey/demohook-infinitetalk-base:latest

# Only thing that changes between deploys — the workflow config
COPY workflow_api.json /comfyui/user/default/workflows/infinitetalk_api.json
