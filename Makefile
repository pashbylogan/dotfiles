# Keep repo checks centralized so local runs and CI cannot drift. [D-CI]

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

# ── file sets ────────────────────────────────────────────────────────────────
# Include sourced fragments explicitly because shell globs won't discover them.
SHELL_FILES := install $(wildcard bin/.local/bin/*) \
	bash/.config/dotfiles/shell.sh \
	bash/.config/dotfiles/shell.local.sh.example \
	$(wildcard .github/scripts/*.sh)
PRETTIER_GLOBS := docs/*.html docs/registry.json
DOCS_CHECK     := .github/scripts/check_docs.py
JQ_FILTERS     := $(wildcard waybar/*.jq)

.DEFAULT_GOAL := help
.PHONY: help ci fmt tools update update-firmware verify

# ── checks ───────────────────────────────────────────────────────────────────
help: ## Show this menu
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z0-9_-]+:.*## /{printf "  \033[36m%-6s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Run 'make ci' before committing — it's exactly what GitHub Actions runs."

ci: ## Run the full gate: shellcheck + shfmt + prettier + jq filter parse + docs integrity
	shellcheck $(SHELL_FILES)
	shfmt -d $(SHFMT_FLAGS) $(SHELL_FILES)
	$(PRETTIER) --check $(PRETTIER_GLOBS)
	@# Smoke-check each jq filter against an empty-object fixture so syntax
	@# errors + obvious filter bugs surface here, not at ./install time.
	@for f in $(JQ_FILTERS); do echo '{}' | jq -f "$$f" >/dev/null || { echo "jq filter failed: $$f"; exit 1; }; done
	@if [ -n "$(JQ_FILTERS)" ]; then echo "jq filters parse + smoke pass: $(JQ_FILTERS)"; fi
	python3 $(DOCS_CHECK)
	@echo "OK - all checks passed"

fmt: ## Auto-fix formatting in place (shfmt + prettier)
	shfmt -w $(SHFMT_FLAGS) $(SHELL_FILES)
	$(PRETTIER) --write $(PRETTIER_GLOBS)

tools: ## Show required tools + how to install them on Omarchy
	@echo "Expected (CI pins): shellcheck $(SHELLCHECK_VERSION), shfmt $(SHFMT_VERSION), prettier 3.8.3"
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck --version | awk '/version:/{print "  shellcheck: "$$2}'; else echo "  shellcheck: MISSING -> re-run ./install (tracked in packages.txt) or 'omarchy pkg add shellcheck'"; fi
	@if command -v shfmt >/dev/null 2>&1; then echo "  shfmt:      $$(shfmt --version)"; else echo "  shfmt:      MISSING -> re-run ./install (tracked in packages.txt) or 'omarchy pkg add shfmt'"; fi
	@if command -v npx >/dev/null 2>&1; then echo "  node/npx:   present (prettier runs via '$(PRETTIER)')"; else echo "  node/npx:   MISSING -> install node via mise"; fi
	@if command -v python3 >/dev/null 2>&1; then echo "  python3:    $$(python3 --version | awk '{print $$2}')"; else echo "  python3:    MISSING"; fi

# ── machine maintenance ──────────────────────────────────────────────────────
# Keep package updates separate from firmware/self-managed channels because
# their prompts, reboot behavior, and failure modes are different. [D-CI]
update: ## Update packages/Omarchy migrations, then `make verify`
	@printf "Note: if 'omarchy update -y' triggers a reboot, the verify step below will NOT run automatically — re-invoke 'make update' afterwards.\n\n"
	@# Still run verify after non-reboot updater failures so drift is visible.
	@printf "$$ omarchy update -y\n"
	@omarchy update -y || printf "\nWARN: 'omarchy update -y' returned non-zero (benign if a reboot was requested).\n"
	@printf "\nPost-update verify:\n"
	@printf "$$ $(MAKE) --no-print-directory verify\n"
	@$(MAKE) --no-print-directory verify

# Firmware and self-managed tools are intentionally opt-in; they can have
# device-specific reboot/power-cycle outcomes unlike package updates. [D-CI]
update-firmware: ## Update firmware and self-managed non-package tools (fwupd + uv)
	@printf "Note: firmware and self-managed updater outcomes are not package-like; review prompts carefully.\n\n"
	@printf "\n$$ omarchy update firmware\n"
	@omarchy update firmware || printf "\nWARN: 'omarchy update firmware' returned non-zero (no fwupd devices? offline? expected on some hardware).\n"
	@printf "\nUpdating uv...\n"
	@if command -v uv >/dev/null 2>&1; then printf "$$ uv self update\n"; uv self update || printf "\nWARN: 'uv self update' returned non-zero.\n"; else printf "SKIP: uv not found on PATH.\n"; fi
	@printf "\nNote: JetBrains IDEs managed by jetbrains-toolbox update via Toolbox's own UI.\n"

verify: ## Health-check the live overlay (hyprctl, managed blocks, stow links, dev-env tools, XDG dirs)
	bash .github/scripts/verify.sh
