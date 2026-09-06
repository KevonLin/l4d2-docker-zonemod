FROM ubuntu:24.04 AS base

USER root

COPY --chmod=755 as-root.sh .
RUN ./as-root.sh

WORKDIR /home/louis
USER louis

FROM base AS game

# as-user.sh is copied but NOT executed at build time.
# Game installation now happens at container startup (see entrypoint.sh),
# so the image stays small and the game binaries are never baked in.
#
# The scripts live OUTSIDE the /home/louis volume on purpose: Docker copies a
# fresh volume's directory contents from the image on first use, so scripts
# placed inside the volume would be shadowed by stale copies on later container
# recreations and image updates would never take effect.
COPY --chmod=755 as-user.sh /usr/local/bin/
COPY --chmod=755 entrypoint.sh /usr/local/bin/
COPY --chmod=755 install-plugins.sh /usr/local/bin/
COPY --chmod=755 start.sh /usr/local/bin/
COPY --chmod=755 stop.sh /usr/local/bin/
COPY --chmod=755 restart.sh /usr/local/bin/

# Start the entrypoint as root so it can set the timezone from the live
# environment at startup, then drop to the unprivileged "louis" user via
# gosu. The image itself stays timezone-agnostic.
WORKDIR /home/louis
USER root

# Default to UTF-8 so the Source engine's setlocale("en_US.UTF-8") call succeeds
# (the locale is generated in as-root.sh) and international characters work in
# chat/names. steamcmd and git also behave consistently under UTF-8.
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

EXPOSE 27015/tcp 27015/udp 22/tcp
VOLUME ["/home/louis"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]