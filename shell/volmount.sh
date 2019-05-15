#!/bin/bash

USAGE=$(cat <<-EOF

Mounts a container volume at a host mount point and makes container
files and directories appear to be owned by the current user.

Usage:
  $(basename $0) [-e engine] [-v volume] MOUNT-POINT
  $(basename $0) -h

At least the parent directory of MOUNT-POINT must exist, and MOUNT-POINT
must be an empty directory.

Options (default values can be overridden by environment variables):
  -e engine     Container engine to use: 'docker', 'podman' or an absolute path to the
                engine executable. 
                Default: TYPO3DEV_ENGINE, or 'podman' if installed, else 'docker'.
  -v volume     Volume name or absolute directory path mapped to the TYPO3 root
                directory in the container. Default: TYPO3DEV_VOLUME, or 'typo3-vol'.
  -h            Displays this text and exits.
 
EOF
)

ALLOWED_OPTS=e:v:

. $(dirname $0)/utils.sh

# At least the parent directory of the mount directory must exist
MAPPED_DIR=$(readlink -f "$1")
MAPPED_PARENT=$(dirname "$MAPPED_DIR")

[ -d "$MAPPED_PARENT" ] || usage "$MAPPED_PARENT is not a directory"

mkdir -p "$MAPPED_DIR"

# Mount directory not empty?
[ -n "$(ls -A "$MAPPED_DIR")" ] && usage "$MAPPED_DIR is not empty"

# Get the volume mount point
VOL_DIR=$($ENGINE volume inspect --format "$MP_FORMAT" $VOLUME) \
    || usage "Volume '$VOLUME' not found"

# Determine UID and GID of the volume owner
VOL_UID=$($SUDO_PREFIX stat --format '%u' $VOL_DIR)
VOL_GID=$($SUDO_PREFIX stat --format '%g' $VOL_DIR)

sudo bindfs \
    --map=$VOL_UID/$(id -u):@$VOL_GID/@$(id -g) \
    $VOL_DIR \
    "$MAPPED_DIR"

echo "Volume '$VOLUME' now mounted at directory $MAPPED_DIR"