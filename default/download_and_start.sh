#!/bin/bash
# DEFAULT Entrypoint Script (VNC, Runtime Models + FFmpeg/FFplay Download)
# Modified for Jupyter compatibility

APP_DIR="/app"
DEPS_DIR="${APP_DIR}/dependencies"
VISOMASTER_MODELS_DIR="${APP_DIR}/models"
MARKER_FILE="${VISOMASTER_MODELS_DIR}/.downloaded"

FFMPEG_URL="https://github.com/visomaster/visomaster-assets/releases/download/v0.1.7_dp/ffmpeg.exe"
FFPLAY_URL="https://github.com/visomaster/visomaster-assets/releases/download/v0.1.7_dp/ffplay.exe"
FFMPEG_TARGET="${DEPS_DIR}/ffmpeg.exe"
FFPLAY_TARGET="${DEPS_DIR}/ffplay.exe"

echo "--- Entrypoint Script Started (Default - Runtime Downloads) ---"

# --- Ensure Dependencies Directory Exists ---
mkdir -p "${DEPS_DIR}"
echo "Ensured dependencies directory exists: ${DEPS_DIR}"

# --- Download FFmpeg if missing ---
if [ ! -f "${FFMPEG_TARGET}" ]; then
  echo "ffmpeg.exe not found in ${DEPS_DIR}. Downloading..."
  # Ensure wget is available (should be from Dockerfile)
  if command -v wget &> /dev/null; then
    wget -q -O "${FFMPEG_TARGET}" "${FFMPEG_URL}"
    if [ $? -eq 0 ]; then
      echo "ffmpeg.exe downloaded successfully."
      # Optional: Make executable if needed on Linux (though it's .exe?)
      # chmod +x "${FFMPEG_TARGET}"
    else
      echo "ERROR: Failed to download ffmpeg.exe from ${FFMPEG_URL}." >&2
      # rm -f "${FFMPEG_TARGET}" # Clean up partial download
      # exit 1 # Optional: Exit if critical
    fi
  else
    echo "ERROR: wget command not found. Cannot download ffmpeg.exe." >&2
    # exit 1 # Optional: Exit if critical
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
      # chmod +x "${FFPLAY_TARGET}" # Optional
    else
      echo "ERROR: Failed to download ffplay.exe from ${FFPLAY_URL}." >&2
      # rm -f "${FFPLAY_TARGET}" # Clean up partial download
      # exit 1 # Optional: Exit if critical
    fi
  else
      echo "ERROR: wget command not found. Cannot download ffplay.exe." >&2
      # exit 1 # Optional: Exit if critical
  fi
else
  echo "ffplay.exe already exists. Skipping download."
fi

# --- Change to Application Directory ---
cd /app/VisoMaster || exit 1 # Exit if cd fails

# --- Download Models if missing ---
if [ ! -f "${MARKER_FILE}" ]; then
  echo "First run or models not found: Downloading models..."
  mkdir -p "${VISOMASTER_MODELS_DIR}"

  if [ -f "download_models.py" ]; then
      # Ensure conda run is available and works
      if command -v conda &> /dev/null; then
          # Activate environment explicitly IF NEEDED (PATH should be set, but belt-and-suspenders)
          # source /opt/conda/etc/profile.d/conda.sh
          # conda activate visomaster
          # Run the download script
          conda run -n visomaster python download_models.py --output_dir "${VISOMASTER_MODELS_DIR}"
          DOWNLOAD_EXIT_CODE=$?
          # Deactivate if you activated
          # conda deactivate

          # Basic check if download created files/dirs before creating marker
          if [ "${DOWNLOAD_EXIT_CODE}" -eq 0 ] && [ "$(ls -A ${VISOMASTER_MODELS_DIR} 2>/dev/null)" ]; then
              touch "${MARKER_FILE}"
              echo "Models downloaded successfully."
          else
              echo "Model download script ran with exit code ${DOWNLOAD_EXIT_CODE}, but output directory seems empty or script failed. Check download_models.py script." >&2
              # exit 1 # Optional: Exit if download fails
          fi
      else
          echo "ERROR: conda command not found. Cannot run model download script." >&2
          # exit 1 # Optional: Exit if conda is missing
      fi
  else
      echo "ERROR: download_models.py not found in /app/VisoMaster. Cannot download models." >&2
      # exit 1 # Optional: Exit if script is missing
  fi
else
  echo "Models marker file found. Skipping download."
fi

# --- Start Supervisord in the background ---
echo "--- Starting supervisord in background ---"
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &
SUPERVISOR_PID=$!
echo "Supervisord started with PID ${SUPERVISOR_PID}."

# Wait a moment for services to potentially start (optional)
sleep 5

# --- Execute the command passed to the entrypoint ---
# This allows Vast.ai's Jupyter command (or the default CMD) to run
echo "--- Executing command: $@ ---"
exec "$@"

# Optional: Add cleanup if needed when the main command exits
# echo "Main command exited. Waiting for supervisord..."
# wait $SUPERVISOR_PID
# echo "Supervisord exited."