# DEFAULT Dockerfile (VNC, Runtime Models) - REVISED FOR JUPYTER COMPATIBILITY & RUNTIME DOWNLOADS
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

# --- Install Python Dependencies AND ipykernel ---
# Copy from root context
COPY requirements.txt .
# Install ipykernel first
RUN conda run -n ${CONDA_ENV_NAME} conda install -y ipykernel && \
    conda run -n ${CONDA_ENV_NAME} pip install --no-cache-dir -r requirements.txt \
    --extra-index-url https://download.pytorch.org/whl/cu124 \
    --extra-index-url https://pypi.nvidia.com && \
    rm -rf ~/.cache/pip

# --- Register Conda Env as Jupyter Kernel ---
RUN conda run -n ${CONDA_ENV_NAME} python -m ipykernel install --user --name=${CONDA_ENV_NAME} --display-name="Python (${CONDA_ENV_NAME})"

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

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    PATH=/opt/conda/envs/${CONDA_ENV_NAME}/bin:/opt/conda/bin:$PATH \
    DEBIAN_FRONTEND=noninteractive \
    # Set SHELL to bash for Vast.ai compatibility if needed
    SHELL=/bin/bash

# Install runtime dependencies (including bash and wget for entrypoint)
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    xvfb \
    fluxbox \
    x11vnc \
    libgomp1 \
    libgl1 \
    ca-certificates \
    bash \
    wget \
    gnupg \
    perl-modules \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the Conda environment from the builder stage
COPY --from=builder /opt/conda/envs/${CONDA_ENV_NAME} /opt/conda/envs/${CONDA_ENV_NAME}
# Copy Jupyter kernel spec created by builder
COPY --from=builder /root/.local/share/jupyter/kernels/${CONDA_ENV_NAME} /usr/local/share/jupyter/kernels/${CONDA_ENV_NAME}


# Copy ONLY the application code and guide from the builder stage
COPY --from=builder ${APP_DIR}/VisoMaster ${APP_DIR}/VisoMaster
COPY --from=builder ${APP_DIR}/VisoMaster/Install_Guide.ipynb ${APP_DIR}/VisoMaster/

# Copy supervisor config and entrypoint script from default/ folder
COPY default/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY default/download_and_start.sh /app/download_and_start.sh
RUN chmod +x /app/download_and_start.sh

# Create models and dependencies directory structure (will be populated by entrypoint)
RUN mkdir -p /app/models /app/dependencies

WORKDIR ${APP_DIR}/VisoMaster # Set final working directory

# --- Runtime Configuration ---
# Expose VNC port
EXPOSE 5901

# ENTRYPOINT is the download script
ENTRYPOINT ["/app/download_and_start.sh"]

# Define a default CMD (Vast.ai will likely override this with its Jupyter command)
# This is what `exec "$@"` in the entrypoint will run if no other command is provided.
CMD ["bash"]