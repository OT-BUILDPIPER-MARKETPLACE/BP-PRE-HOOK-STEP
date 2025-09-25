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
            logInfoMessage "Running: $cmd"
            eval "$cmd" || logErrorMessage "Command failed: $cmd (continuing...)"
        fi
    done
fi

TASK_STATUS=$?
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
