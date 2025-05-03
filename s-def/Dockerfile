# SMALL DEFAULT Dockerfile (Now uses Portal, Runtime Models + Assets)
FROM continuumio/miniconda3:latest AS builder

# --- Environment Setup ---
ARG PYTHON_VERSION=3.10.13
ARG CONDA_ENV_NAME=visomaster
ARG CUDA_VERSION_CONDA=12.4.1
ARG APP_DIR=/app
ARG VISOMASTER_CODE_DIR=${APP_DIR}/VisoMaster
# NOTE: VISOMASTER_DEPS_DIR and VISOMASTER_MODELS_DIR are not used for copying in this build

WORKDIR ${APP_DIR}

# Set noninteractive to avoid debconf prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install essential build tools
RUN apt-get update && apt-get install -y --no-install-recommends wget curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Conda Environment Creation ---
RUN conda create -y -n ${CONDA_ENV_NAME} python=${PYTHON_VERSION} && \
    conda clean -a -y

# --- Verify Environment and Python Version ---
RUN conda run -n ${CONDA_ENV_NAME} echo "Verifying Conda environment ${CONDA_ENV_NAME}..." && \
    conda run -n ${CONDA_ENV_NAME} python --version

# --- Install CUDA Toolkit and cuDNN via Conda ---
RUN conda run -n ${CONDA_ENV_NAME} conda install -y -c nvidia/label/cuda-${CUDA_VERSION_CONDA} cuda-runtime && \
    conda run -n ${CONDA_ENV_NAME} conda install -y -c conda-forge cudnn && \
    conda run -n ${CONDA_ENV_NAME} conda clean -afy && \
    rm -rf /root/.conda ~/.cache

# --- Install Python Dependencies ---
# Copy from root context
COPY requirements.txt .
RUN conda run -n ${CONDA_ENV_NAME} pip install --no-cache-dir -r requirements.txt \
    --extra-index-url https://download.pytorch.org/whl/cu124 \
    --extra-index-url https://pypi.nvidia.com && \
    rm -rf ~/.cache/pip

# --- Copy ONLY Application Code and Internal Guide ---
# Do NOT copy dependencies/ or models/ from local repo
RUN mkdir -p ${VISOMASTER_CODE_DIR}
# Copy from root context
COPY VisoMaster/ ${VISOMASTER_CODE_DIR}/
COPY Install_Guide.ipynb ${VISOMASTER_CODE_DIR}/


# --- Final Stage ---
FROM debian:bullseye-slim

ARG CONDA_ENV_NAME=visomaster
ARG APP_DIR=/app
ARG CADDY_VERSION=2 # Added Caddy version arg

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    PATH=/opt/conda/envs/${CONDA_ENV_NAME}/bin:/opt/conda/bin:$PATH \
    DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies including Caddy, bash, and wget
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    xvfb \
    fluxbox \
    x11vnc \
    libgomp1 \
    libgl1 \
    ca-certificates \
    curl \
    gnupg \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    bash \
    wget \
    perl-modules \
    # Install Caddy
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update \
    && apt-get install -y caddy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create Caddy/Portal directories
RUN mkdir -p /etc/caddy /var/log/portal

# Copy the Conda environment from the builder stage
COPY --from=builder /opt/conda/envs/${CONDA_ENV_NAME} /opt/conda/envs/${CONDA_ENV_NAME}

# Copy ONLY the application code and guide from the builder stage
# *** DO NOT COPY /app/dependencies or /app/models from builder ***
COPY --from=builder ${APP_DIR}/VisoMaster ${APP_DIR}/VisoMaster
# Ensure Install_Guide.ipynb is copied if it was placed in VisoMaster in builder
COPY --from=builder ${APP_DIR}/VisoMaster/Install_Guide.ipynb ${APP_DIR}/VisoMaster/

# Copy Caddyfile, supervisor config, and entrypoint script from s-def/ folder
COPY s-def/Caddyfile /etc/caddy/Caddyfile # Added Caddyfile copy
COPY s-def/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY s-def/download_and_start.sh /app/download_and_start.sh
RUN chmod +x /app/download_and_start.sh

# Create models and dependencies directory structure (will be populated by entrypoint)
RUN mkdir -p /app/models /app/dependencies

WORKDIR ${APP_DIR}/VisoMaster # Set final working directory

# --- Runtime Configuration ---
# Expose Caddy's internal port instead of VNC port
EXPOSE 11111
ENTRYPOINT ["/app/download_and_start.sh"]