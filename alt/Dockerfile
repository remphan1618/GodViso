# ALT Dockerfile (Portal, Build-time Models)
FROM continuumio/miniconda3:latest AS builder

# --- Environment Setup ---
ARG PYTHON_VERSION=3.10.13
ARG CONDA_ENV_NAME=visomaster
ARG CUDA_VERSION_CONDA=12.4.1
ARG APP_DIR=/app
ARG VISOMASTER_CODE_DIR=${APP_DIR}/VisoMaster
ARG VISOMASTER_DEPS_DIR=${APP_DIR}/dependencies
ARG VISOMASTER_MODELS_DIR=${APP_DIR}/models
ARG CADDY_VERSION=2

WORKDIR ${APP_DIR}

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

# --- Copy Application Code, Dependencies, and Internal Guide ---
# Assumes user placed assets in local 'dependencies/' folder at repo root
RUN mkdir -p ${VISOMASTER_CODE_DIR} ${VISOMASTER_DEPS_DIR} ${VISOMASTER_MODELS_DIR}
# Copy from root context
COPY dependencies/ ${VISOMASTER_DEPS_DIR}/
COPY VisoMaster/ ${VISOMASTER_CODE_DIR}/
COPY Install_Guide.ipynb ${VISOMASTER_CODE_DIR}/

# Set workdir for model download
WORKDIR ${VISOMASTER_CODE_DIR}

# --- Download Models During Build ---
RUN echo "Running model download script during build..." && \
    conda run -n ${CONDA_ENV_NAME} python download_models.py --output_dir ${VISOMASTER_MODELS_DIR} && \
    echo "Model download script finished."


# --- Final Stage ---
FROM debian:bullseye-slim

ARG CONDA_ENV_NAME=visomaster
ARG APP_DIR=/app
ARG CADDY_VERSION=2

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    PATH=/opt/conda/envs/${CONDA_ENV_NAME}/bin:/opt/conda/bin:$PATH

# Install runtime dependencies including Caddy
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    xvfb \
    fluxbox \
    x11vnc \
    libgomp1 \
    libgl1 \
    ca-certificates \
    curl \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    # Install Caddy
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update \
    && apt-get install -y caddy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create Caddy directories
RUN mkdir -p /etc/caddy /var/log/portal

# Copy the Conda environment from the builder stage
COPY --from=builder /opt/conda/envs/${CONDA_ENV_NAME} /opt/conda/envs/${CONDA_ENV_NAME}

# Copy the application code, dependencies, models, and guide from the builder stage
COPY --from=builder ${APP_DIR} ${APP_DIR}

# Copy Caddy and supervisor configurations from alt/ folder in build context
COPY alt/Caddyfile /etc/caddy/Caddyfile
COPY alt/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR ${APP_DIR}/VisoMaster # Set final working directory

# --- Runtime Configuration ---
# Expose Caddy's internal port
EXPOSE 11111
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]