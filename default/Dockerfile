# Default VisoMaster Setup with Jupyter and Caddy
# Base Image: Ubuntu 22.04
FROM ubuntu:22.04 AS base

LABEL maintainer="remphan1618"
LABEL description="VisoMaster with Jupyter, Caddy, Supervisord. Standard Setup."

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies, Miniconda prerequisites, Supervisord, wget, git, xvfb, and Caddy
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
COPY default/environment.yml /tmp/environment.yml
RUN conda env create -f /tmp/environment.yml && \
    conda clean -afy && \
    rm /tmp/environment.yml

# Activate Conda environment by default in shell
SHELL ["/bin/bash", "-c"]
RUN echo "conda activate visomaster" >> ~/.bashrc

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

# Copy configuration files and entrypoint script
# **MODIFIED LINE BELOW**
COPY download_and_start.sh /app/download_and_start.sh
COPY default/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY default/Caddyfile /etc/caddy/Caddyfile

# Make entrypoint script executable
RUN chmod +x /app/download_and_start.sh

# Expose ports (Caddy default HTTP/HTTPS, Jupyter, VisoMaster internal - adjust as needed)
# Caddy will handle reverse proxying based on Caddyfile
EXPOSE 8888
EXPOSE 8080
EXPOSE 11111

# Set the entrypoint to the common script
ENTRYPOINT ["/app/download_and_start.sh"]

# Default command (will be executed by entrypoint script)
# Start Jupyter Lab allowing connections from any origin and without a token
CMD ["conda", "run", "-n", "visomaster", "jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--NotebookApp.token=''", "--NotebookApp.password=''", "--allow-root", "--notebook-dir=/app"]