#!/bin/sh

set -e
# set -x

SELF=`readlink -f "$0"`
BASEDIR=$( (cd -P "`dirname "$SELF"`" && pwd) )
RUN_MODE="xwayland" exec "${BASEDIR}/steamlink.sh" "$@"