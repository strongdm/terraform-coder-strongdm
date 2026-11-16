FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git sudo unzip \
    && rm -rf /var/lib/apt/lists/*

RUN userdel -r ubuntu \
    && useradd --create-home --shell /bin/bash --uid 1000 coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder

USER coder
WORKDIR /home/coder
