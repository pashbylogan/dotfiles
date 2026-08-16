# Keep repo checks centralized so local runs and CI cannot drift. [D-CI]

# ── pinned tooling ───────────────────────────────────────────────────────────
# prettier is pinned here and used by BOTH local and CI (CI calls this Makefile).
# shellcheck/shfmt are installed via Omarchy locally (`make tools`) and pinned in
# ci.yml's install step; the versions below are what CI uses — keep in sync.
PRETTIER           := npx --yes prettier@3.8.3
SHELLCHECK_VERSION := 0.11.0
SHFMT_VERSION      := 3.13.1
# Force dialects for sourced fragments with no shebang so shfmt parses them the
# same way their real loaders do.
BASH_SHFMT_FLAGS   := -ln bash -i 2 -ci
POSIX_SHFMT_FLAGS  := -ln posix -i 2 -ci

# ── file sets ────────────────────────────────────────────────────────────────
# Include sourced fragments explicitly because shell globs won't discover them.
BASH_FILES := install lib/style.sh $(wildcard bin/.local/bin/*) \
	bash/.config/dotfiles/shell.sh \
	bash/.config/dotfiles/shell.local.sh.example \
	claude/.claude/statusline-command.sh \
	$(wildcard .github/scripts/*.sh)
POSIX_FILES := $(wildcard uwsm/.config/uwsm/env.d/*.sh)
SHELL_FILES := $(BASH_FILES) $(POSIX_FILES)
PRETTIER_GLOBS := docs/*.html docs/registry.json
DOCS_CHECK     := .github/scripts/check_docs.py
JQ_FILTERS     := $(wildcard claude/*.jq) $(wildcard opencode/*.jq)

# ── output styling ───────────────────────────────────────────────────────────
# Mirror the shell palette (lib/style.sh: ── headers ──, ℹ info, ⚠ warn) so `make`
# and the installer read alike — Make can't source that bash file, hence the copy.
# Set NO_COLOR (any value) for plain piped/CI logs; used only in printf strings. [D-CI]
ifeq ($(origin NO_COLOR),undefined)
BOLD   := \033[1m
CYAN   := \033[0;36m
YELLOW := \033[1;33m
NC     := \033[0m
endif

.DEFAULT_GOAL := help
.PHONY: help ci fmt tools update update-firmware verify pkg-residue

# ── checks ───────────────────────────────────────────────────────────────────
help: ## Show this menu
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z0-9_-]+:.*## /{printf "  $(CYAN)%-6s$(NC) %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Run 'make ci' before committing — it's exactly what GitHub Actions runs."

ci: ## Run the full gate: shellcheck + shfmt + prettier + jq filter parse + docs integrity
	shellcheck -x $(SHELL_FILES)
	shfmt -d $(BASH_SHFMT_FLAGS) $(BASH_FILES)
	shfmt -d $(POSIX_SHFMT_FLAGS) $(POSIX_FILES)
	$(PRETTIER) --check $(PRETTIER_GLOBS)
	@# Tool-owned JSON filters must parse and be no-ops on an empty object. The
	@# bar layout is no longer one of them — `omarchy bar` converges it natively.
	@for f in $(JQ_FILTERS); do echo '{}' | jq -f "$$f" >/dev/null || { echo "jq filter failed: $$f"; exit 1; }; done
	@if [ -n "$(JQ_FILTERS)" ]; then echo "jq filters parse + smoke pass: $(JQ_FILTERS)"; fi
	python3 $(DOCS_CHECK)
	@echo "OK - all checks passed"

fmt: ## Auto-fix formatting in place (shfmt + prettier)
	shfmt -w $(BASH_SHFMT_FLAGS) $(BASH_FILES)
	shfmt -w $(POSIX_SHFMT_FLAGS) $(POSIX_FILES)
	$(PRETTIER) --write $(PRETTIER_GLOBS)

tools: ## Show required tools + how to install them on Omarchy
	@echo "Expected (CI pins): shellcheck $(SHELLCHECK_VERSION), shfmt $(SHFMT_VERSION), prettier 3.8.3"
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck --version | awk '/version:/{print "  shellcheck: "$$2}'; else echo "  shellcheck: MISSING -> re-run ./install (tracked in packages.txt) or 'omarchy pkg add shellcheck'"; fi
	@if command -v shfmt >/dev/null 2>&1; then echo "  shfmt:      $$(shfmt --version)"; else echo "  shfmt:      MISSING -> re-run ./install (tracked in packages.txt) or 'omarchy pkg add shfmt'"; fi
	@if command -v npx >/dev/null 2>&1; then echo "  node/npx:   present (prettier runs via '$(PRETTIER)')"; else echo "  node/npx:   MISSING -> install node via mise"; fi
	@if command -v python3 >/dev/null 2>&1; then echo "  python3:    $$(python3 --version | awk '{print $$2}')"; else echo "  python3:    MISSING"; fi

# ── machine maintenance ──────────────────────────────────────────────────────
# `make update` bundles the frequent, low-risk channels: Omarchy/pacman/AUR
# packages plus uv's self-managed release. Quattro owns mise updates. Firmware is the lone
# opt-in exception (`make update-firmware`) because it alone carries
# device-specific reboot/power-cycle risk. [D-CI]
update: ## Packages + Omarchy migrations + uv, then `make verify`
	@printf "$(CYAN)ℹ$(NC) If 'omarchy update -y' triggers a reboot, verify won't run — re-run 'make update' after.\n"
	@orphans="$$(pacman -Qdtq 2>/dev/null || true)"; \
	if [ -n "$$orphans" ]; then \
		printf "$(YELLOW)⚠$(NC) Orphan packages would make Omarchy's pseudo-TTY updater prompt:\n%s\n" "$$orphans"; \
		printf "Audit them first; drop confirmed leftovers with 'omarchy pkg drop <names>' or run 'omarchy update' interactively.\n"; \
		exit 1; \
	fi
	@printf "\n$(BOLD)── Packages & Omarchy migrations ──$(NC)\n"
	@printf "$(CYAN)$$ omarchy update -y$(NC)\n"
	@omarchy update -y || printf "$(YELLOW)⚠$(NC) 'omarchy update -y' returned non-zero; continuing to uv and verification.\n"
	@printf "\n$(BOLD)── uv self-update ──$(NC)\n"
	@if command -v uv >/dev/null 2>&1; then \
		printf "$(CYAN)$$ uv self update$(NC)\n"; \
		uv self update || printf "$(YELLOW)⚠$(NC) 'uv self update' returned non-zero; continuing to verification.\n"; \
	else \
		printf "$(CYAN)ℹ$(NC) uv not found on PATH — skipped.\n"; \
	fi
	@printf "\n$(CYAN)ℹ$(NC) JetBrains IDEs update via jetbrains-toolbox's own UI.\n"
	@printf "\n$(BOLD)── Verify overlay ──$(NC)\n"
	@printf "$(CYAN)$$ $(MAKE) --no-print-directory verify$(NC)\n"
	@$(MAKE) --no-print-directory verify

# Firmware is intentionally opt-in: unlike packages or self-managed tool
# upgrades, fwupd outcomes are device-specific and can power-cycle. [D-CI]
update-firmware: ## Update firmware (fwupd)
	@printf "$(CYAN)ℹ$(NC) Firmware updater outcomes aren't package-like; review prompts carefully.\n"
	@printf "\n$(BOLD)── Firmware (fwupd) ──$(NC)\n"
	@printf "$(CYAN)$$ omarchy update firmware$(NC)\n"
	@omarchy update firmware || printf "$(YELLOW)⚠$(NC) 'omarchy update firmware' returned non-zero (no fwupd devices? offline? expected on some hardware).\n"

verify: ## Health-check the live overlay (hyprctl, managed blocks, stow links, dev-env tools, XDG dirs)
	bash .github/scripts/verify.sh

pkg-residue: ## Read-only audit for files left behind by PACKAGE=<pkg>
	@test -n "$(PACKAGE)" || { echo "Usage: make pkg-residue PACKAGE=telegram-desktop"; exit 2; }
	bash bin/.local/bin/pkg-residue "$(PACKAGE)"
