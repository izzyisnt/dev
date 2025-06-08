#!/bin/bash
set -euxo pipefail

# === SurfDock Setup Script (bootstrap stage) ===
echo "🚀 Starting SurfDock setup in container..."

# Optional: virtualenv setup (skip if installing system-wide)
# python3 -m venv /opt/venv && source /opt/venv/bin/activate

# === System Dependencies (add as needed during testing) ===
echo "📦 Installing system packages..."
apt-get update && \
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libeigen3-dev \
    libboost-all-dev \
    openbabel \
    swig \
    g++ \
    libopenmm-dev \
    cmake \
    make \
    && rm -rf /var/lib/apt/lists/*

# === Python Dependencies ===
echo "🐍 Installing Python packages..."
pip install --upgrade pip setuptools wheel

# You can add additional pip packages here as you confirm they work:
pip install trimesh openmm pymeshfix plyfile rdkit-pypi loguru

# === Mountpoint/Project install ===
echo "📂 Checking for editable install..."
if [ -f "/workspace/setup.py" ] && [ ! -f "/workspace/.setup_complete" ]; then
    pip install -e /workspace
    touch /workspace/.setup_complete
fi

echo "✅ SurfDock environment ready."
