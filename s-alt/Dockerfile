# Use an official Ubuntu base image
FROM ubuntu:22.04

# Set the working directory inside the container
WORKDIR /app

# Prevent interactive prompts during package installation
# Using recommended key=value format
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
    libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-xinerama0 \
    libxcomposite1 libxcursor1 libxdamage1 libxrandr2 libxtst6 libnss3 libcups2 libxss1 libxrender1 \
    libasound2 libpangocairo-1.0-0 libatk1.0-0 libatk-bridge2.0-0 libgtk-3-0 libgbm1 libglib2.0-0 \
    # Packages needed for adding Caddy repository
    debian-keyring debian-archive-keyring apt-transport-https \
    && \
    # Add Caddy repository and install Caddy
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && \
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list && \
    apt-get update && \
    apt-get install -y caddy && \
    # Clean up apt lists to reduce image size
    rm -rf /var/lib/apt/lists/*

# --- Combined Miniconda Install and Environment Creation ---
ENV CONDA_DIR=/opt/conda
# Copy environment file first
COPY ./s-alt/environment.yml /tmp/environment.yml
# Install Miniconda and create the environment in the same RUN layer
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p $CONDA_DIR && \
    rm ~/miniconda.sh && \
    # Use the installed conda to create the environment immediately
    $CONDA_DIR/bin/conda env create -f /tmp/environment.yml --prefix /opt/conda/envs/viso_env && \
    # Clean up the environment file
    rm /tmp/environment.yml && \
    # Clean conda cache
    $CONDA_DIR/bin/conda clean -afy

# Activate the Conda environment for subsequent commands by adding its bin dir to PATH
# This ensures commands like 'pip' and 'python' use the environment's versions
ENV PATH /opt/conda/envs/viso_env/bin:$PATH

# --- File Copy Section (excluding environment.yml which was handled above) ---

# Copy the requirements file from the root of the build context
# to the current WORKDIR (/app) in the container.
# Ensure 'requirements.txt' exists at the repository root or adjust path.
COPY requirements.txt .
# This pip command should now use the pip from the activated viso_env
# Added pip cache purge to prevent "No space left on device" errors
RUN pip install --no-cache-dir -r requirements.txt && \
    # Remove the copied file after use
    rm requirements.txt && \
    # Clean pip cache to save space
    pip cache purge

# Download and Install KasmVNC
ENV KASM_VNC_VERSION=1.3.1
RUN wget "https://github.com/kasmtech/KasmVNC/releases/download/v${KASM_VNC_VERSION}/KasmVNC_debian_bookworm_${KASM_VNC_VERSION}_amd64.deb" -O /tmp/kasmvnc.deb && \
    apt-get update && apt-get install -y --no-install-recommends /tmp/kasmvnc.deb && \
    rm /tmp/kasmvnc.deb && \
    # Clean up apt lists again after installing the deb package
    rm -rf /var/lib/apt/lists/*

# Copy the application code from the VisoMaster directory in the build context
# into the /app/VisoMaster directory in the container.
COPY ./VisoMaster /app/VisoMaster

# Copy the specific index.html from the s-alt directory in the build context
# to the target location within the application code in the container.
COPY ./s-alt/index.html /app/VisoMaster/app/ui/web/templates/index.html

# Copy Supervisord configuration file from the s-alt directory in the build context
# into the container. Ensure 'supervisord.conf' exists in './s-alt/'.
COPY ./s-alt/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy Caddy configuration file from the s-alt directory in the build context
# into the container. Ensure 'Caddyfile' exists in './s-alt/'.
COPY ./s-alt/Caddyfile /etc/caddy/Caddyfile

# Copy the startup script and make it executable
# Ensure download_and_start.sh is in the repository root
COPY download_and_start.sh /app/download_and_start.sh
RUN chmod +x /app/download_and_start.sh

# --- End File Copy Section ---

# Expose ports for VNC, the web UI, and potentially other services if needed
EXPOSE 6901 5000

# Set the entrypoint to the startup script
ENTRYPOINT ["/app/download_and_start.sh"]

# Set the default command to be executed by the entrypoint script's 'exec "$@"'
# This will start supervisord in the foreground after the script runs
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf", "--nodaemon"]
