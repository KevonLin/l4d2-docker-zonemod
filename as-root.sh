#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

dpkg --add-architecture i386
apt-get update

apt-get -y install \
    libsdl2-2.0-0:i386 \
    libcurl4:i386 \
    language-pack-en \
    tar \
    telnet \
    git \
    curl \
    openssh-server \
    vim \
    ca-certificates \
    tzdata

GOSU_VERSION=1.17
curl -fsSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture)" -o /usr/local/bin/gosu
chmod +x /usr/local/bin/gosu

apt-get clean
rm -rf /var/lib/apt/lists/*

mkdir -p /var/run/sshd

useradd -m -s /bin/bash louis

mkdir -p /addons /cfg /scripts /motd /tmp/dumps /home/louis/l4d2
chown louis:louis /addons /cfg /scripts /motd /tmp/dumps /home/louis/l4d2

mkdir -p /home/louis/.ssh
chown louis:louis /home/louis/.ssh

sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config