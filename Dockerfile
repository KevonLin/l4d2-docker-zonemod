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
COPY --chmod=755 install-plugins.sh .

# Start the entrypoint as root so it can set the timezone from the live
# environment at startup, then drop to the unprivileged "louis" user via
# gosu. The image itself stays timezone-agnostic.
USER root

EXPOSE 27015/tcp 27015/udp 22/tcp
VOLUME ["/home/louis"]

ENTRYPOINT ["./entrypoint.sh"]