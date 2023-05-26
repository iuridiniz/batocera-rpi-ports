#!/bin/sh

set -e
# set -x

SELF=`readlink -f "$0"`
BASEDIR=$( (cd -P "`dirname "$SELF"`" && pwd) )

#### PRE-DEFINED VARIABLES ####

DOCKER_IMAGE_STEAMLINK="iuridiniz/arm32v7-steamlink:stretch"
DOCKER_IMAGE_BWRAP="iuridiniz/arm64v8-bubblewrap:mantic"
DOCKER_IMAGE_XWAYLAND="iuridiniz/arm64v8-xwayland:mantic"
URL_DOCKER_IMAGE_FETCH="https://raw.githubusercontent.com/moby/moby/v24.0.1/contrib/download-frozen-image-v2.sh"
PORTSDIR="/userdata/roms/ports"
WORKDIR="${PORTSDIR}/.data/steamlink"
EXPECTED_SELF="${PORTSDIR}/steamlink.sh"
BINARYDIR="${WORKDIR}/bin"
TMPDIR="${WORKDIR}/temp"
STEAMLINK_ROOTFS="${WORKDIR}/steamlink-rootfs"
STEAMLINK_BINARY="${STEAMLINK_ROOTFS}/usr/bin/steamlink"
XWAYLAND_ROOTFS="${WORKDIR}/xwayland-rootfs"
XWAYLAND_BINARY="${XWAYLAND_ROOTFS}/usr/bin/Xwayland"
BWRAP_BINARY="${BINARYDIR}/bwrap"
DOCKER_IMAGE_FETCH_BINARY="${BINARYDIR}/docker-download-image"
MINIMAL_SPACE_REQUIRED=$(( 1024 * 1024 * 1024 * 2 )) # 2GB

# Try to detect if we are running in batocera (emulationstation) or not
RUN_MODE=${RUN_MODE:-""}
if [ -z "${RUN_MODE}" ]; then 
    if [ -n "${SDL_GAMECONTROLLERCONFIG}" -o -n "${SDL_RENDER_VSYNC}" ]; then
        RUN_MODE=batocera
    else
        RUN_MODE=other
    fi
else
    RUN_MODE=other
fi
SKIP_DOWNLOADS=${SKIP_DOWNLOADS:-""}

#### FUNCTIONS ####

skip_downloads() {
    if [ "${SKIP_DOWNLOADS}" = "1" ]; then
        return 0
    fi
    return 1
}

do_check_minimal_space_required() {
    if skip_downloads; then
        return
    fi

    echo -n "Checking minimal space required..."
    available_space=$(($(stat -f --format="%a*%S" "${WORKDIR}")))
    if [ "${available_space}" -lt "${MINIMAL_SPACE_REQUIRED}" ]; then
        echo "Error: not enough space available in ${WORKDIR} (${available_space} < ${MINIMAL_SPACE_REQUIRED})"
        exit 1
    fi
    echo "done"
}

do_download_docker_image_fetch() {
    if skip_downloads; then
        return
    fi

    [ -x "${DOCKER_IMAGE_FETCH_BINARY}" ] && return

    echo -n "Downloading ${DOCKER_IMAGE_FETCH_BINARY}..."
    mkdir -p "$(dirname "${DOCKER_IMAGE_FETCH_BINARY}")"
    curl -sSL "${URL_DOCKER_IMAGE_FETCH}" -o "${DOCKER_IMAGE_FETCH_BINARY}"
    chmod +x "${DOCKER_IMAGE_FETCH_BINARY}"
    hash -r
    echo "done"
}

do_download_bwrap() {
    if skip_downloads; then
        return
    fi

    [ -x "${BWRAP_BINARY}" ] && return

    # download requisites
    do_download_docker_image_fetch

    echo -n "Downloading docker image: ${DOCKER_IMAGE_BWRAP}..."
    tempdir=$(mktemp -d)
    "${DOCKER_IMAGE_FETCH_BINARY}" "${tempdir}" "${DOCKER_IMAGE_BWRAP}"

    # find layer.tar, if more than one exit with error
    layer_tar=$(find "${tempdir}" -name layer.tar)
    if [ $(echo "${layer_tar}" | wc -l) -ne 1 ]; then
        echo "Error: more than one layer.tar found"
        exit 1
    fi
    echo "done"

    echo -n "Installing ${BWRAP_BINARY}..."
    tar -xf "${layer_tar}" -C "${WORKDIR}"
    chown -R root:root "${WORKDIR}"
    [ ! -x "${BWRAP_BINARY}" ] && echo "Error: ${BWRAP_BINARY} does not exists" && exit 1
    echo "done"
}

do_download_xwayland() {
    if skip_downloads; then
        return
    fi

    [ -x "${XWAYLAND_BINARY}" ] && return

    # download requisites
    do_download_docker_image_fetch

    echo -n "Downloading docker image: ${DOCKER_IMAGE_XWAYLAND}..."
    tempdir=$(mktemp -d)
    "${DOCKER_IMAGE_FETCH_BINARY}" "${tempdir}" "${DOCKER_IMAGE_XWAYLAND}"

    # find layer.tar, if more than one exit with error
    layer_tar=$(find "${tempdir}" -name layer.tar)
    if [ $(echo "${layer_tar}" | wc -l) -ne 1 ]; then
        echo "Error: more than one layer.tar found"
        exit 1
    fi
    echo "done"

    echo -n "Installing ${XWAYLAND_BINARY} (and backup old one if it exists)..."
    # backup old rootfs
    [ -d "${XWAYLAND_ROOTFS}.old" ] && rm -rf "${XWAYLAND_ROOTFS}.old"
    [ -d "${XWAYLAND_ROOTFS}" ] && mv "${XWAYLAND_ROOTFS}" "${XWAYLAND_ROOTFS}.old"
    mkdir -p "${XWAYLAND_ROOTFS}"

    tar -xf "${layer_tar}" -C "${XWAYLAND_ROOTFS}"
    chown -R root:root "${XWAYLAND_ROOTFS}"
    [ ! -x "${XWAYLAND_BINARY}" ] && echo "Error: ${XWAYLAND_BINARY} does not exists" && exit 1
    echo "done"
}

do_download_steamlink() {
    if skip_downloads; then
        return
    fi

    [ -x "${STEAMLINK_BINARY}" ] && return

    # download requisites
    do_download_docker_image_fetch

    echo -n "Downloading docker image: ${DOCKER_IMAGE_STEAMLINK}..."
    tempdir=$(mktemp -d)
    "${DOCKER_IMAGE_FETCH_BINARY}" "${tempdir}" "${DOCKER_IMAGE_STEAMLINK}"

    # find layer.tar, if more than one exit with error
    layer_tar=$(find "${tempdir}" -name layer.tar)
    if [ $(echo "${layer_tar}" | wc -l) -ne 1 ]; then
        echo "Error: more than one layer.tar found"
        exit 1
    fi
    echo "done"

    echo -n "Installing ${STEAMLINK_BINARY} (and backup old one if it exists)..."

    # backup old rootfs
    [ -d "${STEAMLINK_ROOTFS}.old" ] && rm -rf "${STEAMLINK_ROOTFS}.old"
    [ -d "${STEAMLINK_ROOTFS}" ] && mv "${STEAMLINK_ROOTFS}" "${STEAMLINK_ROOTFS}.old"
    mkdir -p "${STEAMLINK_ROOTFS}"

    tar -xf "${layer_tar}" -C "${STEAMLINK_ROOTFS}"
    chown -R root:root "${STEAMLINK_ROOTFS}"

    [ ! -x "${STEAMLINK_BINARY}" ] && echo "Error: ${STEAMLINK_BINARY} does not exists" && exit 1
    echo "done"
}

#### MAIN: PREAMBLE ####

if [ "${SELF}" != "${EXPECTED_SELF}" ]; then
    echo "Warning: ${SELF} is not ${EXPECTED_SELF}"
fi

# only valid RUN_MODE's are batocera and other
if [ "${RUN_MODE}" != "batocera" -a "${RUN_MODE}" != "other" ]; then
    echo "Error: invalid RUN_MODE=${RUN_MODE}"
    exit 1
fi

export PATH="${BINARYDIR}:/usr/bin:/bin:/usr/local/bin:/usr/sbin:/sbin:/usr/local/sbin"
export TMPDIR="${TMPDIR}"

# check batocera version
VERSION=$(batocera-version | cut -d' ' -f1 | cut -d'-' -f1 | cut -d'.' -f1)
# remove any non numeric character
VERSION=$(echo "${VERSION}" | tr -cd '[:digit:]')

# This is only tested in version >= 36
if [ "$VERSION" -lt "36" ]; then
    echo "This script is only tested in version >= 36"
    exit 1
fi

# check for required tools
for cmd in jq curl; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "Error: $cmd not found"
        exit 1
    fi
done

if [ ! -d "${WORKDIR}" ]; then
    echo "Warning: ${WORKDIR} not found"
    mkdir -p "${WORKDIR}"
fi

if [ ! -d "${TMPDIR}" ]; then
    echo "Warning: ${TMPDIR} not found"
    mkdir -p "${TMPDIR}"
fi

if [ ! -d "${BINARYDIR}" ]; then
    echo "Warning: ${BINARYDIR} not found"
    mkdir -p "${BINARYDIR}"
fi

if [ ! -d "${STEAMLINK_ROOTFS}" ]; then
    echo "Warning: ${STEAMLINK_ROOTFS} not found"
fi

cd "${WORKDIR}"

# check for steamlink app
if [ ! -x "${STEAMLINK_BINARY}" ]; then
    echo "Warning: ${STEAMLINK_BINARY} does not exists (first run?)"
fi

do_check_minimal_space_required
do_download_steamlink
do_download_xwayland
do_download_bwrap

[ ! -x "${STEAMLINK_BINARY}" ] && echo "Error: ${STEAMLINK_BINARY} does not exists" && exit 1

# clear TMPDIR (used for downloads)
rm -rf "${TMPDIR}"/*

# if not running in batocera, only download and exit
if [ "${RUN_MODE}" != "batocera" ]; then
    echo "Not running in batocera and binaries were downloaded and installed in ${WORKDIR}. Exiting..."
    exit 0
fi

#### MAIN: RUN IN BATOCERA ####
set +e
# kill Xwayland if running
kill $(pidof Xwayland) && sleep 5 ;

# execute Xwayland
echo -n "Starting ${XWAYLAND_BINARY} (under bwrap)..."
[ -h "$XWAYLAND_ROOTFS"/var/run ] && rm "$XWAYLAND_ROOTFS"/var/run

"${BWRAP_BINARY}" \
    --bind "${XWAYLAND_ROOTFS}" / \
    --dev-bind /dev /dev \
    --bind /sys /sys \
    --bind /tmp /tmp \
    --proc /proc \
    --dir /run/ --bind /run/ /run/ \
    --dir /var/run/ --bind /var/run/ /var/run/ \
    --ro-bind /lib/modules /lib/modules \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind /etc/hostname /etc/hostname \
    --ro-bind /etc/hosts /etc/hosts \
    --ro-bind /boot /boot \
    --ro-bind / /.host/ \
    --bind /userdata/roms /userdata/roms \
    --bind /userdata/bios /userdata/bios \
    --setenv HOME /root \
    Xwayland -fullscreen &
echo "done"

echo -"Starting ${STEAMLINK_BINARY} (under bwrap)..."

[ -h "$STEAMLINK_ROOTFS"/var/run ] && rm "$STEAMLINK_ROOTFS"/var/run

"${BWRAP_BINARY}" \
    --bind "${STEAMLINK_ROOTFS}" / \
    --dev-bind /dev /dev \
    --bind /sys /sys \
    --bind /tmp /tmp \
    --proc /proc \
    --dir /run/ --bind /run/ /run/ \
    --dir /var/run/ --bind /var/run/ /var/run/ \
    --ro-bind /lib/modules /lib/modules \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind /etc/hostname /etc/hostname \
    --ro-bind /etc/hosts /etc/hosts \
    --ro-bind /boot /boot \
    --ro-bind / /.host/ \
    --bind /userdata/roms /userdata/roms \
    --bind /userdata/bios /userdata/bios \
    --setenv HOME /root \
    --setenv DISPLAY :0 \
    steamlink

# kill Xwayland if running
kill $(pidof Xwayland) && sleep 2 || true;
kill -9 $(pidof Xwayland) || true;

exec /bin/true