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

# ── 1. Install custom nodes via git clone ────────────────────────────────────
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    cd ComfyUI-WanVideoWrapper && \
    if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    cd ComfyUI-VideoHelperSuite && \
    if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

# ── 2. Download model weights (using wget for reliability on large files) ────

# Create model directories
RUN mkdir -p /comfyui/models/diffusion_models \
             /comfyui/models/vae \
             /comfyui/models/clip_vision \
             /comfyui/models/text_encoders \
             /comfyui/models/wav2vec

# Wan2.1 Image-to-Video 14B model (480P variant — ~25GB)
RUN wget -c -t 0 --timeout=60 --waitretry=10 --retry-connrefused \
    -O /comfyui/models/diffusion_models/wan2.1_i2v_480p_14B_fp16.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp16.safetensors"

# Wan2.1 VAE (~200MB)
RUN wget -c -t 0 --timeout=60 --waitretry=10 --retry-connrefused \
    -O /comfyui/models/vae/wan_2.1_vae.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"

# Wan2.1 CLIP vision encoder (~1GB)
RUN wget -c -t 0 --timeout=60 --waitretry=10 --retry-connrefused \
    -O /comfyui/models/clip_vision/clip_vision_h.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

# Wan2.1 T5 text encoder (~5GB)
RUN wget -c -t 0 --timeout=60 --waitretry=10 --retry-connrefused \
    -O /comfyui/models/text_encoders/umt5_xxl_fp16.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors"

# InfiniteTalk / MultiTalk audio-conditioning weights (~500MB)
RUN wget -c -t 0 --timeout=60 --waitretry=10 --retry-connrefused \
    -O /comfyui/models/diffusion_models/infinitetalk.safetensors \
    "https://huggingface.co/MeiGen-AI/InfiniteTalk/resolve/main/single/infinitetalk.safetensors"

# chinese-wav2vec2-base audio encoder (full HuggingFace model directory ~400MB)
RUN pip install --no-cache-dir huggingface_hub && \
    python -c "from huggingface_hub import snapshot_download; snapshot_download('TencentGameMate/chinese-wav2vec2-base', local_dir='/comfyui/models/wav2vec')"

# ── 3. Install additional Python dependencies ───────────────────────────────
RUN pip install --no-cache-dir librosa soundfile

# ── 4. Copy the default workflow (optional) ──────────────────────────────────
COPY workflow_api.json /comfyui/user/default/workflows/infinitetalk_api.json
