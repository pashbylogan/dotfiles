# Makefile — the single source of truth for this repo's checks. [D-CI]
#
# This repo is a minimal personal overlay on Omarchy (start: docs/index.html).
# `.github/workflows/ci.yml` runs `make ci`, so green locally == green in CI.
#
# Humans & agents: `make` for the menu, `make fmt` to auto-fix formatting,
# `make ci` before committing.

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
	bash/.config/dotfiles/shell.local.sh.example \
	$(wildcard .github/scripts/*.sh)
# Docs: hand-written HTML knowledge base + the machine-readable registry.
PRETTIER_GLOBS := docs/*.html docs/registry.json
DOCS_CHECK     := .github/scripts/check_docs.py

.DEFAULT_GOAL := help
.PHONY: help ci fmt tools update verify

help: ## Show this menu
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z0-9_-]+:.*## /{printf "  \033[36m%-6s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Run 'make ci' before committing — it's exactly what GitHub Actions runs."

ci: ## Run the full gate: shellcheck + shfmt + prettier + docs integrity
	shellcheck $(SHELL_FILES)
	shfmt -d $(SHFMT_FLAGS) $(SHELL_FILES)
	$(PRETTIER) --check $(PRETTIER_GLOBS)
	python3 $(DOCS_CHECK)
	@echo "OK - all checks passed"

fmt: ## Auto-fix formatting in place (shfmt + prettier)
	shfmt -w $(SHFMT_FLAGS) $(SHELL_FILES)
	$(PRETTIER) --write $(PRETTIER_GLOBS)

tools: ## Show required tools + how to install them on Omarchy
	@echo "Expected (CI pins): shellcheck $(SHELLCHECK_VERSION), shfmt $(SHFMT_VERSION), prettier 3.8.3"
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck --version | awk '/version:/{print "  shellcheck: "$$2}'; else echo "  shellcheck: MISSING -> omarchy pkg add shellcheck   (lean: omarchy pkg aur add shellcheck-bin)"; fi
	@if command -v shfmt >/dev/null 2>&1; then echo "  shfmt:      $$(shfmt --version)"; else echo "  shfmt:      MISSING -> omarchy pkg add shfmt"; fi
	@if command -v npx >/dev/null 2>&1; then echo "  node/npx:   present (prettier runs via '$(PRETTIER)')"; else echo "  node/npx:   MISSING -> install node via mise"; fi
	@if command -v python3 >/dev/null 2>&1; then echo "  python3:    $$(python3 --version | awk '{print $$2}')"; else echo "  python3:    MISSING"; fi

# ── update: single command to refresh everything on this machine ─────────────
# `omarchy update -y` covers pacman + AUR + omarchy itself + migrations + keyring
# + orphan cleanup, but NOT firmware (separate omarchy command) and NOT uv (Astral
# self-installer, lives outside pacman/yay). This target chains all three so
# `make update` truly updates everything package-manager-reachable on the box.
# JetBrains IDEs managed inside jetbrains-toolbox have no headless update path —
# open Toolbox to update those (the toolbox AUR package itself is updated above).
update: ## Update everything: omarchy/pacman/AUR + firmware + uv, then `make verify`
	@printf "Note: if 'omarchy update -y' triggers a reboot, the firmware/uv/verify steps below will NOT run automatically — re-invoke 'make update' afterwards.\n\n"
	@# Each step is allowed to fail independently so a non-zero exit (no firmware
	@# devices, transient network, reboot decline) does not silently skip the rest.
	omarchy update -y || printf "\nWARN: 'omarchy update -y' returned non-zero (benign if a reboot was requested).\n"
	omarchy update firmware || printf "\nWARN: 'omarchy update firmware' returned non-zero (no fwupd devices? offline? expected on some hardware).\n"
	@if command -v uv >/dev/null 2>&1; then printf "\nUpdating uv...\n"; uv self update || true; fi
	@printf "\nNote: JetBrains IDEs managed by jetbrains-toolbox update via Toolbox's own UI.\n"
	@printf "\nPost-update verify:\n"
	@$(MAKE) --no-print-directory verify

verify: ## Health-check the live overlay (hyprctl, managed blocks, stow links, dev-env tools, XDG dirs)
	bash .github/scripts/verify.sh
