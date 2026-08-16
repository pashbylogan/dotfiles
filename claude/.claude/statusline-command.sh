#!/usr/bin/env bash
# [D-CLAUDE-CONFIG] tracked Claude Code statusline — see docs/decisions.html#D-CLAUDE-CONFIG
# Claude Code statusLine — receives session JSON on stdin, prints one styled line.
# Colors are plain ANSI so the terminal renders them from the active Omarchy
# theme; Quattro themes Claude Code itself via ~/.claude/themes/omarchy.json.
# stdin fields: .cwd / .workspace.current_dir, .model.display_name,
#               .context_window.used_percentage

# One jq pass emits the three fields on separate lines (the comma operator); three
# line reads recover them while preserving empty fields, which an IFS=tab split
# would collapse. jq inherits this script's stdin through the process
# substitution, so the payload never needs buffering through a variable.
{
  IFS= read -r cwd
  IFS= read -r model
  IFS= read -r used_pct
} < <(
  jq -r '
    .cwd // .workspace.current_dir // "",
    .model.display_name // "",
    (.context_window.used_percentage // "" | tostring)' 2>/dev/null
)

# ── colors ───────────────────────────────────────────────────────────────────
# Plain ANSI slots rather than resolved truecolor: the terminal already renders
# 0-15 from the active Omarchy theme, so these track `omarchy theme set` for
# free and cost no subprocess. Most Omarchy themes derive the accent from the
# same hex as the blue slot, but not all (hackerman, kanagawa, lumon, retro-82
# and white set a separate accent), so treat blue as blue. [D-CLAUDE-CONFIG]
esc=$'\033'
c_folder="${esc}[0;34m" # blue — the path
c_branch="${esc}[0;35m" # magenta — distinct from the severity hues
c_model="${esc}[0;36m"  # cyan
c_low="${esc}[0;32m"    # green  — context < 50%
c_mid="${esc}[0;33m"    # yellow — context 50-79%
c_high="${esc}[0;31m"   # red    — context >= 80%
c_sep="${esc}[0;90m"    # bright black — segment separators
reset="${esc}[0m"
sep_char=$'│'    # │ box-drawing vertical separator
branch_icon=$'' # nerd-font git branch glyph

# Show only the current folder's name (basename of cwd)
if [ -n "$cwd" ]; then
  folder=${cwd##*/}
  [ -z "$folder" ] && folder="/" # cwd was the filesystem root
else
  folder="?"
fi

# Git branch; fall back to a short SHA so a detached HEAD still shows context.
branch=""
if [ -n "$cwd" ]; then
  # --no-optional-locks avoids racing with other git processes in the repo
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    sha=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    [ -n "$sha" ] && branch="@$sha"
  fi
fi

# Context gauge: only when used_pct is a real number. Clamp display to [0,100]
# and pick a severity color; LC_ALL=C keeps '.'-decimals parseable in any locale.
have_ctx=0
if [[ $used_pct =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
  # printf -v, not $(...): printf is a builtin, so a command substitution would
  # fork a subshell on every render for nothing.
  LC_ALL=C printf -v pct_int '%.0f' "$used_pct"
  ((pct_int < 0)) && pct_int=0
  ((pct_int > 100)) && pct_int=100
  if ((pct_int >= 80)); then
    ctx_color=$c_high
  elif ((pct_int >= 50)); then
    ctx_color=$c_mid
  else
    ctx_color=$c_low
  fi
  have_ctx=1
fi

# Collect only the segments present this render, then join with a dim separator
parts=("${c_folder}${folder}${reset}")
[ -n "$branch" ] && parts+=("${c_branch}${branch_icon} ${branch}${reset}")
[ -n "$model" ] && parts+=("${c_model}${model}${reset}")
((have_ctx)) && parts+=("${ctx_color}ctx:${pct_int}%${reset}")

line=${parts[0]}
for seg in "${parts[@]:1}"; do
  line="${line} ${c_sep}${sep_char}${reset} ${seg}"
done

# %s (not %b): the color codes are already real ESC bytes, so backslashes in the
# folder / branch / model names are printed literally, never interpreted.
printf '%s\n' "$line"
