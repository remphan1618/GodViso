# --- Stage 1: Builder ---
# Use an official Ubuntu base image
FROM ubuntu:22.04 AS builder

# Set the working directory inside the container
WORKDIR /app

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set path for KasmVNC (ensure this variable is needed by subsequent steps or scripts)
ENV KASM_VNC_PATH=/usr/share/kasmvnc

# Install base dependencies, build tools, Miniconda prerequisites, Supervisord, wget, git, xvfb, Caddy, and KasmVNC deps
# Only install build tools like wget, curl, git, gpg in this stage if not needed in final runtime
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
    # Clean up apt lists to reduce image size IN THIS STAGE
    rm -rf /var/lib/apt/lists/*

# Install Miniconda and create the environment in the same RUN layer
ENV CONDA_DIR=/opt/conda
# Copy environment file first (Ensure opencv is listed here)
COPY ./s-alt/environment.yml /tmp/environment.yml
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
ENV PATH /opt/conda/envs/viso_env/bin:$PATH

# Install pip requirements (use the requirements_other.txt file)
# Ensure opencv-python is removed from this file
COPY requirements_other.txt .
# Define extra index URLs as build arguments for reuse
ARG PYTORCH_INDEX_URL=https://download.pytorch.org/whl/cu124
ARG NVIDIA_INDEX_URL=https://pypi.nvidia.com
RUN pip install --no-cache-dir --extra-index-url ${PYTORCH_INDEX_URL} --extra-index-url ${NVIDIA_INDEX_URL} -r requirements_other.txt && \
    rm requirements_other.txt && \
    # Clean pip cache to save space
    pip cache purge

# Download and Install KasmVNC
ENV KASM_VNC_VERSION=1.3.1
RUN wget "https://github.com/kasmtech/KasmVNC/releases/download/v${KASM_VNC_VERSION}/KasmVNC_debian_bookworm_${KASM_VNC_VERSION}_amd64.deb" -O /tmp/kasmvnc.deb && \
    apt-get update && apt-get install -y --no-install-recommends /tmp/kasmvnc.deb && \
    rm /tmp/kasmvnc.deb && \
    rm -rf /var/lib/apt/lists/*

# Copy application code now if needed for any build steps, otherwise copy in final stage
# We copy it here just to ensure it's available if any build step needed it,
# but it will be copied again properly in the final stage from the build context.
COPY ./VisoMaster /app/VisoMaster


# --- Stage 2: Final Runtime Image ---
FROM ubuntu:22.04

LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="VisoMaster Small Alternate Runtime Image"

# Set the working directory
WORKDIR /app

# Install *only* essential runtime dependencies
# List only packages absolutely required by KasmVNC, Caddy, Supervisord, and your app at runtime
# This list will likely be much smaller than in the builder stage
# Ensure Caddy and Supervisor are installed here for runtime use
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    supervisor \
    ca-certificates curl gnupg \
    debian-keyring debian-archive-keyring apt-transport-https \
    # KasmVNC runtime dependencies (check KasmVNC docs for minimal set) - Example:
    libxkbcommon-x11-0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-xinerama0 \
    libxcomposite1 libxcursor1 libxdamage1 libxrandr2 libxtst6 libnss3 libcups2 libxss1 libxrender1 \
    libasound2 libpangocairo-1.0-0 libatk1.0-0 libatk-bridge2.0-0 libgtk-3-0 libgbm1 libglib2.0-0 \
    # Add any other essential runtime libs (e.g., libgl1 for GUI apps if needed via xvfb/kasmvnc)
    libgl1 \
    && \
    # Add Caddy repository and install Caddy
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && \
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list && \
    apt-get update && \
    apt-get install -y caddy && \
    # Clean up apt lists
    rm -rf /var/lib/apt/lists/*

# Copy the installed Conda environment from the builder stage
COPY --from=builder /opt/conda/envs/viso_env /opt/conda/envs/viso_env

# Copy KasmVNC installation from builder stage
# Adjust paths as necessary based on where KasmVNC installs files
COPY --from=builder /usr/bin/kasmvnc* /usr/bin/
COPY --from=builder /usr/lib/kasmvnc /usr/lib/kasmvnc
COPY --from=builder /usr/share/kasmvnc /usr/share/kasmvnc
COPY --from=builder /etc/kasmvnc /etc/kasmvnc
# Add other necessary KasmVNC files/dirs if needed

# Set PATH to include Conda environment
# Make sure this PATH includes standard system paths as well
ENV PATH /opt/conda/envs/viso_env/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Copy application code from the build context
COPY ./VisoMaster /app/VisoMaster

# Copy configuration files from the build context
COPY ./s-alt/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./s-alt/Caddyfile /etc/caddy/Caddyfile
# --- MODIFIED: Removed trailing comment ---
COPY ./s-alt/index.html /app/VisoMaster/app/ui/web/templates/index.html

# Copy the startup script and make it executable
# Ensure download_and_start.sh is in the repository root
COPY download_and_start.sh /app/download_and_start.sh
RUN chmod +x /app/download_and_start.sh

# Expose ports
EXPOSE 6901 5000

# Set the entrypoint to the startup script
ENTRYPOINT ["/app/download_and_start.sh"]

# Set the default command (Supervisord)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf", "--nodaemon"]
