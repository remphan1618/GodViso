#!/bin/bash
# SMALL ALT Entrypoint Script (Portal, Runtime Models + FFmpeg/FFplay Download)
# Identical to s-def/download_and_start.sh

APP_DIR="/app"
DEPS_DIR="${APP_DIR}/dependencies"
VISOMASTER_MODELS_DIR="${APP_DIR}/models"
MARKER_FILE="${VISOMASTER_MODELS_DIR}/.downloaded"

FFMPEG_URL="https://github.com/visomaster/visomaster-assets/releases/download/v0.1.7_dp/ffmpeg.exe"
FFPLAY_URL="https://github.com/visomaster/visomaster-assets/releases/download/v0.1.7_dp/ffplay.exe"
FFMPEG_TARGET="${DEPS_DIR}/ffmpeg.exe"
FFPLAY_TARGET="${DEPS_DIR}/ffplay.exe"

echo "--- Entrypoint Script Started ---"

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
          conda run -n visomaster python download_models.py --output_dir "${VISOMASTER_MODELS_DIR}"
          # Basic check if download created files/dirs before creating marker
          if [ "$(ls -A ${VISOMASTER_MODELS_DIR} 2>/dev/null)" ]; then
              touch "${MARKER_FILE}"
              echo "Models downloaded successfully."
          else
              echo "Model download script ran, but output directory seems empty. Check download_models.py script." >&2
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

# --- Start Supervisord ---
# Execute supervisord as the final step, replacing this script process
echo "--- Starting supervisord ---"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf