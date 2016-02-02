#!/bin/bash

DIR=$(pushd $(dirname $BASH_SOURCE[0]) > /dev/null && pwd && popd > /dev/null )

BUGGY_GP=${DIR}/ganttproject_issue_523.tar.gz

BUGGY_GP_HOME=${DIR}/buggy_ganttproject/

if [ ! -d $BUGGY_GP_HOME ] ; then
    mkdir $BUGGY_GP_HOME > /dev/null
    tar zxvf $BUGGY_GP -C $BUGGY_GP_HOME
fi

[ -z $GP_HOME ] && echo "Using buggy GP_HOME at ${BUGGY_GP_HOME}" && GP_HOME=$BUGGY_GP_HOME
[ -z $GP_LOG_DIR ] && echo "Using $DIR as GP_LOG_DIR" && GP_LOG_DIR=$DIR

# Use large heap to avoid GC that may move exception objects and change their address.
GP_LOG_DIR=$GP_LOG_DIR GP_HOME=$GP_HOME JAVA=$JAVA VM_OPTS="$VM_OPTS  -Xmx1g -Xms1g"  ${DIR}/../run-gp.sh
