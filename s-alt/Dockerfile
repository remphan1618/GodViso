# Use an official Ubuntu base image
FROM ubuntu:22.04

# Set the working directory inside the container
WORKDIR /app

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set path for KasmVNC (ensure this variable is needed by subsequent steps or scripts)
ENV KASM_VNC_PATH=/usr/share/kasmvnc

# Install base dependencies, Miniconda prerequisites, Supervisord, wget, git, xvfb, Caddy, and KasmVNC deps
# Update package lists and install dependencies in a single RUN command to reduce layers
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    supervisor \
    wget \
    git \
    xvfb \
    libxkbcommon-x11-0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcb-xinerama0 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxrandr2 \
    libxtst6 \
    libnss3 \
    libcups2 \
    libxss1 \
    libxrender1 \
    libasound2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libgbm1 \
    libglib2.0-0 \
    # Install Caddy
    && install -y debian-keyring debian-archive-keyring apt-transport-https \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update \
    && apt-get install -y caddy \
    # Clean up apt lists to reduce image size
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
ENV CONDA_DIR=/opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p $CONDA_DIR && \
    rm ~/miniconda.sh && \
    $CONDA_DIR/bin/conda init bash

# Make conda command available in subsequent RUN instructions
SHELL ["/bin/bash", "--login", "-c"]

# --- File Copy Section ---
# NOTE: The source paths below assume the build context is the repository root,
#       and these files exist in the 's-alt' subdirectory relative to the root.

# Copy the Conda environment file from the s-alt directory in the build context
# to the current WORKDIR (/app) in the container.
COPY ./s-alt/environment.yml .
RUN conda env create -f environment.yml --prefix /opt/conda/envs/viso_env && \
    # Remove the copied file after use to keep the image clean
    rm environment.yml

# Activate the Conda environment for subsequent commands
ENV PATH /opt/conda/envs/viso_env/bin:$PATH

# Copy the requirements file from the root of the build context
# to the current WORKDIR (/app) in the container.
# Ensure 'requirements.txt' exists at the repository root or adjust path.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    # Remove the copied file after use
    rm requirements.txt

# Download KasmVNC
ENV KASM_VNC_VERSION=1.3.1
RUN wget "https://github.com/kasmtech/KasmVNC/releases/download/v${KASM_VNC_VERSION}/KasmVNC_debian_bookworm_${KASM_VNC_VERSION}_amd64.deb" -O /tmp/kasmvnc.deb && \
    apt-get update && apt-get install -y /tmp/kasmvnc.deb && rm /tmp/kasmvnc.deb && \
    # Clean up apt lists again after installing the deb package
    rm -rf /var/lib/apt/lists/*

# Copy the application code from the VisoMaster directory in the build context
# into the /app/VisoMaster directory in the container.
COPY ./VisoMaster /app/VisoMaster

# Copy the specific index.html from the s-alt directory in the build context
# to the target location within the application code in the container.
# Removed trailing comment that might cause issues.
COPY ./s-alt/index.html /app/VisoMaster/app/ui/web/templates/index.html

# Copy Supervisord configuration file from the s-alt directory in the build context
# into the container. Ensure 'supervisord.conf' exists in './s-alt/'.
COPY ./s-alt/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy Caddy configuration file from the s-alt directory in the build context
# into the container. Ensure 'Caddyfile' exists in './s-alt/'.
COPY ./s-alt/Caddyfile /etc/caddy/Caddyfile

# --- End File Copy Section ---

# Expose ports for VNC, the web UI, and potentially other services if needed
EXPOSE 6901 5000

# Set the entrypoint to run Supervisord
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Default command (can be overridden)
CMD ["--nodaemon"]
