FROM ubuntu:22.04 AS base

USER root

COPY --chmod=755 as-root.sh .
RUN ./as-root.sh

WORKDIR /home/louis
USER louis

FROM base AS game

ARG GAME_ID=222860 \
    INSTALL_DIR="l4d2"

COPY --chmod=755 as-user.sh .
RUN ./as-user.sh

COPY --chmod=755 install-plugins.sh .
RUN ./install-plugins.sh

USER root

EXPOSE 27015/tcp 27015/udp
VOLUME ["/addons", "/cfg", "/scripts"]

COPY --chmod=755 entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"]