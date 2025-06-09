# ── Stage 1: builder ────────────────────────────────
FROM nvidia/cuda:12.3.0-devel-ubuntu22.04 AS builder

# Install system deps
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      python3.10 python3-pip python3-distutils  sudo openssh-server git curl && \
    rm -rf /var/lib/apt/lists/*

# Install all Python deps (torch, rdkit, etc.)
RUN pip install --upgrade pip setuptools wheel && \
#    pip install \
#      "numpy<2.0" \
#      torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
#        --index-url https://download.pytorch.org/whl/cu121 && \
    pip install \
      rdkit-pypi==2022.9.5 \
      trimesh openmm pymeshfix plyfile loguru matplotlib pyvista Pillow

ARG PUBLIC_KEY
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    echo "${PUBLIC_KEY}" > /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys

# Patch sshd_config to ensure key-based login works
RUN sed -i -E \
    -e 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' \
    -e 's/^#?PermitRootLogin .*/PermitRootLogin yes/' \
    -e 's|^#?AuthorizedKeysFile .*|AuthorizedKeysFile .ssh/authorized_keys|' \
    /etc/ssh/sshd_config

RUN sshd -t



# ── Stage 2: runtime ────────────────────────────────
FROM nvidia/cuda:12.3.0-runtime-ubuntu22.04
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
#COPY --from=builder /usr/local/bin/pip* /usr/local/bin/
#COPY --from=builder /usr/bin/python3 /usr/bin/python3
RUN ln -s /usr/bin/python3 /usr/bin/python

# Re-create SSH dirs
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd /root/.ssh && chmod 700 /root/.ssh

# Copy the key from builder image
COPY --from=builder /root/.ssh/authorized_keys /root/.ssh/authorized_keys

# SurfDock code
WORKDIR /root/SurfDock
COPY SurfDock/ .

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
