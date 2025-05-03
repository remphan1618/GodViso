#!/bin/bash
echo "--- Default Start Script ---"

# Start supervisord in the background
echo "Starting supervisord..."
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &
SUPERVISOR_PID=$!
echo "Supervisord started with PID ${SUPERVISOR_PID}."

# Wait a moment for services to potentially start (optional)
sleep 5

echo "Executing command: $@"
# Execute the command passed to the entrypoint (e.g., Vast.ai's Jupyter command)
exec "$@"

# Optional: Add cleanup if needed when the main command exits
# wait $SUPERVISOR_PID