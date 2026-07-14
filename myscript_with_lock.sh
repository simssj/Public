#!/bin/bash

# This is AI-generated bash code that purports to provide a single-instance locking mechanism for bash scripts.

# --- Configuration ---
PIDFILE="/tmp/my_script.pid" # Define a unique path for your lock file
SCRIPT_NAME=$(basename "$0") # Gets the current script name

# 1. Cleanup function: Runs when the script exits (success or failure)
cleanup() {
    echo "Exiting and removing PID file: $PIDFILE"
    rm -f "$PIDFILE"
}
# Trap ensures that cleanup runs even if the script is interrupted (Ctrl+C)
trap cleanup EXIT

# 2. Check for existing instance
if [ -f "$PIDFILE" ]; then
    LAST_PID=$(cat "$PIDFILE")
    
    # The 'kill -0' command checks if a process exists without sending a signal, 
    # making it safe to use for checking status.
    if kill -0 "$LAST_PID" 2>/dev/null; then
        echo "---------------------------------------------------"
        echo "🚨 Script '$SCRIPT_NAME' is ALREADY RUNNING (PID: $LAST_PID)."
        echo "Please wait for it to complete, or manually stop it and run the script again."
        echo "---------------------------------------------------"
        exit 1 # Exit with an error code
    else
        # The PID file exists, but the process is not running (stale lock file)
        echo "⚠️ Detected stale PID file ($PIDFILE). Cleaning up..."
        rm -f "$PIDFILE"
    fi
fi

# 3. If we reach here, no instance was found or the lock file was cleaned up.
# Start tracking: Write our own Process ID to the file immediately.
echo $$ > "$PIDFILE"

echo "---------------------------------------------------"
echo "✅ Script is starting successfully."
echo "Running in background mode. PID saved to $PIDFILE"
echo "---------------------------------------------------"


# --- YOUR MAIN SCRIPT LOGIC GOES HERE ---
sleep 5 # Simulate some work being done (e.g., complex calculations, API calls)

echo "Script finished its main task."

# The 'trap cleanup EXIT' hook handles the removal of $PIDFILE automatically when the script reaches this point.
