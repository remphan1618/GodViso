# Small Alternate VisoMaster Setup with Caddy and KasmVNC
# Base Image: Ubuntu 22.04
FROM ubuntu:22.04 AS base

LABEL maintainer="remphan1618"
LABEL description="VisoMaster with Caddy, KasmVNC, Supervisord. Small Alternate Setup."

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

ENV KASM_VNC_PATH=/usr/share/kasmvnc

# Install base dependencies, Miniconda prerequisites, Supervisord, wget, git, xvfb, Caddy, and KasmVNC deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    bzip2 \
    unzip \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    supervisor \
    xvfb \
    # KasmVNC dependencies
    libjpeg-turbo8 \
    libwebp6 \
    libfontconfig1 \
    x11vnc \
    xvfb \
    xterm \
    # Caddy dependencies
    curl \
    gnupg \
    # Clean up
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Caddy
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update && apt-get install -y caddy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Miniconda Installation ---
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p $CONDA_DIR && \
    rm ~/miniconda.sh && \
    $CONDA_DIR/bin/conda clean -tipsy && \
    ln -s $CONDA_DIR/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". $CONDA_DIR/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

# Set up Conda environment for VisoMaster
COPY s-alt/environment.yml /tmp/environment.yml
RUN conda env create -f /tmp/environment.yml && \
    conda clean -afy && \
    rm /tmp/environment.yml

# Activate Conda environment by default in shell
SHELL ["/bin/bash", "-c"]
RUN echo "conda activate visomaster" >> ~/.bashrc

# --- KasmVNC Installation ---
RUN wget https://github.com/kasmtech/KasmVNC/releases/download/v1.2.0/kasmvncserver_jammy_1.2.0_amd64.deb -O /tmp/kasmvnc.deb && \
    apt-get update && apt-get install -y /tmp/kasmvnc.deb && \
    rm /tmp/kasmvnc.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- KasmVNC Configuration ---
# Allow connections from Caddy (running in the same container) by removing localhost restriction
RUN sed -i 's/-localhost//' /etc/kasmvnc/vncserver.conf
# Disable authentication by setting SecurityTypes=None
RUN echo "SecurityTypes=None" >> /etc/kasmvnc/vncserver.conf

# --- Application Setup ---
ENV APP_DIR=/app
WORKDIR $APP_DIR

# Clone VisoMaster repository
RUN git clone https://github.com/joshsylvia/VisoMaster.git VisoMaster

# Set up directories for models, dependencies, and logs
ENV VISOMASTER_MODELS_DIR=$APP_DIR/models
ENV DEPS_DIR=$APP_DIR/dependencies
ENV LOGS_DIR=$APP_DIR/logs
RUN mkdir -p $VISOMASTER_MODELS_DIR $DEPS_DIR $LOGS_DIR

# Copy configuration files and entrypoint script from ROOT
COPY download_and_start.sh /app/download_and_start.sh
COPY s-alt/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY s-alt/Caddyfile /etc/caddy/Caddyfile

COPY s-alt/index.html /app/index.html

# Make entrypoint script executable
RUN chmod +x /app/download_and_start.sh

# Expose Caddy's port (KasmVNC is proxied)
EXPOSE 11111

# Set the entrypoint to the common script
ENTRYPOINT ["/app/download_and_start.sh"]

# Default command (will be executed by entrypoint script)
# This CMD is mostly a placeholder as supervisord starts the main processes.
# We keep a simple command like sleep to keep the container running if supervisord fails.
CMD ["sleep", "infinity"]