#!/bin/sh
docker run -d --name nginx_proxy -v `pwd`:/etc/nginx/conf.d -v `pwd`/www:/var/www -p 443:443 -p 80:80 nginx
