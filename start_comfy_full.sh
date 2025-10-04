#!/bin/bash
set -e

WORKDIR=/workspace
COMFY_DIR=$WORKDIR/ComfyUI
VENV_DIR=$WORKDIR/venv
PORT_COMFY=8188
PORT_JUPYTER=8888

echo "=== Starting ComfyUI + Manager + Popular Nodes + JupyterLab ==="

cd $WORKDIR
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

apt update && apt install -y git wget pciutils

# GPU detection
CUDA_VERSION=$(nvcc --version 2>/dev/null | grep "release" | awk '{print $6}' | sed 's/,//')
if [[ -z "$CUDA_VERSION" ]]; then
    CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}')
fi
if [[ "$CUDA_VERSION" == 12* ]]; then
    TORCH_URL="https://download.pytorch.org/whl/cu121"
else
    TORCH_URL="https://download.pytorch.org/whl/cu118"
fi

# ComfyUI install/update
if [ ! -d "$COMFY_DIR" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
else
    cd "$COMFY_DIR"
    git pull
fi
cd "$COMFY_DIR"
pip install --upgrade pip wheel setuptools
pip install -r requirements.txt
pip install torch torchvision torchaudio --extra-index-url "$TORCH_URL"

# ComfyUI Manager install/update
CUSTOM_NODES_DIR="$COMFY_DIR/custom_nodes"
MANAGER_DIR="$CUSTOM_NODES_DIR/ComfyUI-Manager"
if [ ! -d "$MANAGER_DIR" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$MANAGER_DIR"
else
    cd "$MANAGER_DIR"
    git pull
fi

# Install popular nodes
cd "$CUSTOM_NODES_DIR"
# Example list of popular custom nodes
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git || true
git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git || true
git clone https://github.com/AloneMonkey/ComfyUI-TiledVAE.git || true

# Link shared storage
SHARED_MODELS=$WORKDIR/storage/models
SHARED_NODES=$WORKDIR/storage/custom_nodes
if [ -d "$SHARED_MODELS" ]; then ln -sfn "$SHARED_MODELS" "$COMFY_DIR/models"; fi
if [ -d "$SHARED_NODES" ]; then ln -sfn "$SHARED_NODES" "$COMFY_DIR/custom_nodes_shared"; fi

# JupyterLab
pip install --upgrade jupyterlab notebook ipykernel
mkdir -p "$WORKDIR"
nohup jupyter lab --ip=0.0.0.0 --port=$PORT_JUPYTER --no-browser --NotebookApp.token='' --NotebookApp.password='' --notebook-dir="$WORKDIR" > $WORKDIR/jupyter.log 2>&1 &

# Start ComfyUI
cd "$COMFY_DIR"
python main.py --listen 0.0.0.0 --port $PORT_COMFY