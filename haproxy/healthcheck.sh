#!/bin/bash
# Docker Healthcheck - just check if the runit services are all running.

set -o pipefail

count=$(curl -s -k https://127.0.0.1:9998/metrics | grep -P 'node_service_state{.*} 0' | wc -l)
if [ $? != 0 ] ; then
    exit 1
fi

if [ $count != 0 ]; then
    exit 1
fi

exit 0
