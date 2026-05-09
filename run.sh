#!/bin/sh
set -e
xhost +local:docker
docker run --rm -it \
         -e DISPLAY="$DISPLAY" \
         -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
         --device /dev/dri \
         rutt-etra || true
xhost -local:docker
