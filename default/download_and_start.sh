#!/bin/bash
# DEFAULT Entrypoint Script (VNC, Runtime Models)

APP_DIR="/app"
MODELS_DIR="${APP_DIR}/models"
MARKER_FILE="${MODELS_DIR}/.downloaded"

echo "--- Entrypoint Script Started ---"

# --- Change to Application Directory ---
cd /app/VisoMaster || exit 1 # Exit if cd fails

# --- Download Models if missing ---
if [ ! -f "${MARKER_FILE}" ]; then
  echo "First run or models not found: Downloading models..."
  mkdir -p "${MODELS_DIR}"

  if [ -f "download_models.py" ]; then
      # Ensure conda run is available and works
      if command -v conda &> /dev/null; then
          conda run -n visomaster python download_models.py --output_dir "${MODELS_DIR}"
          # Basic check if download created files/dirs before creating marker
          if [ "$(ls -A ${MODELS_DIR} 2>/dev/null)" ]; then
              touch "${MARKER_FILE}"
              echo "Models downloaded successfully."
          else
              echo "Model download script ran, but output directory seems empty. Check download_models.py script." >&2
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

# --- Start Supervisord ---
# Execute supervisord as the final step, replacing this script process
echo "--- Starting supervisord ---"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf