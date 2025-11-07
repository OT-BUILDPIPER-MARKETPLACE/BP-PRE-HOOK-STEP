#!/bin/bash

# Source common functions
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh


if [ "$DEBUG" = true ]; then
  set -x
fi

case "$ACTION" in
  build)
    PRE_HOOK_CMD=$(getPreHookBuildCommand)
    ;;
  deploy)
    PRE_HOOK_CMD=$(getPreHookDeployCommand)
    ;;
  *)
    logInfoMessage "Usage: {build|deploy}"
    ;;
esac

# ------------------------------------------------------------------
# SECURITY FIX: Avoid printing raw pre-hook commands that might
# contain sensitive env vars like passwords or tokens.
# ------------------------------------------------------------------
MASKED_CMD="$PRE_HOOK_CMD"
MASKED_CMD=$(echo "$MASKED_CMD" | sed -E 's/(AWS|DB|TOKEN|PASSWORD|SECRET|KEY)=([^ ]+)/\1=****/g')
MASKED_CMD=$(echo "$MASKED_CMD" | sed -E 's/(export[[:space:]]+[^=]+=)[^ ]+/\1****/g')

logInfoMessage "PRE_HOOK_CMD is: $PRE_HOOK_CMD"

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll $INSTRUCTION_TYPE the code available at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

cd "${CODEBASE_LOCATION}" || { logErrorMessage "Failed to change directory to $CODEBASE_LOCATION"; exit 1; }

#######################################################

if [ -z "$PRE_HOOK_CMD" ]; then
  logInfoMessage "No pre-hook commands found."
else
  echo "$PRE_HOOK_CMD" | while IFS= read -r cmd; do
    if [ -n "$cmd" ]; then
      # Mask command for logging
      SAFE_CMD=$(echo "$cmd" | sed -E 's/(AWS|DB|TOKEN|PASSWORD|SECRET|KEY)=([^ ]+)/\1=****/g')
      SAFE_CMD=$(echo "$SAFE_CMD" | sed -E 's/(export[[:space:]]+[^=]+=)[^ ]+/\1****/g')
      logInfoMessage "Running sanitized command: $SAFE_CMD"
      set +x  
      eval "$cmd"
      TASK_STATUS=$?
      if [ "$DEBUG" = true ]; then set -x; fi

      if [ "$STATUS" -ne 0 ]; then
          logErrorMessage "Command failed: $SAFE_CMD"
          saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
      fi
    fi
  done
fi
