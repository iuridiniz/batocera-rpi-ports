#!/bin/sh
# set -x
set -e
SELF=`readlink -f "$0"`
BASEDIR=$( (cd -P "`dirname "$SELF"`" && pwd) )
DOCKER_IMAGE_BASE="iuridiniz"
cd "$BASEDIR"

# 32bits images, make raspbian first
for dockerfile in Dockerfile.arm32v7-raspbian:* Dockerfile.arm32v7-steamlink:*; do
    [ -f "$dockerfile" ] || continue
    image_name="`echo "$dockerfile" | sed 's/Dockerfile\.\(.*\)/\1/'`"
    docker buildx build --load --progress=plain --platform linux/arm/v7 -t "$DOCKER_IMAGE_BASE/$image_name" -f "$dockerfile" .
done

# 64bits images
for dockerfile in Dockerfile.arm64v8-*; do
    [ -f "$dockerfile" ] || continue
    image_name="`echo "$dockerfile" | sed 's/Dockerfile\.\(.*\)/\1/'`"
    docker buildx build --load --progress=plain --platform linux/arm64 -t "$DOCKER_IMAGE_BASE/$image_name" -f "$dockerfile" .
done