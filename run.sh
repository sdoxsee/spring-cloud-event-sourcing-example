#!/usr/bin/env bash

set -e

# see https://github.com/spotify/docker-maven-plugin/issues/218#issuecomment-217383661
export DOCKER_HOST=unix:///var/run/docker.sock

# Build the project and docker images
mvn clean install -DskipTests
# mvn install -DskipTests -DskipDockerBuild

# Export the active docker machine IP
# export DOCKER_IP=$(docker-machine ip $(docker-machine active))

# docker-machine doesn't exist in Linux, assign default ip if it's not set
# DOCKER_IP=${DOCKER_IP:-0.0.0.0}
export DOCKER_IP=192.168.2.19

# Remove existing containers
docker-compose stop
docker-compose rm -f

# Start the config service first and wait for it to become available
docker-compose up -d config-service

while [ -z ${CONFIG_SERVICE_READY} ]; do
  echo "Waiting for config service..."
  if [ "$(curl --silent $DOCKER_IP:8888/health 2>&1 | grep -q '\"status\":\"UP\"'; echo $?)" = 0 ]; then
      CONFIG_SERVICE_READY=true;
  fi
  sleep 2
done

# Start the discovery service next and wait
docker-compose up -d discovery-service

while [ -z ${DISCOVERY_SERVICE_READY} ]; do
  echo "Waiting for discovery service..."
  if [ "$(curl --silent $DOCKER_IP:8761/health 2>&1 | grep -q '\"status\":\"UP\"'; echo $?)" = 0 ]; then
      DISCOVERY_SERVICE_READY=true;
  fi
  sleep 2
done

# Start the other containers
docker-compose up -d

# Attach to the log output of the cluster
docker-compose logs -f
