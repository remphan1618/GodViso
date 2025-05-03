#!/bin/bash
# Common Entrypoint Script (Runtime Downloads + Jupyter Compat)

APP_DIR="/app"
DEPS_DIR="${APP_DIR}/dependencies"
VISOMASTER_MODELS_DIR="${APP_DIR}/models"
LOGS_DIR="${APP_DIR}/logs" # Ensure logs dir is referenced if needed by script logic, though supervisord handles file creation
MARKER_FILE="${VISOMASTER_MODELS_DIR}/.downloaded"

FFMPEG_URL="https://github.com/visomaster/visomaster-assets/releases/download/v0.1.7_dp/ffmpeg.exe"
FFPLAY_URL="https://github.com/visomaster/visomaster-assets/releases/download/v0.1.7_dp/ffplay.exe"
FFMPEG_TARGET="${DEPS_DIR}/ffmpeg.exe"
FFPLAY_TARGET="${DEPS_DIR}/ffplay.exe"

echo "--- Entrypoint Script Started ---"

# --- Ensure Directories Exist ---
# Note: Dockerfile should create these, but double-check
mkdir -p "${DEPS_DIR}" "${VISOMASTER_MODELS_DIR}" "${LOGS_DIR}"
echo "Ensured directories exist: ${DEPS_DIR}, ${VISOMASTER_MODELS_DIR}, ${LOGS_DIR}"

# --- Download FFmpeg if missing ---
if [ ! -f "${FFMPEG_TARGET}" ]; then
  echo "ffmpeg.exe not found in ${DEPS_DIR}. Downloading..."
  if command -v wget &> /dev/null; then
    wget -q -O "${FFMPEG_TARGET}" "${FFMPEG_URL}"
    if [ $? -eq 0 ]; then
      echo "ffmpeg.exe downloaded successfully."
    else
      echo "ERROR: Failed to download ffmpeg.exe from ${FFMPEG_URL}." >&2
    fi
  else
    echo "ERROR: wget command not found. Cannot download ffmpeg.exe." >&2
  fi
else
  echo "ffmpeg.exe already exists. Skipping download."
fi

# --- Download FFplay if missing ---
if [ ! -f "${FFPLAY_TARGET}" ]; then
  echo "ffplay.exe not found in ${DEPS_DIR}. Downloading..."
  if command -v wget &> /dev/null; then
    wget -q -O "${FFPLAY_TARGET}" "${FFPLAY_URL}"
    if [ $? -eq 0 ]; then
      echo "ffplay.exe downloaded successfully."
    else
      echo "ERROR: Failed to download ffplay.exe from ${FFPLAY_URL}." >&2
    fi
  else
      echo "ERROR: wget command not found. Cannot download ffplay.exe." >&2
  fi
else
  echo "ffplay.exe already exists. Skipping download."
fi

# --- Change to Application Directory ---
cd /app/VisoMaster || exit 1 # Exit if cd fails

# --- Download Models if missing ---
if [ ! -f "${MARKER_FILE}" ]; then
  echo "First run or models not found: Downloading models..."
  if [ -f "download_models.py" ]; then
      if command -v conda &> /dev/null; then
          echo "Running model download script..."
          conda run -n visomaster python download_models.py --output_dir "${VISOMASTER_MODELS_DIR}"
          DOWNLOAD_EXIT_CODE=$?
          if [ "${DOWNLOAD_EXIT_CODE}" -eq 0 ] && [ "$(ls -A ${VISOMASTER_MODELS_DIR} 2>/dev/null)" ]; then
              touch "${MARKER_FILE}"
              echo "Models downloaded successfully."
          else
              echo "Model download script ran with exit code ${DOWNLOAD_EXIT_CODE}, or output directory is empty. Check download_models.py script." >&2
          fi
      else
          echo "ERROR: conda command not found. Cannot run model download script." >&2
      fi
  else
      echo "ERROR: download_models.py not found in /app/VisoMaster. Cannot download models." >&2
  fi
else
  echo "Models marker file found. Skipping download."
fi

# --- Start Supervisord in the background ---
echo "--- Starting supervisord in background ---"
# Ensure supervisord config exists before trying to start it
if [ -f /etc/supervisor/conf.d/supervisord.conf ]; then
  /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &
  SUPERVISOR_PID=$!
  echo "Supervisord started with PID ${SUPERVISOR_PID}."
  # Wait a moment for services (optional)
  sleep 5
else
  echo "ERROR: /etc/supervisor/conf.d/supervisord.conf not found. Cannot start supervisord." >&2
  # Decide if we should exit or continue to exec "$@"
fi


# --- Execute the command passed to the entrypoint ---
echo "--- Executing command: $@ ---"
exec "$@"