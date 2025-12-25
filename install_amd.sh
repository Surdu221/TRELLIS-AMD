#!/bin/bash
# TRELLIS-AMD Installation Script
# Tested on: AMD RX 7800 XT, ROCm 6.4.2, Ubuntu

set -e

echo "=============================================="
echo "  TRELLIS-AMD Installation Script"
echo "  For AMD GPUs with ROCm"
echo "=============================================="

# Check for ROCm
if ! command -v rocminfo &> /dev/null; then
    echo "ERROR: ROCm not found. Please install ROCm 6.4+ first."
    echo "See: https://rocm.docs.amd.com/projects/install-on-linux/en/latest/"
    exit 1
fi

# Detect GPU
GPU_ARCH=$(rocminfo | grep -o 'gfx[0-9a-z]*' | head -1)
if [ -z "$GPU_ARCH" ]; then
    echo "WARNING: Could not detect GPU architecture, defaulting to gfx1100"
    GPU_ARCH="gfx1100"
fi
echo "Detected GPU: $GPU_ARCH"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "[1/7] Creating Python virtual environment..."
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate

echo "[2/7] Upgrading pip..."
pip install --upgrade pip wheel setuptools

echo "[3/7] Installing PyTorch for ROCm..."
# Check if torch is already installed with ROCm
if python3 -c "import torch; exit(0 if hasattr(torch.version, 'hip') else 1)" 2>/dev/null; then
    echo "PyTorch for ROCm already installed"
else
    pip install torch torchvision --index-url https://download.pytorch.org/whl/rocm6.4
fi

echo "[4/7] Installing TRELLIS Python dependencies..."
pip install -r requirements.txt

echo "[5/7] Installing nvdiffrast-hip..."
cd extensions/nvdiffrast-hip
pip install . --no-build-isolation
cd ../..

echo "[6/7] Building diff-gaussian-rasterization (manual HIP build)..."
cd extensions/diff-gaussian-rasterization
chmod +x build_hip.sh
./build_hip.sh
cd ../..

echo "[7/7] Installing torchsparse..."
# Try pip first, if that fails try from source
if ! pip install torchsparse 2>/dev/null; then
    echo "pip install torchsparse failed, you may need to install it manually"
    echo "See: https://github.com/mit-han-lab/torchsparse"
fi

echo ""
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo ""
echo "If you encountered any errors during the build,"
echo "make sure you have these system dependencies:"
echo "  - ROCm 6.4+"
echo "  - hipcc compiler"
echo "  - Python development headers"
echo ""
echo "To run TRELLIS:"
echo "  source .venv/bin/activate"
echo "  ATTN_BACKEND=sdpa XFORMERS_DISABLED=1 SPARSE_BACKEND=torchsparse python app.py"
echo ""
echo "Then open http://localhost:7860 in your browser"
