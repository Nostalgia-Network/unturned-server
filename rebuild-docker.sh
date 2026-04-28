#!/usr/bin/env bash

# Login needed for push to Docker Hub
source .env
docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD docker.io
history -d -2 # Remove docker login from BASH history to prevent plaintext credential storage

docker build -t nostalgianetwork/unturned-server ./docker

# Push will fail unless you are added as a collaborator to the repository
docker push nostalgianetwork/unturned-server