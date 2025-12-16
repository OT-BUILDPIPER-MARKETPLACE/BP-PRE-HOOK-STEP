#!/bin/bash

# ------------------------------------------------------------------
# Source common BuildPiper functions
# ------------------------------------------------------------------
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

# ------------------------------------------------------------------
# Enable debug if required
# ------------------------------------------------------------------
if [ "$DEBUG" = true ]; then
  set -x
fi

# ------------------------------------------------------------------
# Resolve PRE_HOOK_CMD based on ACTION
# ------------------------------------------------------------------
case "$ACTION" in
  build)
    PRE_HOOK_CMD="$(getPreHookBuildCommand)"
    ;;
  deploy)
    PRE_HOOK_CMD="$(getPreHookDeployCommand)"
    ;;
  *)
    logErrorMessage "Invalid ACTION. Allowed values: build | deploy"
    exit 1
    ;;
esac

# ------------------------------------------------------------------
# Mask command ONLY for logging (never for execution)
# ------------------------------------------------------------------
MASKED_CMD="$(echo "$PRE_HOOK_CMD" | sed -E \
  -e 's/(AWS|DB|TOKEN|PASSWORD|SECRET|KEY)=([^[:space:]]+)/\1=****/g' \
  -e 's/(export[[:space:]]+[^=]+=)[^[:space:]]+/\1****/g'
)"

logInfoMessage "PRE_HOOK_CMD (masked): $MASKED_CMD"

# ------------------------------------------------------------------
# Move to codebase directory
# ------------------------------------------------------------------
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
logInfoMessage "I'll ${INSTRUCTION_TYPE:-process} the code available at [$CODEBASE_LOCATION]"
sleep "${SLEEP_DURATION:-0}"

cd "$CODEBASE_LOCATION" || {
  logErrorMessage "Failed to change directory to $CODEBASE_LOCATION"
  saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
  exit 1
}

# ------------------------------------------------------------------
# Block dangerous commands (SECURITY)
# ------------------------------------------------------------------
BLOCKED_CMDS_REGEX='^(env|printenv|set|declare|export|cat[[:space:]]+/proc/self/environ)$'

# ------------------------------------------------------------------
# Execute pre-hook commands
# ------------------------------------------------------------------
if [ -z "$PRE_HOOK_CMD" ]; then
  logInfoMessage "No pre-hook commands found. Skipping pre-hook execution."
  saveTaskStatus 0 "${ACTIVITY_SUB_TASK_CODE}"
  exit 0
fi

# Read commands line-by-line WITHOUT subshell
IFS=$'\n' read -rd '' -a CMD_LIST <<< "$PRE_HOOK_CMD"

for cmd in "${CMD_LIST[@]}"; do
  clean_cmd="$(echo "$cmd" | xargs)"
  [ -z "$clean_cmd" ] && continue

  # 🚫 Block unsafe commands
  if [[ "$clean_cmd" =~ $BLOCKED_CMDS_REGEX ]]; then
    logErrorMessage "Blocked unsafe pre-hook command: $clean_cmd"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
  fi

  # Mask for logging only
  SAFE_CMD="$(echo "$clean_cmd" | sed -E \
    -e 's/(AWS|DB|TOKEN|PASSWORD|SECRET|KEY)=([^[:space:]]+)/\1=****/g' \
    -e 's/(export[[:space:]]+[^=]+=)[^[:space:]]+/\1****/g'
  )"

  logInfoMessage "Running sanitized command: $SAFE_CMD"

  # Execute ORIGINAL command
  eval "$clean_cmd"
  TASK_STATUS=$?
done

# ------------------------------------------------------------------
# Success
# ------------------------------------------------------------------
saveTaskStatus $TASK_STATUS ${ACTIVITY_SUB_TASK_CODE}

