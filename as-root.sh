#!/bin/bash
set -e

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

: "${TZ:=UTC}"
echo "Setting timezone to $TZ"
echo "$TZ" > /etc/timezone
ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
dpkg-reconfigure -f noninteractive tzdata 2>/dev/null || true

mkdir -p /var/run/sshd

useradd -m -s /bin/bash louis

sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config