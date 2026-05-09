#!/bin/sh
set -e
M="$1:/app/bin/data/ISP_haydarpasa:ro"
echo $M
xhost +local:docker
docker run --rm -it \
         -e DISPLAY="$DISPLAY" \
         -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
         --device /dev/dri \
         -v ${M} \
         rutt-etra || true
xhost -local:docker
