# ============================================================================
# RunPod Serverless ComfyUI Worker — InfiniteTalk (lip-sync avatar generation)
#
# Builds a Docker image with:
#   - ComfyUI base
#   - ComfyUI-WanVideoWrapper (InfiniteTalk custom nodes)
#   - ComfyUI-VideoHelperSuite (VHS_VideoCombine for MP4 output)
#   - Wan2.1-I2V-14B-480P diffusion model
#   - MeiGen-AI/InfiniteTalk audio conditioning weights
#   - chinese-wav2vec2-base audio encoder
#
# Build:  docker build -t demohook-infinitetalk .
# Size:   ~40GB (models baked in)
# GPU:    RTX 4090 (24GB VRAM) recommended
# ============================================================================

FROM runpod/worker-comfyui:5.1.0-base

# ── 1. Install custom nodes via git clone (comfy-cli registry names are unreliable) ──
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    cd ComfyUI-WanVideoWrapper && \
    pip install -r requirements.txt || true

RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    cd ComfyUI-VideoHelperSuite && \
    pip install -r requirements.txt || true

# ── 2. Download model weights ───────────────────────────────────────────────

# Wan2.1 Image-to-Video 14B model (480P variant — ~25GB)
RUN comfy model download \
    --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_bf16.safetensors \
    --relative-path models/diffusion_models

# Wan2.1 VAE
RUN comfy model download \
    --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors \
    --relative-path models/vae

# Wan2.1 CLIP vision encoder
RUN comfy model download \
    --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/wan2.1_i2v_clip_vision.safetensors \
    --relative-path models/clip_vision

# Wan2.1 T5 text encoder
RUN comfy model download \
    --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5-xxl-enc-bf16.safetensors \
    --relative-path models/text_encoders

# InfiniteTalk / MultiTalk audio-conditioning weights
RUN comfy model download \
    --url https://huggingface.co/MeiGen-AI/InfiniteTalk/resolve/main/InfiniteTalk_single.safetensors \
    --relative-path models/diffusion_models

# chinese-wav2vec2-base audio encoder (full HuggingFace model directory)
RUN pip install huggingface_hub && \
    python -c "from huggingface_hub import snapshot_download; snapshot_download('TencentGameMate/chinese-wav2vec2-base', local_dir='/comfyui/models/wav2vec')"

# ── 3. Install additional Python dependencies ───────────────────────────────
RUN pip install --no-cache-dir librosa soundfile

# ── 4. Copy the default workflow for health checks (optional) ────────────────
COPY workflow_api.json /comfyui/user/default/workflows/infinitetalk_api.json
