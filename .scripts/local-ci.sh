#!/bin/bash
# Local CI checks – mirrors .github/workflows/ci.yml
# Usage (from repository root):
#   ./.scripts/local-ci.sh         # quick checks (no game download)
#   ./.scripts/local-ci.sh --full  # full docker build (downloads SteamCMD + game)

set -e
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo "🚀 Running local CI..."

# 1. YAML syntax
echo; echo "📄 [1/6] YAML lint"
if ! command -v yamllint &>/dev/null; then pip install yamllint --user -q; fi
# Collect existing compose files NUL-safely (SC2011: use `find -print0`, not `ls | xargs`).
COMPOSE_FILES=()
while IFS= read -r -d '' f; do
  COMPOSE_FILES+=("$f")
done < <(find . -maxdepth 1 \( -name 'docker-compose.yml' -o -name 'compose.yml' -o -name 'compose.bind.yml' \) -print0 2>/dev/null || true)
yamllint --no-warnings "${COMPOSE_FILES[@]}" .github/workflows/*.yml || fail "YAML error"

# 2. Shell syntax (bash -n)
echo; echo "📄 [2/6] Shell syntax"
for f in *.sh; do bash -n "$f" || fail "Syntax error in $f"; done
pass "Shell scripts OK"

# 3. Dockerfile static checks (no download)
echo; echo "📄 [3/6] Dockerfile lint"
docker build --check . || fail "docker build --check failed"
docker buildx build --load --target=base -t l4d2-local-base . || fail "Base stage build failed"
pass "Dockerfile static check OK"

# 4. External URL reachability (warn only)
echo; echo "📄 [4/6] External URLs (warn only)"
for url in "https://media.steampowered.com/installer/steamcmd_linux.tar.gz" \
           "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64" \
           "https://github.com/SirPlease/L4D2-Competitive-Rework.git"; do
  code=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" || echo "000")
  [[ "$code" =~ ^(200|30[12])$ ]] && pass "  $url" || warn "  $url (HTTP $code)"
done

# 5. .env.example validation
echo; echo "📄 [5/6] .env.example validation"
[ -f .env.example ] || fail ".env.example missing"
for var in HOME INSTALL_DIR GAME_NAME GAME_ID INSTALL_PLUGINS PORT IP DEFAULT_MAP MAXPLAYERS TZ; do
  grep -q "^${var}=" .env.example || fail "Missing $var in .env.example"
done
pass ".env.example OK"

# 6. Cross-file consistency (COPY sources, ENTRYPOINT)
echo; echo "📄 [6/6] Cross-file consistency"
grep '^COPY ' Dockerfile | while read -r _ line; do
  [[ "$line" == --chmod=* ]] && line="${line#--chmod=* }"
  src="${line%% *}"
  [ -f "$src" ] || fail "COPY source missing: $src"
  pass "  COPY $src exists"
done
entry=$(grep '^ENTRYPOINT' Dockerfile | sed 's/.*"\(.*\)".*/\1/')
[ -f "$(basename "$entry")" ] || fail "ENTRYPOINT $entry missing"
pass "ENTRYPOINT exists"

# Optional full build (triggered by --full)
if [[ "$1" == "--full" ]]; then
  echo; echo "📦 [FULL] Building entire image (downloads SteamCMD + game)..."
  docker build --no-cache -t l4d2-local-full . || fail "Full build failed"
  pass "Full build successful (image not pushed)"
fi

echo; echo "🎉 All local checks passed!"