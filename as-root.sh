#!/bin/bash
set -e

# Prevent any apt/dpkg debconf front-end from prompting interactively.
# Without this, `apt-get install tzdata` pops up the classic region/city
# selection menu, which hangs (and cancels) the docker build.
export DEBIAN_FRONTEND=noninteractive

dpkg --add-architecture i386
apt-get update

# 32-bit runtime for SteamCMD and the L4D2 srcds binary:
#   - libc6:i386      32-bit glibc
#   - lib32z1         32-bit zlib  (steamcmd needs it)
#   - lib32gcc-s1     32-bit libgcc_s.so.1   (required on Ubuntu 22.04+; the
#                     old "lib32gcc1" no longer exists on 24.04)
#   - lib32stdc++6    32-bit libstdc++.so.6  (srcds_linux needs it)
apt-get -y install \
    libc6:i386 \
    lib32z1 \
    lib32gcc-s1 \
    lib32stdc++6 \
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

# Configure sshd via a drop-in file instead of sed-rewriting sshd_config:
# every supported Ubuntu release reads /etc/ssh/sshd_config.d/*.conf (through
# the "Include" directive), which is robust against the commented-out default
# lines changing between 22.04 (jammy) and 24.04 (noble).
cat > /etc/ssh/sshd_config.d/zz-l4d2.conf <<'EOF'
# Applied at build time for the l4d2-docker-zonemod image.
PubkeyAuthentication yes
PasswordAuthentication no
EOF