#!/bin/bash

# Example Provisioning Script for Vast.ai
# To be used with the PROVISIONING_SCRIPT environment variable.
# Downloads models after the container starts, intended as an alternative
# to baking models into the Docker image.

echo "--- Starting Provisioning Script ---"

# Define target directory for models (should match application expectation)
# Using /workspace/models ensures persistence if the instance is stopped/started,
# otherwise use /app/models if persistence isn't needed or handled differently.
MODELS_DIR="/workspace/models" # Recommended: Use persistent storage
# MODELS_DIR="/app/models" # Alternative: Non-persistent storage within container
APP_DIR="/app/VisoMaster" # Assuming app code is here

# Ensure the target directory exists
mkdir -p "${MODELS_DIR}"
echo "Ensuring model directory exists: ${MODELS_DIR}"

# Activate conda environment if needed for the download script
# Using `conda run` is generally safer in scripts.
echo "Activating Conda environment 'visomaster' for download script..."
CONDA_RUN="conda run --no-capture-output -n visomaster"

echo "Checking if download script exists at ${APP_DIR}/download_models.py..."
if [ -f "${APP_DIR}/download_models.py" ]; then
  echo "Running model download script via Conda..."
  # Execute the download script.
  # Ensure the download script handles existing files gracefully (e.g., doesn't re-download if files exist)
  # Pass the target directory to the script.
  ${CONDA_RUN} python "${APP_DIR}/download_models.py" --output_dir "${MODELS_DIR}"

  # Check exit code of the download script
  if [ $? -eq 0 ]; then
    echo "Model download script finished successfully."
  else
    echo "ERROR: Model download script failed. Check script output above for details." >&2
    # Optionally exit with an error code if model download is critical
    # exit 1
  fi
else
  echo "ERROR: Download script ${APP_DIR}/download_models.py not found!" >&2
  # Optionally exit with an error code if script is missing
  # exit 1
fi

echo "--- Provisioning Script Finished ---"

# The main container command (supervisord) will run after this script exits successfully (exit code 0).
exit 0