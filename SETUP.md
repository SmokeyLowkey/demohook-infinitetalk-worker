# RunPod Serverless Endpoint Setup — InfiniteTalk

Step-by-step guide to deploy a ComfyUI + InfiniteTalk serverless endpoint on RunPod for avatar lip-sync video generation.

## Prerequisites

- RunPod account with billing enabled
- Docker installed locally (or use RunPod's GitHub build)
- ~40GB disk space for the Docker image

## Option A: Deploy via GitHub (Recommended)

RunPod can build and deploy directly from a GitHub repo.

### 1. Push the `runpod/` directory to a GitHub repo

Create a new repo (e.g., `demohook-infinitetalk-worker`) and push:

```bash
cd runpod/
git init
git add Dockerfile workflow_api.json
git commit -m "InfiniteTalk RunPod serverless worker"
git remote add origin https://github.com/YOUR_ORG/demohook-infinitetalk-worker.git
git push -u origin main
```

### 2. Create the serverless endpoint on RunPod

1. Go to [RunPod Console](https://www.runpod.io/console/serverless)
2. Click **New Endpoint**
3. Select **Start from GitHub Repo**
4. Authorize RunPod to access your repo
5. Select the repo and branch (`main`)
6. Configure:

| Setting | Value |
|---------|-------|
| GPU | RTX 4090 (24GB) |
| Max Workers | 15 (start here, scale later) |
| Active (Idle) Workers | 2-3 |
| Idle Timeout | 30 seconds |
| Execution Timeout | 600 seconds (10 min) |
| Container Disk Size | 50 GB |

7. Click **Deploy**
8. RunPod will build the Docker image (~20-30 min first time)
9. Note your **Endpoint ID** from the dashboard

### 3. Get your API key

1. Go to [RunPod Settings > API Keys](https://www.runpod.io/console/user/settings)
2. Create or copy your API key

### 4. Set environment variables in DemoHook

Add to your `.env.local`:

```
RUNPOD_API_KEY=your_runpod_api_key_here
RUNPOD_ENDPOINT_ID=your_endpoint_id_here
```

Add the same values to your Vercel deployment environment variables.

---

## Option B: Build and Push Docker Image Manually

### 1. Build the image

```bash
cd runpod/
docker build -t your-registry/demohook-infinitetalk:latest .
```

This will take 30-60 minutes (downloading ~28GB of model weights).

### 2. Push to Docker Hub or a container registry

```bash
docker push your-registry/demohook-infinitetalk:latest
```

### 3. Create the endpoint

1. Go to [RunPod Console > Serverless](https://www.runpod.io/console/serverless)
2. Click **New Endpoint**
3. Select **Use a custom Docker image**
4. Enter your image: `your-registry/demohook-infinitetalk:latest`
5. Configure GPU, workers, and timeouts (same as Option A table above)
6. Deploy

---

## Verify the Endpoint

### Health check

```bash
curl https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/health \
  -H "Authorization: Bearer YOUR_API_KEY"
```

Expected response:
```json
{
  "jobs": { "completed": 0, "failed": 0, "inProgress": 0, "inQueue": 0, "retried": 0 },
  "workers": { "idle": 2, "initializing": 0, "ready": 2, "running": 0, "throttled": 0 }
}
```

### Test generation

```bash
# Submit a test job (replace with your own image/audio URLs)
curl -X POST https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/run \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "workflow": <contents of workflow_api.json>,
      "images": [
        {
          "name": "input_image.png",
          "image": "<base64-encoded-image>"
        }
      ]
    }
  }'
```

Then poll for status:

```bash
curl https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/status/JOB_ID \
  -H "Authorization: Bearer YOUR_API_KEY"
```

---

## Model Details

| Component | Size | Source |
|-----------|------|--------|
| Wan2.1-I2V-14B-480P (diffusion) | ~25GB | `Comfy-Org/Wan_2.1_ComfyUI_repackaged` |
| Wan2.1 VAE | ~200MB | `Comfy-Org/Wan_2.1_ComfyUI_repackaged` |
| Wan2.1 CLIP Vision | ~1GB | `Comfy-Org/Wan_2.1_ComfyUI_repackaged` |
| UMT5-XXL Text Encoder | ~5GB | `Comfy-Org/Wan_2.1_ComfyUI_repackaged` |
| InfiniteTalk Single | ~500MB | `MeiGen-AI/InfiniteTalk` |
| chinese-wav2vec2-base | ~400MB | `TencentGameMate/chinese-wav2vec2-base` |

Total: ~32GB of model weights baked into the Docker image.

## VRAM Usage

| Resolution | VRAM | Generation Time (RTX 4090) |
|------------|------|----------------------------|
| 480p (832x480) | ~12GB | ~2-4 min for 60s clip |
| 720p (1280x720) | ~20GB | ~5-8 min for 60s clip |

## Concurrency & Scaling

- Each worker handles 1 job at a time (1 GPU = 1 generation)
- Jobs exceeding max workers are queued automatically
- Scale by increasing Max Workers in RunPod dashboard
- Monitor queue depth — if avg wait > 30s, increase Max Workers
- See the main migration plan for detailed scaling recommendations

## Troubleshooting

### "Worker not ready" or cold start delays
- Increase Active (Idle) Workers to keep warm GPUs available
- Cold start takes ~30-60s for model loading

### Out of memory errors
- Reduce resolution to 480p
- Use GGUF quantized models (Q8 for best quality/VRAM tradeoff)
- Quantized models available at `Kijai/WanVideo_comfy_GGUF` on HuggingFace

### Generation quality issues
- Increase sampling steps (20 is default, try 30-40 for better quality)
- Adjust CFG scale (3.0 default, try 2.5-4.0)
- Ensure input image is a clear, front-facing portrait photo

### Audio sync issues
- Ensure audio is clear speech without heavy background music
- The Wav2Vec encoder works best with clean vocal audio
- Audio separation node can help if source has background noise
