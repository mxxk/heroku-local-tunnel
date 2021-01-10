#!/usr/bin/env bash

set -o errexit

cd "$(dirname "${BASH_SOURCE[0]}")"
haproxy -f ./haproxy.cfg &
PORT=$TUNNELTO_TUNNEL_PORT RUST_LOG=tunnelto_server=debug RUST_BACKTRACE=1 ALLOWED_HOSTS=$TUNNELTO_ALLOWED_HOSTS ./tunnelto_server &
# Wait for first process to exit, then exit the entire program.
wait

# TODO: Determine which env variables are needed:

# ALLOW_UNKNOWN_CLIENTS=1
