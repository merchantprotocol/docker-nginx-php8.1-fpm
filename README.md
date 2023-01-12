# docker-webserver-nginx-php8.0-fpm

I got tired of building and rebuilding images everytime I wanted to deploy a new php project.

This image is one that I start as the base image for all of my projects to quickly get up and running. It's also used as part of multiple production clusters.

You can find this image hosted over at the [docker.io public repository](https://hub.docker.com/repository/docker/byrdziak/merchantprotocol-webserver-nginx-php8.0).

## Docker Build

`docker build -t namephp8 ./`