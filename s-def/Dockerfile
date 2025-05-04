# Small Default VisoMaster Setup with KasmVNC only
# Base Image: Ubuntu 22.04
FROM ubuntu:22.04 AS base

LABEL maintainer="remphan1618"
LABEL description="VisoMaster with KasmVNC and Supervisord. Small Default Setup."

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV KASM_VNC_PATH /usr/share/kasmvnc

# Install base dependencies, Miniconda prerequisites, Supervisord, wget, git, xvfb, and KasmVNC deps
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
    # Clean up
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Miniconda Installation ---
ENV CONDA_DIR /opt/conda
ENV PATH $CONDA_DIR/bin:$PATH

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p $CONDA_DIR && \
    rm ~/miniconda.sh && \
    $CONDA_DIR/bin/conda clean -tipsy && \
    ln -s $CONDA_DIR/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". $CONDA_DIR/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

# Set up Conda environment for VisoMaster
COPY s-def/environment.yml /tmp/environment.yml
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

# Configure KasmVNC to listen on all interfaces by default for direct access
# Update the default kasmvnc configuration to remove -localhost restriction
RUN sed -i 's/-localhost//' /etc/kasmvnc/vncserver.conf

# --- Application Setup ---
ENV APP_DIR /app
WORKDIR $APP_DIR

# Clone VisoMaster repository
RUN git clone https://github.com/joshsylvia/VisoMaster.git VisoMaster

# Set up directories for models, dependencies, and logs
ENV VISOMASTER_MODELS_DIR $APP_DIR/models
ENV DEPS_DIR $APP_DIR/dependencies
ENV LOGS_DIR $APP_DIR/logs
RUN mkdir -p $VISOMASTER_MODELS_DIR $DEPS_DIR $LOGS_DIR

# Copy configuration files and entrypoint script from ROOT
COPY download_and_start.sh /app/download_and_start.sh
COPY s-def/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
# No Caddyfile needed for this setup

# Make entrypoint script executable
RUN chmod +x /app/download_and_start.sh

# Expose KasmVNC's default web port
EXPOSE 8443

# Set the entrypoint to the common script
ENTRYPOINT ["/app/download_and_start.sh"]

# Default command (will be executed by entrypoint script)
# This CMD is mostly a placeholder as supervisord starts the main processes.
# We keep a simple command like sleep to keep the container running if supervisord fails.
CMD ["sleep", "infinity"]