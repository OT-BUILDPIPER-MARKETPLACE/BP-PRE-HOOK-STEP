#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

# ---------------------------------------------------------------
# NOTE: ACTIVITY_SUB_TASK_CODE is managed by the BuildPiper
#       environment. Do NOT override it here to ensure events
#       appear correctly in the UI.
# ---------------------------------------------------------------

if [ "$DEBUG" = true ]; then
  set -x
fi

# ---------------------------------------------------------------
# 1. Action Selection
# ---------------------------------------------------------------
logInfoMessage "> Starting step: pre_hook"
logInfoMessage "> Resolving action: ${ACTION}"

case "$ACTION" in
  build)
    PRE_HOOK_CMD=$(getPreHookBuildCommand)
    logInfoMessage "> Selected action: build"
    add_event "ACTION_SELECTION" "Successful" \
      "Pre-hook action resolved: build" \
      "Action: ${ACTION}"
    ;;
  deploy)
    PRE_HOOK_CMD=$(getPreHookDeployCommand)
    logInfoMessage "> Selected action: deploy"
    add_event "ACTION_SELECTION" "Successful" \
      "Pre-hook action resolved: deploy" \
      "Action: ${ACTION}"
    ;;
  *)
    logErrorMessage "> Invalid or missing ACTION. Expected: {build|deploy} — got: '${ACTION}'"
    add_event "ACTION_SELECTION" "Failed" \
      "Invalid or missing action provided — expected: build | deploy" \
      "Action: '${ACTION}'"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
    ;;
esac

# ---------------------------------------------------------------
# 2. Command Validation
# ---------------------------------------------------------------
logInfoMessage "> Validating pre-hook command..."

if [ -z "$PRE_HOOK_CMD" ]; then
  logInfoMessage "> No PRE_HOOK command configured for action: ${ACTION} — skipping execution"
  add_event "COMMAND_VALIDATION" "Successful" \
    "No PRE_HOOK command configured — skipping execution" \
    "Action: ${ACTION}"
  saveTaskStatus 0 "${ACTIVITY_SUB_TASK_CODE}"
  exit 0
fi

MASKED_CMD="$PRE_HOOK_CMD"
MASKED_CMD=$(echo "$MASKED_CMD" | sed -E 's/(AWS|DB|TOKEN|PASSWORD|PASS|SECRET|KEY|CRED|AUTH|PRIVATE|FERNET|ACCESS|SESSION)=([^ ]+)/\1=****/Ig')
MASKED_CMD=$(echo "$MASKED_CMD" | sed -E 's/(export[[:space:]]+[^=]+=)[^ ]+/\1****/Ig')

logInfoMessage "> PRE_HOOK_CMD (masked): ${MASKED_CMD}"

add_event "COMMAND_VALIDATION" "Successful" \
  "PRE_HOOK command resolved and masked for secure logging" \
  "Action: ${ACTION} | Command (masked): ${MASKED_CMD}"

# ---------------------------------------------------------------
# 3. Workspace Navigation
# ---------------------------------------------------------------
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
logInfoMessage "> Navigating to codebase: ${CODEBASE_LOCATION}"

sleep "${SLEEP_DURATION}"

cd "${CODEBASE_LOCATION}" || {
  logErrorMessage "> Failed to navigate to codebase directory: ${CODEBASE_LOCATION}"
  add_event "WORKSPACE_NAVIGATION" "Failed" \
    "Failed to navigate to codebase directory" \
    "Path: ${CODEBASE_LOCATION} | Verify WORKSPACE and CODEBASE_DIR are set correctly"
  saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
  exit 1
}

logInfoMessage "> Successfully navigated to: ${CODEBASE_LOCATION}"
add_event "WORKSPACE_NAVIGATION" "Successful" \
  "Navigated to codebase directory" \
  "Path: ${CODEBASE_LOCATION}"

# ---------------------------------------------------------------
# 4. Command Execution
# ---------------------------------------------------------------
logInfoMessage "> Executing pre-hook commands..."

echo ""
echo "> Pre-Hook Execution Summary"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Parameter" "Value"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Action" "${ACTION}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Codebase Location" "${CODEBASE_LOCATION}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Command (masked)" "${MASKED_CMD:0:48}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
echo ""

echo "$PRE_HOOK_CMD" | while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue

  # Mask command for secure logging
  SAFE_LOG_CMD=$(echo "$cmd" | sed -E 's/(AWS|DB|TOKEN|PASSWORD|PASS|SECRET|KEY|CRED|AUTH|PRIVATE|FERNET|ACCESS|SESSION)=([^ ]+)/\1=****/Ig')
  SAFE_LOG_CMD=$(echo "$SAFE_LOG_CMD" | sed -E 's/(export[[:space:]]+[^=]+=)[^ ]+/\1****/Ig')

  logInfoMessage "> Running command (masked): ${SAFE_LOG_CMD}"

  IFS=';&' read -ra CMD_PARTS <<< "$cmd"

  for part in "${CMD_PARTS[@]}"; do
    clean_cmd=$(echo "$part" | xargs)
    [ -z "$clean_cmd" ] && continue

    if [[ "$clean_cmd" == "env" ]]; then
      logInfoMessage "> Executing env with sensitive variables masked"
      env | sed -E 's/(AWS|DB|TOKEN|PASSWORD|PASS|SECRET|KEY|CRED|AUTH|PRIVATE|FERNET|ACCESS|SESSION)=.*/\1=****/Ig'
      TASK_STATUS=$?
    else
      eval "$clean_cmd"
      TASK_STATUS=$?
    fi

    if [ "${TASK_STATUS}" -eq 0 ]; then
      logInfoMessage "> Sub-command completed successfully (exit: ${TASK_STATUS})"
      add_event "SUB_COMMAND_EXECUTION" "Successful" \
        "Sub-command executed successfully" \
        "Command (masked): ${SAFE_LOG_CMD} | Exit Code: ${TASK_STATUS}"
    else
      logErrorMessage "> Sub-command failed (exit: ${TASK_STATUS})"
      add_event "SUB_COMMAND_EXECUTION" "Failed" \
        "Sub-command failed — review command syntax or dependencies" \
        "Command (masked): ${SAFE_LOG_CMD} | Exit Code: ${TASK_STATUS}"
    fi
  done

  saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"

  if [ "${TASK_STATUS}" -eq 0 ]; then
    logInfoMessage "> Pre-hook completed successfully"
    add_event "PRE_HOOK_COMPLETE" "Successful" \
      "Pre-hook execution completed successfully" \
      "Action: ${ACTION} | Exit Code: ${TASK_STATUS}"
  else
    logErrorMessage "> Pre-hook execution failed — review failed command logs above"
    add_event "PRE_HOOK_COMPLETE" "Failed" \
      "Pre-hook execution failed — review failed command output above" \
      "Action: ${ACTION} | Exit Code: ${TASK_STATUS}"
  fi
done