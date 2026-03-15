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
    sudo \
    vim

apt-get clean
rm -rf /var/lib/apt/lists/*

mkdir -p /var/run/sshd

useradd -m -s /bin/bash louis
echo "louis ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/louis
echo "Defaults:louis !requiretty" >> /etc/sudoers.d/louis

mkdir -p /addons /cfg /scripts /motd /tmp/dumps
chown louis:louis /addons /cfg /scripts /motd /tmp/dumps

mkdir -p /home/louis/.ssh
chmod 700 /home/louis/.ssh
chown louis:louis /home/louis/.ssh

sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config