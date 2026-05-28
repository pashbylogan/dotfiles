# Makefile — the single source of truth for this repo's checks. [D-CI]
#
# This repo is a minimal personal overlay on Omarchy (start: docs/index.html).
# `.github/workflows/ci.yml` invokes these same targets, so **`make ci` runs
# exactly what GitHub Actions runs** — green locally == green in CI.
#
# Humans & agents: run `make` (or `make help`) for the menu, `make fmt` to
# auto-fix formatting, and `make ci` before committing.

# ── pinned tooling ───────────────────────────────────────────────────────────
# prettier is pinned here and used by BOTH local and CI (CI calls this Makefile).
# shellcheck/shfmt are installed via Omarchy locally (`make tools`) and pinned in
# ci.yml's install step; the versions below are what CI uses — keep in sync.
PRETTIER           := npx --yes prettier@3.8.3
SHELLCHECK_VERSION := 0.11.0
SHFMT_VERSION      := 3.10.0
# -ln bash: the sourced fragments have no shebang; force the bash dialect so
# shfmt never falls back to POSIX parsing of their bash-only syntax.
SHFMT_FLAGS        := -ln bash -i 2 -ci

# ── the file sets this repo governs (the repo's "knowledge") ──────────────────
# Shell: the installer + every personal command + the sourced bash fragments.
# The fragments have no shebang; they carry a `# shellcheck shell=bash` directive.
SHELL_FILES := install $(wildcard bin/.local/bin/*) \
	bash/.config/dotfiles/shell.sh \
	bash/.config/dotfiles/shell.local.sh.example
# Docs: hand-written HTML knowledge base + the machine-readable registry.
PRETTIER_GLOBS := docs/*.html docs/registry.json
DOCS_CHECK     := .github/scripts/check_docs.py

.DEFAULT_GOAL := help
.PHONY: help ci lint fmt fmt-check shellcheck shfmt-check shfmt-fix \
	prettier-check prettier-fix docs apply tools

help: ## Show this menu
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z0-9_-]+:.*## /{printf "  \033[36m%-15s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Run 'make ci' before committing — it mirrors GitHub Actions exactly."

ci: lint fmt-check docs ## Run the full CI gate locally (what GitHub Actions runs)
	@echo "OK - all CI checks passed"

lint: shellcheck ## Lint shell scripts for bugs (shellcheck)

fmt: shfmt-fix prettier-fix ## Auto-fix all formatting in place (shfmt + prettier)

fmt-check: shfmt-check prettier-check ## Check formatting without writing (CI does this)

docs: ## Verify docs/ integrity (registry <-> anchors <-> code paths, links, appears_in)
	python3 $(DOCS_CHECK)

apply: ## Run the overlay installer (./install) — idempotent
	./install

# ── granular targets (ci.yml calls these directly) ───────────────────────────
shellcheck: ## Lint the shell file set
	shellcheck $(SHELL_FILES)

shfmt-check: ## Shell formatting check (diff only, no write)
	shfmt -d $(SHFMT_FLAGS) $(SHELL_FILES)

shfmt-fix: ## Format shell files in place
	shfmt -w $(SHFMT_FLAGS) $(SHELL_FILES)

prettier-check: ## Docs formatting check (HTML + JSON)
	$(PRETTIER) --check $(PRETTIER_GLOBS)

prettier-fix: ## Format docs in place (HTML + JSON)
	$(PRETTIER) --write $(PRETTIER_GLOBS)

tools: ## Show required tools + how to install them on Omarchy
	@echo "Expected (CI pins): shellcheck $(SHELLCHECK_VERSION), shfmt $(SHFMT_VERSION), prettier 3.8.3"
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck --version | awk '/version:/{print "  shellcheck: "$$2}'; else echo "  shellcheck: MISSING -> omarchy pkg add shellcheck   (lean: omarchy pkg aur add shellcheck-bin)"; fi
	@if command -v shfmt >/dev/null 2>&1; then echo "  shfmt:      $$(shfmt --version)"; else echo "  shfmt:      MISSING -> omarchy pkg add shfmt"; fi
	@if command -v npx >/dev/null 2>&1; then echo "  node/npx:   present (prettier runs via '$(PRETTIER)')"; else echo "  node/npx:   MISSING -> install node via mise"; fi
	@if command -v python3 >/dev/null 2>&1; then echo "  python3:    $$(python3 --version | awk '{print $$2}')"; else echo "  python3:    MISSING"; fi
