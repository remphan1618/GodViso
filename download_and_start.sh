#!/bin/bash
# Common Entrypoint Script (Runtime Downloads + Jupyter Compat)

APP_DIR="/app"
DEPS_DIR="${APP_DIR}/dependencies"
VISOMASTER_MODELS_DIR="${APP_DIR}/models"
LOGS_DIR="${APP_DIR}/logs" # Ensure logs dir is referenced if needed by script logic
MARKER_FILE="${VISOMASTER_MODELS_DIR}/.downloaded"

# --- IMPORTANT: Consider replacing these .exe downloads ---
# If standard Linux ffmpeg works, install it via apt-get in the Dockerfile instead.
FFMPEG_URL="https://github.com/visomaster/visomaster-assets/releases/download/v0.1.7_dp/ffmpeg.exe"
FFPLAY_URL="https://github.com/visomaster/visomaster-assets/releases/download/v0.1.7_dp/ffplay.exe"
FFMPEG_TARGET="${DEPS_DIR}/ffmpeg.exe"
FFPLAY_TARGET="${DEPS_DIR}/ffplay.exe"

echo "--- Entrypoint Script Started ---"

# --- Ensure Directories Exist ---
mkdir -p "${DEPS_DIR}" "${VISOMASTER_MODELS_DIR}" "${LOGS_DIR}"
echo "Ensured directories exist: ${DEPS_DIR}, ${VISOMASTER_MODELS_DIR}, ${LOGS_DIR}"

# --- Download FFmpeg if missing ---
if [ ! -f "${FFMPEG_TARGET}" ]; then
  echo "ffmpeg.exe not found in ${DEPS_DIR}. Downloading..."
  if command -v wget &> /dev/null; then
    # Use --no-verbose instead of -q to see progress/errors during download
    wget --no-verbose -O "${FFMPEG_TARGET}" "${FFMPEG_URL}"
    if [ $? -eq 0 ]; then
      echo "ffmpeg.exe downloaded successfully."
    else
      echo "ERROR: Failed to download ffmpeg.exe from ${FFMPEG_URL}. Exit code: $?" >&2
      # Consider exiting if ffmpeg is critical: exit 1
    fi
  else
    echo "ERROR: wget command not found. Cannot download ffmpeg.exe." >&2
    # Consider exiting: exit 1
  fi
else
  echo "ffmpeg.exe already exists. Skipping download."
fi

# --- Download FFplay if missing ---
if [ ! -f "${FFPLAY_TARGET}" ]; then
  echo "ffplay.exe not found in ${DEPS_DIR}. Downloading..."
  if command -v wget &> /dev/null; then
    wget --no-verbose -O "${FFPLAY_TARGET}" "${FFPLAY_URL}"
    if [ $? -eq 0 ]; then
      echo "ffplay.exe downloaded successfully."
    else
      echo "ERROR: Failed to download ffplay.exe from ${FFPLAY_URL}. Exit code: $?" >&2
      # Consider exiting if ffplay is critical: exit 1
    fi
  else
      echo "ERROR: wget command not found. Cannot download ffplay.exe." >&2
      # Consider exiting: exit 1
  fi
else
  echo "ffplay.exe already exists. Skipping download."
fi

# --- Change to Application Directory ---
# Ensure the target directory exists before trying to cd into it
if [ -d "/app/VisoMaster" ]; then
  cd /app/VisoMaster || exit 1 # Exit if cd fails even though dir exists (permission issue?)
  echo "Changed directory to /app/VisoMaster"
else
  echo "ERROR: Directory /app/VisoMaster does not exist. Cannot change directory." >&2
  exit 1
fi


# --- Download Models if missing ---
if [ ! -f "${MARKER_FILE}" ]; then
  echo "First run or models not found: Downloading models..."
  if [ -f "download_models.py" ]; then
      if command -v conda &> /dev/null; then
          echo "Running model download script using conda..."
          # Ensure the environment is activated correctly for the script
          # Using 'conda run' should handle activation
          conda run -n viso_env python download_models.py --output_dir "${VISOMASTER_MODELS_DIR}"
          DOWNLOAD_EXIT_CODE=$?
          if [ "${DOWNLOAD_EXIT_CODE}" -eq 0 ] && [ "$(ls -A ${VISOMASTER_MODELS_DIR} 2>/dev/null)" ]; then
              touch "${MARKER_FILE}"
              echo "Models downloaded successfully."
          else
              # Provide more specific error based on exit code or empty dir
              if [ "${DOWNLOAD_EXIT_CODE}" -ne 0 ]; then
                 echo "ERROR: Model download script failed with exit code ${DOWNLOAD_EXIT_CODE}. Check download_models.py script logs/output." >&2
              else
                 echo "ERROR: Model download script ran successfully (exit code 0), but output directory ${VISOMASTER_MODELS_DIR} is empty or inaccessible." >&2
              fi
              # Consider exiting if models are critical: exit 1
          fi
      else
          echo "ERROR: conda command not found. Cannot run model download script." >&2
          # Consider exiting: exit 1
      fi
  else
      echo "ERROR: download_models.py not found in $(pwd). Cannot download models." >&2
      # Consider exiting: exit 1
  fi
else
  echo "Models marker file found. Skipping download."
fi

# --- REMOVED: Starting Supervisord in the background ---
# The 'exec "$@"' line below will now start supervisord using the CMD from the Dockerfile

# --- Execute the command passed to the entrypoint ---
# This should be the CMD from the Dockerfile (e.g., supervisord)
echo "--- Entrypoint script finished. Executing command: $@ ---"
exec "$@"
