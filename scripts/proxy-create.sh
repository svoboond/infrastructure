#!/bin/bash
set -e

if [[ -z $1 ]]; then
    echo "Cluster name argument not supplied."
    exit -1
else
    cluster_name="$1"
fi

if [[ -n $(docker ps -q --filter "name=docker_registry_proxy") ]]; then
    echo "Proxy already exists."
    exit 0
fi

if [[ -z $(docker network ls -q --filter "name=${cluster_name}") ]]; then
    echo "Docker network ${cluster_name} does not exist. Create cluster first."
    exit -2
else
    echo "Creating proxy ..."
    docker run --detach --rm --name docker_registry_proxy -it \
        --net "${cluster_name}" --hostname docker-registry-proxy \
        -p 0.0.0.0:3128:3128 -e ENABLE_MANIFEST_CACHE=true \
        -v $(pwd)/docker_mirror_cache:/docker_mirror_cache \
        -v $(pwd)/docker_mirror_certs:/ca \
        -e REGISTRIES="k8s.gcr.io gcr.io docker.elastic.co" \
        rpardini/docker-registry-proxy:0.6.2 >/dev/null
fi

if [[ -z $(docker ps -q --filter "name=${cluster_name}") ]]; then
    echo "Cluster not configured to use proxy, because cluster does not exist."
    exit -3
else
    docker cp scripts/wait-for-it.sh "${cluster_name}:/root" >/dev/null
    docker exec "${cluster_name}" bash -c "/root/wait-for-it.sh --timeout=10 docker-registry-proxy:3128" >/dev/null
    docker exec "${cluster_name}" bash -c "\
        curl http://docker-registry-proxy:3128/setup/systemd \
        | sed '/Environment/ s/$/ \"NO_PROXY=localhost,127.0.0.1,10.96.0.0\/12,192.168.59.0\/24,192.168.49.0\/24,192.168.39.0\/24\"/' \
        | bash" >/dev/null
    runtime="60 second"
    endtime=$(date -ud "$runtime" +%s)
    cluster_healthy=false
    while [[ $(date -u +%s) -le $endtime ]]; do
        cluster_status=$(kubectl get nodes "${cluster_name}" -o custom-columns=STATUS:status.conditions[-1].type --no-headers || true)
        if [[ $cluster_status == "Ready" ]]; then
            cluster_healthy=true
            break
        fi
        sleep 5
    done
    if [[ $cluster_healthy == true ]]; then
        echo "Cluster configured to use proxy."
    else
        echo "Cluster is not healthy."
        exit -4
    fi
fi
