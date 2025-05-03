# PRIMARY Dockerfile (Builds the standard VNC image)
# Base image with CUDA 12.4.1 support suitable for Conda installation
FROM continuumio/miniconda3:latest AS builder

# --- Environment Setup ---
ARG PYTHON_VERSION=3.10.13
ARG CONDA_ENV_NAME=visomaster
ARG CUDA_VERSION_CONDA=12.4.1
ARG APP_DIR=/app
ARG VISOMASTER_CODE_DIR=${APP_DIR}/VisoMaster
ARG VISOMASTER_DEPS_DIR=${APP_DIR}/dependencies
ARG VISOMASTER_MODELS_DIR=${APP_DIR}/models

WORKDIR ${APP_DIR}

# Install essential tools, supervisor, and GUI components
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    supervisor \
    xvfb \
    fluxbox \
    x11vnc \
    wget \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Conda Environment Creation and Activation ---
RUN conda create -y -n ${CONDA_ENV_NAME} python=${PYTHON_VERSION} && \
    conda clean -a -y
SHELL ["conda", "run", "-n", "${CONDA_ENV_NAME}", "/bin/bash", "-c"]
RUN echo "Conda environment $CONDA_DEFAULT_ENV activated." && python --version

# --- Install CUDA Toolkit and cuDNN via Conda ---
RUN conda install -y -c nvidia/label/cuda-${CUDA_VERSION_CONDA} cuda-runtime && \
    conda install -y -c conda-forge cudnn && \
    conda clean -a -y

# --- Install Python Dependencies ---
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    --extra-index-url https://download.pytorch.org/whl/cu124 \
    --extra-index-url https://pypi.nvidia.com

# --- Copy Application Code, Dependencies, and Internal Guide ---
RUN mkdir -p ${VISOMASTER_CODE_DIR} ${VISOMASTER_DEPS_DIR} ${VISOMASTER_MODELS_DIR}
COPY dependencies/ ${VISOMASTER_DEPS_DIR}/
COPY VisoMaster/ ${VISOMASTER_CODE_DIR}/ # Assuming VisoMaster code is in a subfolder
COPY Install_Guide.ipynb ${VISOMASTER_CODE_DIR}/ # Simplified name

# Set the working directory to the application code directory
WORKDIR ${VISOMASTER_CODE_DIR}

# --- Download Models ---
RUN echo "Running model download script..." && \
    python download_models.py --output_dir ${VISOMASTER_MODELS_DIR} && \
    echo "Model download script finished."

# --- Runtime Configuration ---
EXPOSE 5901 # VNC port
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf # Simplified name
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
SHELL ["/bin/bash", "-c"]