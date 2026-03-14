#!/bin/bash
microdnf -y install SDL2.i686 \
    libcurl.i686 \
    glibc-langpack-en \
    tar \
    telnet \
    git \
    curl                # 添加 curl
microdnf -y update
microdnf clean all

useradd louis

mkdir /addons /cfg /scripts /motd /tmp/dumps
chown louis:louis /addons /cfg /scripts /motd /tmp/dumps