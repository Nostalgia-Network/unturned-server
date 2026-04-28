#!/usr/bin/env bash

# Login needed for push to Docker Hub
source .env

echo "$DOCKER_PASSWORD" | docker login -u $DOCKER_USERNAME --password-stdin docker.io
unset $DOCKER_PASSWORD
unset $DOCKER_USERNAME
docker build -t nostalgianetwork/unturned-server ./docker

# Push will fail unless you are added as a collaborator to the repository
docker push nostalgianetwork/unturned-server