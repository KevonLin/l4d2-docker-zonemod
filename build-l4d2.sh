#!/bin/bash
set -e

# The timezone is applied at container startup from the environment (see
# entrypoint.sh), NOT baked into the image. So no build args are needed.
docker build --progress plain -t kevonlin/l4d2 .