#!/bin/bash

set -eu
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/config.sh


# Build the local binary and docker image
echo "Building Simd Docker...  "

image=dockernet/dockerfiles/Dockerfile

DOCKER_BUILDKIT=1 docker build --tag simd:debug -f $image .
docker_build_succeeded=${PIPESTATUS[0]}

if [[ "$docker_build_succeeded" == "0" ]]; then
   echo "Done" 
else
   echo "Failed"
fi

set -e
