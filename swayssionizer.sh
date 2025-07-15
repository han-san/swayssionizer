#! /bin/sh
#
# Kind of similar to tmux-sessionizer, but replacing tmux with sway.
#
# Will open some directory using kitty, or switch to the kitty instance
# that was opened for that same directory previously if there already is
# one.
#
# Requires that the environment variables SWAYSSIONIZER_SEARCH_DIRS and
# SWAYSSIONIZER_0_DIR to SWAYSSIONIZER_3_DIR are set in the config file
# at $XDG_CONFIG_HOME/swayssionizer/config.
#
# DESIGN:
# A session is a workspace containing a window that has been marked
# with some absolute path. Sessions can be either active or inactive,
# and only one session can be active at a time. An active session means
# that the window with the absolute path mark also has an "active" mark.
#
# When the user chooses a directory the program will either switch to
# the session already marked with that directory if there is one, or
# create a new session. If there already is an active session when a new
# one is switched to or created, the active session will be turned
# inactive by removing the active mark and moving all windows on its
# workspace to a new workspace with the name of the absolute path it's
# associated with. The new active session's windows are then moved to
# the workspace where the old active session used to be. This way, one
# workspace will always contain the active session.

set -eu

script_name=$(basename "$0")

# If you want to use a different terminal or menu launcher, edit the
# following two variables and functions.
term_cmd=kitty
menu_cmd=tofi

# $1: Launch directory.
# $2: Session mark.
# $3: Active mark.
launch_new_session() {
  # The important thing is that the two marks are properly attached to
  # the newly spawned terminal in some way. Trying to get it to work
  # with other terminals was a hassle, so good luck if that's what you
  # want :).
  swaymsg "exec $term_cmd --hold --directory \"$1\" swaymsg 'mark --add \"$2\", mark --add \"$3\"'"
}

# Reads a '\n'-separated list from stdin.
show_projects_menu() {
  "$menu_cmd" --prompt-text="Open project:"
}

exists() {
  command -v "$1" >/dev/null 2>&1
}

log_error() {
  printf "%b\n" "$1" 1>&2

  if exists notify-send; then
    notify-send -u critical "$script_name" "$1"
  fi
}

# $1: List of directories to search (colon-separated).
find_projects() (
  IFS=:
  for f in $1; do
    find "$f" -mindepth 1 -maxdepth 1 -type d -a ! -path "*/\.*" -prune -print
  done
)

log_usage() {
  log_error "Usage: $script_name [session_number]\n\n  -h, --help  Show this help list"
}

for arg in "$@"; do
  case "$arg" in
  "-h" | "--help")
    log_usage
    exit 1
    ;;
  esac
done

missing_dep=""

if ! exists "$term_cmd"; then
  missing_dep="$missing_dep\n$term_cmd"
fi

if ! exists "$menu_cmd"; then
  missing_dep="$missing_dep\n$menu_cmd"
fi

if ! exists swaymsg; then
  missing_dep="$missing_dep\nswaymsg"
fi

if [ -n "$missing_dep" ]; then
  log_error "The following dependencies are missing:\n$missing_dep"
  exit 1
fi

if [ $# -gt 1 ]; then
  log_usage
  exit 1
fi

sessions_file="${XDG_CONFIG_HOME:-$HOME/.config}/${script_name%.sh}/config"
if ! [ -f "$sessions_file" ]; then
  log_error "FATAL: $script_name config file [$sessions_file] is not a proper file."
  exit 1
fi

# shellcheck source=/dev/null
. "$sessions_file"

# We either select the specified project or let the user fuzzy search all their projects.
dir=""
selection="${1:-}"
case "$selection" in
0)
  dir=$SWAYSSIONIZER_0_DIR
  ;;
1)
  dir=$SWAYSSIONIZER_1_DIR
  ;;
2)
  dir=$SWAYSSIONIZER_2_DIR
  ;;
3)
  dir=$SWAYSSIONIZER_3_DIR
  ;;
"")

  dir=$(find_projects "$SWAYSSIONIZER_SEARCH_DIRS" | show_projects_menu)

  if [ -z "$dir" ]; then
    # The user cancelled the selection.
    exit 0
  fi
  ;;
*)
  log_error "FATAL: Unknown selection [$selection] passed as argument."
  exit 1
  ;;
esac

if [ -z "$dir" ]; then
  log_error "FATAL: No directory selected after case."
  exit 1
fi

active_mark="swayssionizer-active"
session_mark_unique_prefix="swayssionizer:"
session_workspace="$dir"
session_mark="$session_mark_unique_prefix$dir"
default_workspace="${SWAYSSIONIZER_DEFAULT_WORKSPACE:-1}"

# If we have a window with both marks, we can just switch to it no problem.
if swaymsg -t get_tree |
  jq -e \
    --arg active_mark "$active_mark" \
    --arg session_mark "$session_mark" \
    '.. |
       select(objects and contains({
         marks: [$active_mark, $session_mark]
       }))' \
    >/dev/null; then
  swaymsg \[con_mark="^$active_mark\$"\] focus
  exit 0
fi

# Clean up the workspace with the current active session.
if swaymsg \[con_mark="^$active_mark\$"\] focus >/dev/null; then
  old_session_mark=$(
    swaymsg -t get_tree |
      jq -r \
        --arg active_mark "$active_mark" \
        --arg session_mark_unique_prefix "$session_mark_unique_prefix" \
        '.. |
           select(objects and contains({
             marks: [$active_mark]
           })) |
           .marks[] |
           select(startswith($session_mark_unique_prefix))'
  )
  if [ -z "$old_session_mark" ]; then
    log_error "FATAL: Active session doesn't have its unique id mark."
    exit 1
  fi
  # Move the current active session windows to their own workspace.
  old_session_workspace="${old_session_mark#"$session_mark_unique_prefix"}"
  swaymsg \[workspace=__focused__\] move workspace "$old_session_workspace"
else
  # There is no active session, so we go with the default workspace.
  swaymsg workspace "$default_workspace"
fi

# Boot up a new active workspace, either by moving an existing session
# to it or launching a new one.
if swaymsg \[workspace="^$session_workspace\$"\] move workspace current >/dev/null; then
  swaymsg "[con_mark=\"^$session_mark\$\"] focus, mark --add \"$active_mark\""
else
  launch_new_session "$dir" "$session_mark" "$active_mark"
fi
