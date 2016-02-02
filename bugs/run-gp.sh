#!/bin/bash

DIR=$(pushd $(dirname $BASH_SOURCE[0]) > /dev/null && pwd && popd > /dev/null )

if [ ! -d $GP_HOME ]; then
    echo "GP_HOME is not set or not a valid directory."
    exit 1
fi

[ -z $GP_LOG_DIR ] && GP_LOG_DIR="$HOME/.ganttproject.d"
# Check if log dir is present (or create it)
if [ ! -d $GP_LOG_DIR ]; then
  if [ -e  $GP_LOG_DIR ]; then
    echo "file $GP_LOG_DIR exists and is not a directory" >&2
    exit 1
  fi
  if ! mkdir $GP_LOG_DIR ; then
    echo "Could not create $GP_LOG_DIR directory" >&2
    exit 1
  fi
fi

# Create unique name for log file
LOG_FILE="$GP_LOG_DIR/.ganttproject-"$(date +%Y%m%d%H%M%S)".log"
if [ -e "$LOG_FILE" ] && [ ! -w "$LOG_FILE" ]; then
  echo "Log file $LOG_FILE is not writable" >2
  exit 1
fi

# Find usable java executable
if [ -z "$JAVA" ]; then
    echo "Using default java at $(which java)"
    JAVA=$(which java)
fi

if [ ! -x "$JAVA" ]; then
  echo "$JAVA is not executable. Please check the permissions." >&2
  exit 1
fi

#default is
ECLIPSITO_CLASS_LOADER_PATCH=${DIR}/eclipsito-bundle-classloader.jar

LOCAL_CLASSPATH=${ECLIPSITO_CLASS_LOADER_PATCH}:${GP_HOME}/eclipsito.jar:${GP_HOME}
CONFIGURATION_FILE=ganttproject-eclipsito-config.xml
BOOT_CLASS=org.bardsoftware.eclipsito.Boot

LOG_OPTS="-log -log_file $LOG_FILE"

$JAVA -Xmx256m $VM_OPTS -classpath $CLASSPATH:$LOCAL_CLASSPATH $BOOT_CLASS $CONFIGURATION_FILE $LOG_OPTS "$@"
