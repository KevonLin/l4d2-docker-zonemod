.PHONY: ci ci-full

ci:
	@.scripts/local-ci.sh

ci-full:
	@.scripts/local-ci.sh --full