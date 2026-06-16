#!/usr/bin/env bash
# [D-CLAUDE-CONFIG] tracked Claude Code statusline — see docs/decisions.html#D-CLAUDE-CONFIG
# Claude Code statusLine — receives session JSON on stdin, prints one styled line.
# Colors track the active Omarchy theme by reading its generated palette
# (~/.config/omarchy/current/theme/colors.toml), which Omarchy rewrites on every
# `omarchy theme set`, so the bar restyles itself with no hook or cache. Falls
# back to basic ANSI colors when the palette is absent (non-Omarchy host).
# stdin fields: .cwd / .workspace.current_dir, .model.display_name,
#               .context_window.used_percentage

input=$(cat)

# One jq pass emits the three fields on separate lines (the comma operator); three
# line reads recover them while preserving empty fields, which an IFS=tab split
# would collapse. printf '%s' (not echo) feeds the payload verbatim.
{
  IFS= read -r cwd
  IFS= read -r model
  IFS= read -r used_pct
} < <(
  printf '%s' "$input" | jq -r '
    .cwd // .workspace.current_dir // "",
    .model.display_name // "",
    (.context_window.used_percentage // "" | tostring)' 2>/dev/null
)

# ── Omarchy theme palette ──────────────────────────────────────────────
# current/theme always points at the live theme. Parse colors.toml once into a
# key→hex map (lines look like: accent = "#7aa2f7") instead of re-scanning it
# per color on every refresh.
declare -A pal
theme_file="$HOME/.config/omarchy/current/theme/colors.toml"
if [ -r "$theme_file" ]; then
  while IFS= read -r ln; do
    [[ $ln =~ ^([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*\"?#([0-9a-fA-F]{6}) ]] &&
      pal[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
  done <"$theme_file"
fi

esc=$'\033'
# Map a palette key to a truecolor SGR built from real ESC bytes. $1 = colors.toml
# key (e.g. accent, color5); $2 = fallback ANSI escape when the key/palette is missing.
theme_color() {
  local hex=${pal[$1]:-}
  if [ -n "$hex" ]; then
    printf '%s[38;2;%d;%d;%dm' "$esc" "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
  else
    printf '%s' "$2"
  fi
}

c_folder=$(theme_color accent "${esc}[0;36m") # signature accent for the path
c_branch=$(theme_color color5 "${esc}[0;35m") # purple — distinct from severity hues
c_model=$(theme_color color6 "${esc}[0;36m")  # cyan
c_low=$(theme_color color2 "${esc}[0;32m")    # green  — context < 50%
c_mid=$(theme_color color3 "${esc}[0;33m")    # yellow — context 50-79%
c_high=$(theme_color color1 "${esc}[0;31m")   # red    — context >= 80%
c_sep=$(theme_color color8 "${esc}[0;90m")    # dim — segment separators
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
  pct_int=$(LC_ALL=C printf '%.0f' "$used_pct")
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
