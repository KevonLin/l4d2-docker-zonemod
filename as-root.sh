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
    tzdata \
    locales

apt-get clean
rm -rf /var/lib/apt/lists/*

# Generate the en_US.UTF-8 locale. The Source engine (srcds) explicitly calls
# setlocale("en_US.UTF-8") at startup; the Ubuntu base image ships minimal and
# has no locale data installed, so without this the engine warns
# "setlocale('en_US.UTF-8') failed" and falls back to the "C" locale, breaking
# international characters (chat, player names) on the server.
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

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

# Configure Vim globally for UTF-8 so editing Chinese text never shows mojibake
# (chat logs, server.cfg, SourceMod configs...). Ubuntu's /etc/vim/vimrc
# sources /etc/vim/vimrc.local when it exists, so this applies to every user
# in the container. A per-user ~/.vimrc for 'louis' would NOT work here:
# /home/louis is a Docker volume (a fresh volume is pre-populated from the
# image exactly once), so the system-wide file is the right place.
cat > /etc/vim/vimrc.local <<'EOF'
" Global Vim settings for the l4d2-docker-zonemod image.
" Work natively in UTF-8 and auto-detect common Chinese encodings when opening
" a file, so editing never mangles the text.
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=ucs-bom,utf-8,gb18030,gbk,big5,latin1
set fileformats=unix,dos,mac
EOF

# Belt and braces: newer Ubuntu ships a /etc/vim/vimrc that already ends with
# "if filereadable('/etc/vim/vimrc.local'): source it". If it doesn't, append
# the loader so our settings are honoured regardless of base-image nuances.
if ! grep -q "vimrc\.local" /etc/vim/vimrc 2>/dev/null; then
    cat >> /etc/vim/vimrc <<'EOF'

" Load local overrides (added by as-root.sh)
if filereadable('/etc/vim/vimrc.local')
  source /etc/vim/vimrc.local
endif
EOF
fi
