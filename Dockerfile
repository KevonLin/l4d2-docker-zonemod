FROM ubuntu:22.04 AS base

USER root

COPY --chmod=755 as-root.sh .
RUN ./as-root.sh

WORKDIR /home/louis
USER louis

FROM base AS game

# as-user.sh is copied but NOT executed at build time.
# Game installation now happens at container startup (see entrypoint.sh),
# so the image stays small and the game binaries are never baked in.
COPY --chmod=755 as-user.sh .
COPY --chmod=755 entrypoint.sh .

USER root

EXPOSE 27015/tcp 27015/udp
VOLUME ["/addons", "/cfg", "/scripts"]

COPY --chmod=755 entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"]