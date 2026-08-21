#!/bin/bash
set -e

# Prevent any apt/dpkg debconf front-end from prompting interactively.
# Without this, `apt-get install tzdata` pops up the classic region/city
# selection menu, which hangs (and cancels) the docker build.
export DEBIAN_FRONTEND=noninteractive

dpkg --add-architecture i386
apt-get update

apt-get -y install \
    libc6:i386 \
    lib32z1 \
    tar \
    telnet \
    git \
    curl \
    openssh-server \
    vim \
    ca-certificates \
    tzdata

apt-get clean
rm -rf /var/lib/apt/lists/*

# gosu lets the entrypoint run as root (to set the timezone at startup) and
# then drop privileges to the unprivileged "louis" user for the actual work.
GOSU_VERSION=1.17
curl -fsSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture)" -o /usr/local/bin/gosu
chmod +x /usr/local/bin/gosu

mkdir -p /var/run/sshd

useradd -m -s /bin/bash louis

sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config