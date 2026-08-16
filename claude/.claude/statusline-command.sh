#!/usr/bin/env bash
# [D-CLAUDE-CONFIG] tracked Claude Code statusline — see docs/decisions.html#D-CLAUDE-CONFIG
# Claude Code statusLine — receives session JSON on stdin, prints one styled line.
# Colors track the active Omarchy theme through Quattro's palette resolver, so
# aliases and fallbacks behave exactly like the shell. Falls back to basic ANSI
# colors when the resolver is absent (non-Omarchy host).
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

# ── Omarchy theme palette ──────────────────────────────────────────────
# The resolver emits one tab-separated key/value pair per palette role.
declare -A pal
if command -v omarchy-theme-color >/dev/null 2>&1; then
  while IFS=$'\t' read -r key value; do
    if [[ $value =~ ^#([0-9a-fA-F]{3})$ ]]; then
      short=${BASH_REMATCH[1]}
      pal["$key"]="${short:0:1}${short:0:1}${short:1:1}${short:1:1}${short:2:1}${short:2:1}"
    elif [[ $value =~ ^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$ ]]; then
      pal["$key"]="${BASH_REMATCH[1]}"
    fi
  done < <(omarchy-theme-color --all 2>/dev/null)
fi
unset short

esc=$'\033'
# Map a palette key to a truecolor SGR built from real ESC bytes. $1 = variable
# to assign, $2 = palette key (e.g. accent, color5), $3 = fallback ANSI escape
# when it is missing. Assigning via printf -v keeps this whole block fork-free;
# a command substitution per color would cost seven subshells on every render.
theme_color() {
  local hex=${pal[$2]:-}
  if [ -n "$hex" ]; then
    printf -v "$1" '%s[38;2;%d;%d;%dm' "$esc" "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
  else
    printf -v "$1" '%s' "$3"
  fi
}

# Declared here so the indirect `printf -v` assignments stay visible to static
# analysis; theme_color is what actually fills each one in.
c_folder='' c_branch='' c_model='' c_low='' c_mid='' c_high='' c_sep=''
theme_color c_folder accent "${esc}[0;36m" # signature accent for the path
theme_color c_branch color5 "${esc}[0;35m" # purple — distinct from severity hues
theme_color c_model color6 "${esc}[0;36m"  # cyan
theme_color c_low color2 "${esc}[0;32m"    # green  — context < 50%
theme_color c_mid color3 "${esc}[0;33m"    # yellow — context 50-79%
theme_color c_high color1 "${esc}[0;31m"   # red    — context >= 80%
theme_color c_sep color8 "${esc}[0;90m"    # dim — segment separators
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
