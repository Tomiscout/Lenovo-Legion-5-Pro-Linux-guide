#!/bin/sh

if pgrep -x "brave" > /dev/null; then
  killall -2 brave --wait
  if [ $? -ne 0 ]; then
    echo "Failed to kill the process"
    exit 1
  fi
else
    echo "Brave not running, nothing to kill"
    exit 0
fi
