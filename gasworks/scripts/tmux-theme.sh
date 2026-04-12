#!/bin/sh
# tmux-theme.sh — Gasworks extension of gastown's tmux theme.
# Usage: tmux-theme.sh <session> <agent> <gastown-config-dir>
#
# Adds gasworks-specific roles (pm, architect, orchestrator, etc.)
# on top of gastown's base theme. Gastown is called first for base
# roles; if the agent matches a gasworks role, we override afterward.
#
# Gastown is upstream — we never modify its files. This wrapper is
# the extension point for all gasworks role theming.
SESSION="$1" AGENT="$2" GASTOWN_CONFIGDIR="$3"

# Run gastown's theme first — handles base roles (mayor, deacon, etc.)
"$GASTOWN_CONFIGDIR/scripts/tmux-theme.sh" "$SESSION" "$AGENT" "$GASTOWN_CONFIGDIR"

# Socket-aware tmux command (uses GC_TMUX_SOCKET when set).
gcmux() { tmux ${GC_TMUX_SOCKET:+-L "$GC_TMUX_SOCKET"} "$@"; }

# ── Determine gasworks role ─────────────────────────────────────────────
# Only match gasworks-specific roles. If no match, gastown's theme stands.
role=""
case "$AGENT" in
    */pm|*--pm)                                     role="pm" ;;
    */orchestrator|*--orchestrator)                  role="orchestrator" ;;
    */architect|*--architect)                        role="architect" ;;
    */product-researcher-*|*--product-researcher-*)  role="researcher" ;;
    */ux-designer|*--ux-designer)                    role="ux-designer" ;;
    */staff-engineer|*--staff-engineer)               role="staff-engineer" ;;
    */maggie|*--maggie|*/marcus|*--marcus)            role="crew" ;;
esac

[ -z "$role" ] && exit 0

# ── Gasworks color theme ────────────────────────────────────────────────
case "$role" in
    pm)              bg="#3d1f5a" fg="#e0e0e0" ;;  # violet
    orchestrator)    bg="#5a3d1f" fg="#e0e0e0" ;;  # amber
    architect)       bg="#1f3d5a" fg="#e0e0e0" ;;  # navy
    researcher)      bg="#1f5a3d" fg="#e0e0e0" ;;  # emerald
    ux-designer)     bg="#5a1f4d" fg="#e0e0e0" ;;  # magenta
    staff-engineer)  bg="#1f4a5a" fg="#e0e0e0" ;;  # steel blue
    crew)            bg="#2d5a3d" fg="#e0e0e0" ;;  # forest
esac

# ── Gasworks role icon ──────────────────────────────────────────────────
case "$role" in
    pm)              icon="📋" ;;
    orchestrator)    icon="🎯" ;;
    architect)       icon="🏗" ;;
    researcher)      icon="🔬" ;;
    ux-designer)     icon="🎨" ;;
    staff-engineer)  icon="🔧" ;;
    crew)            icon="👷" ;;
esac

# ── Apply gasworks overrides ────────────────────────────────────────────
gcmux set-option -t "$SESSION" status-style "bg=$bg,fg=$fg"
gcmux set-option -t "$SESSION" status-left "$icon $AGENT "
