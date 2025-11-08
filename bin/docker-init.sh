#!/bin/bash

# replace default api path to new one
python /app/bin/update_docker_js_api_address.py

# start backend api server in background
crawlab-server server &

# start nginx for static frontend and reverse proxy
nginx -g 'daemon off;'
