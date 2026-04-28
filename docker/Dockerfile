FROM ubuntu:18.04

LABEL Nostalgia, <nosnetworksupport@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git curl unzip wget jq lib32gcc1 lib32stdc++6 libc6 libgl1-mesa-glx libxcursor1 libxrandr2 libc6-dev libgcc-4.8-dev libxml2-utils && \
    useradd -d /home/container -m container

COPY ./entrypoint.sh /entrypoint.sh
COPY ./repo-sync.sh /repo-sync.sh

RUN chmod +x /entrypoint.sh /repo-sync.sh && \
    chown container:container /entrypoint.sh /repo-sync.sh

USER container
ENV  USER container
ENV  HOME /home/container

WORKDIR /home/container

CMD ["/bin/bash", "/entrypoint.sh"]
