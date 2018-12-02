#!/bin/sh
docker stop nginx_proxy
docker rm nginx_proxy
./run.sh
