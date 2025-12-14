FROM rockylinux/rockylinux:9-minimal AS base

ADD as-root.sh .
RUN ./as-root.sh

WORKDIR /home/louis
USER louis

FROM base AS game

ARG GAME_ID=222860 \
    INSTALL_DIR="l4d2"

EXPOSE 27015/tcp 27015/udp

ADD as-user.sh .
RUN ./as-user.sh

VOLUME ["/addons", "/cfg", "/scripts"]

ADD install-plugins.sh .
RUN ./install-plugins.sh

ADD entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"]
