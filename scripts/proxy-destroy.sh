#!/bin/bash
set -e

if [[ -z $(docker ps -q --filter "name=docker_registry_proxy") ]]; then
    echo "Proxy does not exists."
else
    echo "Destroying proxy ..."
    docker stop docker_registry_proxy >/dev/null
    docker wait docker_registry_proxy >/dev/null 2>&1 || true
    docker rm -v docker_registry_proxy >/dev/null 2>&1 || true
    echo "Proxy destroyed."
fi
