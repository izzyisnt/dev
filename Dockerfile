# ── Stage 1: builder ────────────────────────────────
FROM nvidia/cuda:12.3.0-devel-ubuntu22.04 AS builder

# Install system deps
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      sudo git curl && \
    rm -rf /var/lib/apt/lists/*

# Inject your SSH public key (build‐arg)
ARG PUBLIC_KEY
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    echo "${PUBLIC_KEY}" > /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys


# ── Stage 2: runtime ────────────────────────────────
FROM nvidia/cuda:12.3.0-runtime-ubuntu22.04

# 1) Install SSH + Python runtime
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      openssh-server python3 python3-pip python3-distutils && \
    rm -rf /var/lib/apt/lists/*

# 2) Symlink python → python3
RUN ln -s /usr/bin/python3 /usr/bin/python

RUN pip install \
      rdkit-pypi==2022.9.5 \
      trimesh openmm pymeshfix plyfile loguru matplotlib pyvista Pillow



# 3) Ensure SSH dirs
RUN mkdir -p /run/sshd /root/.ssh && chmod 700 /root/.ssh

# 4) Copy over baked-in key & fix perms
COPY --from=builder /root/.ssh/authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# 5) Patch sshd_config for key-only root login
RUN sed -i -E \
      -e 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' \
      -e 's/^#?PermitRootLogin .*/PermitRootLogin yes/' \
      -e 's|^#?AuthorizedKeysFile .*|AuthorizedKeysFile .ssh/authorized_keys|' \
      /etc/ssh/sshd_config

# 6) SurfDock code
WORKDIR /root/SurfDock
COPY SurfDock/ .

# 7) Expose SSH & start
EXPOSE 22
CMD ["/usr/sbin/sshd","-D"]
