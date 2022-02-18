#!/bin/bash
set -e
set -x

docker build --pull . -t docker.io/udevbe/compositor-proxy:nvidia
docker push docker.io/udevbe/compositor-proxy:nvidia
