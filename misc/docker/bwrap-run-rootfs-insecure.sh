#!/bin/sh

SELF=`readlink -f "$0"`
BASEDIR=$( (cd -P "`dirname "$SELF"`" && pwd) )

ROOTFS="$1"

if [ ! -x "$BASEDIR/bwrap" ]; then
    exit 1
fi

if [ "$ROOTFS" = "" ]; then
    exit 1
fi

if [ ! -d "$ROOTFS" ]; then
    exit 1
fi

shift
CMD="$1"

if [ "$CMD" = "" ]; then
    CMD=$SHELL
else 
    shift
fi

[ -h "$ROOTFS"/var/run ] && rm "$ROOTFS"/var/run

exec "$BASEDIR"/bwrap \
    --bind "$ROOTFS" / \
    --dev-bind /dev /dev \
    --bind /sys /sys \
    --bind /tmp /tmp \
    --proc /proc \
    --dir /run/ --bind /run/ /run/ \
    --dir /var/run/ --bind /var/run/ /var/run/ \
    --ro-bind /var/lib/dbus/machine-id /var/lib/dbus/machine-id \
    --ro-bind /lib/modules /lib/modules \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind /etc/hostname /etc/hostname \
    --ro-bind /etc/hosts /etc/hosts \
    --ro-bind /boot /boot \
    --ro-bind / /.host/ \
    --bind /userdata/roms /userdata/roms \
    --bind /userdata/bios /userdata/bios \
    --setenv HOME /root \
    $CMD "$@"
