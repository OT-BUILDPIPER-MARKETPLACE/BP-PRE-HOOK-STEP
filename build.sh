#!/bin/bash

# Source common functions
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

# Enable Debugging if required
if [ "$DEBUG" = true ]; then
  set -x
fi

sleep  $SLEEP_DURATION

export BUILD_NUMBER=$(getBuildNumber)
export PRE_HOOK_CMD=$(getPreHookCommand)

#######################################################



pwd

ls

echo $PRE_HOOK_CMD 
echo $BUILD_NUMBER


echo "$PRE_HOOK_CMD" | while IFS= read -r cmd; do
  if [ -n "$cmd" ]; then
    echo "Running: $cmd"
    eval "$cmd" || echo " Command failed: $cmd (continuing...)"
  fi
done




