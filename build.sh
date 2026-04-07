#!/bin/bash

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
    logInfoMessage "Selected action: $ACTION"
    add_event "PRE HOOK ACTION" "Successful" \
      "Action selected: build" \
      "Action: ${ACTION}"
    ;;
  deploy)
    PRE_HOOK_CMD=$(getPreHookDeployCommand)
    logInfoMessage "Selected action: $ACTION"
    add_event "PRE HOOK ACTION" "Successful" \
      "Action selected: deploy" \
      "Action: ${ACTION}"
    ;;
  *)
    logInfoMessage "Usage: ACTION must be {build|deploy}"
    add_event "PRE HOOK ACTION" "Failed" \
      "Invalid or missing action provided" \
      "Action: ${ACTION}"
    exit 1
    ;;
esac

if [ -z "$PRE_HOOK_CMD" ]; then
  logInfoMessage "No PRE_HOOKS found"
  add_event "PRE HOOK COMMAND CHECK" "Successful" \
    "No PRE_HOOK command found, skipping execution" \
    "Action: ${ACTION}"
  exit 0
fi

MASKED_CMD="$PRE_HOOK_CMD"
MASKED_CMD=$(echo "$MASKED_CMD" | sed -E 's/(AWS|DB|TOKEN|PASSWORD|PASS|SECRET|KEY|CRED|AUTH|PRIVATE|FERNET|ACCESS|SESSION)=([^ ]+)/\1=****/Ig')
MASKED_CMD=$(echo "$MASKED_CMD" | sed -E 's/(export[[:space:]]+[^=]+=)[^ ]+/\1****/Ig')

logInfoMessage "PRE_HOOK_CMD is: $MASKED_CMD"

add_event "PRE HOOK COMMAND CHECK" "Successful" \
  "PRE_HOOK command resolved and masked for logging" \
  "Command (masked): ${MASKED_CMD}"

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
logInfoMessage "I'll ${INSTRUCTION_TYPE} the code available at [$CODEBASE_LOCATION]"
sleep "${SLEEP_DURATION}"

cd "${CODEBASE_LOCATION}" || {
  logErrorMessage "Failed to change directory to $CODEBASE_LOCATION"
  add_event "PRE HOOK DIRECTORY CHANGE" "Failed" \
    "Failed to navigate to codebase directory" \
    "Target Directory: ${CODEBASE_LOCATION}"
  exit 1
}

add_event "PRE HOOK DIRECTORY CHANGE" "Successful" \
  "Successfully navigated to codebase directory" \
  "Target Directory: ${CODEBASE_LOCATION}"

echo "$PRE_HOOK_CMD" | while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue

  # Mask command for logging
  SAFE_LOG_CMD=$(echo "$cmd" | sed -E 's/(AWS|DB|TOKEN|PASSWORD|PASS|SECRET|KEY|CRED|AUTH|PRIVATE|FERNET|ACCESS|SESSION)=([^ ]+)/\1=****/Ig')
  SAFE_LOG_CMD=$(echo "$SAFE_LOG_CMD" | sed -E 's/(export[[:space:]]+[^=]+=)[^ ]+/\1****/Ig')

  logInfoMessage "Running sanitized command: $SAFE_LOG_CMD"

  add_event "PRE HOOK COMMAND EXECUTION START" "Successful" \
    "Initiating command execution" \
    "Command (masked): ${SAFE_LOG_CMD}"

  IFS=';&' read -ra CMD_PARTS <<< "$cmd"

  for part in "${CMD_PARTS[@]}"; do
    clean_cmd=$(echo "$part" | xargs)
    [ -z "$clean_cmd" ] && continue


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

    if [ "${TASK_STATUS}" -eq 0 ]; then
      add_event "PRE HOOK SUB-COMMAND RESULT" "Successful" \
        "Sub-command executed successfully" \
        "Exit Code: ${TASK_STATUS}"
    else
      add_event "PRE HOOK SUB-COMMAND RESULT" "Failed" \
        "Sub-command execution failed" \
        "Exit Code: ${TASK_STATUS}"
    fi
  done

  saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"

  if [ "${TASK_STATUS}" -eq 0 ]; then
    add_event "PRE HOOK TASK STATUS" "Successful" \
      "Task status saved successfully" \
      "Sub Task Code: ${ACTIVITY_SUB_TASK_CODE} | Exit Code: ${TASK_STATUS}"
  else
    add_event "PRE HOOK TASK STATUS" "Failed" \
      "Task completed with non-zero exit status" \
      "Sub Task Code: ${ACTIVITY_SUB_TASK_CODE} | Exit Code: ${TASK_STATUS}"
  fi
done