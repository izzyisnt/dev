# Dockerfile for ghcr.io/izzyisnt/dev:latest
FROM nvidia/cuda:12.3.0-devel-ubuntu22.04

# System dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    openssh-server sudo git curl vim tmux build-essential \
 && rm -rf /var/lib/apt/lists/*

# Add docker user for SSH login
RUN useradd -ms /bin/bash docker && \
    echo "docker ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /var/run/sshd /home/docker/.ssh && \
    chown docker:docker /home/docker/.ssh

# Inject public key at build time
ARG PUBLIC_KEY
RUN echo "${PUBLIC_KEY}" > /home/docker/.ssh/authorized_keys && \
    chmod 600 /home/docker/.ssh/authorized_keys && \
    chown docker:docker /home/docker/.ssh/authorized_keys


# ssh in and run it
COPY setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh


EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
