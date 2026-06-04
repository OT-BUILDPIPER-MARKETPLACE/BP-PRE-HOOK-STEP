#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

if [ "$DEBUG" = true ]; then
  set -x
fi

validate_command() {
  local cmd="$1"

  BLOCKED_PATTERNS=(
    "rm[[:space:]]+-rf"
    "rm[[:space:]]+-fr"
    "kubectl[[:space:]]+delete"
    "kubectl[[:space:]]+drain"
    "kubectl[[:space:]]+cordon"
    "kubectl[[:space:]]+uncordon"
    "sudo"
    "^su([[:space:]]|$)"
    "shutdown"
    "reboot"
    "halt"
    "poweroff"
    "mkfs"
    "fdisk"
    "parted"
    "wipefs"
    "dd[[:space:]]+"
    "userdel"
    "groupdel"
    "killall"
    "pkill"
    "kill[[:space:]]+-9"
    "systemctl[[:space:]]+stop"
    "systemctl[[:space:]]+disable"
    "docker[[:space:]]+system[[:space:]]+prune"
    "docker[[:space:]]+container[[:space:]]+prune"
    "docker[[:space:]]+volume[[:space:]]+prune"
    "eval[[:space:]]+"
    "bash[[:space:]]+-c"
    "sh[[:space:]]+-c"
    "curl.*\\|.*sh"
    "wget.*\\|.*sh"
  )

  for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if echo "$cmd" | grep -Eiq "$pattern"; then
      logWarningMessage "Restricted command detected and skipped: $cmd"
      return 1
    fi
  done

  return 0
}

case "$ACTION" in
  build)
    PRE_HOOK_CMD=$(getPreHookBuildCommand)
    ;;
  deploy)
    PRE_HOOK_CMD=$(getPreHookDeployCommand)
    ;;
  *)
    logInfoMessage "Usage: ACTION must be {build|deploy}"
    exit 1
    ;;
esac

MASKED_CMD="$PRE_HOOK_CMD"
MASKED_CMD=$(echo "$MASKED_CMD" | sed -E 's/(AWS|DB|TOKEN|PASSWORD|PASS|SECRET|KEY|CRED|AUTH|PRIVATE|FERNET|ACCESS|SESSION)=([^ ]+)/\1=****/Ig')
MASKED_CMD=$(echo "$MASKED_CMD" | sed -E 's/(export[[:space:]]+[^=]+=)[^ ]+/\1****/Ig')

logInfoMessage "PRE_HOOK_CMD is: $MASKED_CMD"

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

logInfoMessage "I'll ${INSTRUCTION_TYPE} the code available at [$CODEBASE_LOCATION]"

sleep "${SLEEP_DURATION}"

cd "${CODEBASE_LOCATION}" || {
  logErrorMessage "Failed to change directory to $CODEBASE_LOCATION"
  exit 1
}

while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue

  SAFE_LOG_CMD=$(echo "$cmd" | sed -E 's/(AWS|DB|TOKEN|PASSWORD|PASS|SECRET|KEY|CRED|AUTH|PRIVATE|FERNET|ACCESS|SESSION)=([^ ]+)/\1=****/Ig')
  SAFE_LOG_CMD=$(echo "$SAFE_LOG_CMD" | sed -E 's/(export[[:space:]]+[^=]+=)[^ ]+/\1****/Ig')

  logInfoMessage "Running sanitized command: $SAFE_LOG_CMD"

  IFS=';' read -ra CMD_PARTS <<< "$cmd"

  for part in "${CMD_PARTS[@]}"; do

    clean_cmd="$(echo "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    [ -z "$clean_cmd" ] && continue

if ! validate_command "$clean_cmd"; then
  logWarningMessage "Restricted command detected. Skipping execution: $clean_cmd"
  SKIPPED_COMMANDS=$((SKIPPED_COMMANDS + 1))
  continue
fi

    if [[ "$clean_cmd" == "env" ]]; then
      logInfoMessage "Executing env with sensitive variables masked"

      env | sed -E '
        s/(AWS|DB|TOKEN|PASSWORD|PASS|SECRET|KEY|CRED|AUTH|PRIVATE|FERNET|ACCESS|SESSION)=.*/\1=****/Ig
      '

      TASK_STATUS=$?
    else
      eval "$clean_cmd"
      TASK_STATUS=$?
    fi

    if [ "$TASK_STATUS" -ne 0 ]; then
      logErrorMessage "Command failed with exit code: $TASK_STATUS"
      saveTaskStatus "$TASK_STATUS" "${ACTIVITY_SUB_TASK_CODE}"
      exit "$TASK_STATUS"
    fi

  done

done <<< "$PRE_HOOK_CMD"

if [ "$SKIPPED_COMMANDS" -gt 0 ]; then
  logWarningMessage "$SKIPPED_COMMANDS restricted command(s) were skipped during execution."
fi

saveTaskStatus "0" "${ACTIVITY_SUB_TASK_CODE}"
exit 0