#!/usr/bin/env bash
# Remove Birman typography layouts from Arch Linux + KDE Plasma 6
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "→ $*"; }
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }

# --- XKB symbol blocks ---

step "Removing XKB symbol blocks..."

if grep -q "typo-birman-en" /usr/share/X11/xkb/symbols/us; then
    sudo python3 "$BASE/helper/symbolsremove.py" \
        /usr/share/X11/xkb/symbols/us typo-birman-en
    ok "typo-birman-en removed from symbols/us"
else
    ok "typo-birman-en not found in symbols/us — skipped"
fi

if grep -q "typo-birman-ru" /usr/share/X11/xkb/symbols/ru; then
    sudo python3 "$BASE/helper/symbolsremove.py" \
        /usr/share/X11/xkb/symbols/ru typo-birman-ru
    ok "typo-birman-ru removed from symbols/ru"
else
    ok "typo-birman-ru not found in symbols/ru — skipped"
fi

# --- evdev.lst ---

step "Cleaning evdev.lst..."
sudo sed -i -E '/[[:space:]]+typo-birman-(en|ru)[[:space:]]/d' \
    /usr/share/X11/xkb/rules/evdev.lst
ok "evdev.lst cleaned"

# --- evdev.xml ---

step "Cleaning evdev.xml..."
sudo python3 "$BASE/helper/xmlremove.py" \
    /usr/share/X11/xkb/rules/evdev.xml \
    /tmp/evdev_clean.xml
sudo mv /tmp/evdev_clean.xml /usr/share/X11/xkb/rules/evdev.xml
ok "evdev.xml cleaned"

# --- KDE Plasma: kxkbrc ---

step "Reverting KDE keyboard configuration..."

KXKBRC="$HOME/.config/kxkbrc"
BACKUP="${KXKBRC}.bak"

if [[ -f "$BACKUP" ]]; then
    read -r -p "  Restore kxkbrc from backup? [Y/n] " _r
    _r="${_r,,}"
    if [[ "$_r" =~ ^(y|yes)$ ]] || [[ -z "$_r" ]]; then
        mv "$BACKUP" "$KXKBRC"
        ok "kxkbrc restored from backup"
    else
        warn "Backup kept at $BACKUP — kxkbrc not changed"
    fi
else
    # No backup: reset to system default (English only, no custom variants)
    kwriteconfig6 --file kxkbrc --group Layout --key Use             "true"
    kwriteconfig6 --file kxkbrc --group Layout --key LayoutList      "us"
    kwriteconfig6 --file kxkbrc --group Layout --key VariantList     ""
    kwriteconfig6 --file kxkbrc --group Layout --key Options         ""
    kwriteconfig6 --file kxkbrc --group Layout --key ResetOldOptions "true"
    ok "kxkbrc reset to English (us) only"
fi

# --- Alt+Shift shortcut ---

KGLOBAL="$HOME/.config/kglobalshortcutsrc"
if grep -q "typo-birman\|Keyboard Layout Switcher" "$KGLOBAL" 2>/dev/null; then
    read -r -p "  Remove Alt+Shift layout shortcut from kglobalshortcutsrc? [Y/n] " _s
    _s="${_s,,}"
    if [[ "$_s" =~ ^(y|yes)$ ]] || [[ -z "$_s" ]]; then
        kwriteconfig6 --file kglobalshortcutsrc \
            --group "KDE Keyboard Layout Switcher" \
            --key "Switch to Next Keyboard Layout" \
            "none,none,Switch to Next Keyboard Layout"
        ok "Layout toggle shortcut cleared"
    fi
fi

# --- Pacman hook (if installed) ---

HOOK=/etc/pacman.d/hooks/99-birman-xkb.hook
REAPPLY=/usr/local/bin/birman-xkb-reapply
SHARE=/usr/local/share/birman-xkb

if [[ -f "$HOOK" ]] || [[ -f "$REAPPLY" ]] || [[ -d "$SHARE" ]]; then
    echo ""
    warn "Found system-wide hook installation. Remove it too?"
    [[ -f "$HOOK"    ]] && echo "  $HOOK"
    [[ -f "$REAPPLY" ]] && echo "  $REAPPLY"
    [[ -d "$SHARE"   ]] && echo "  $SHARE"
    read -r -p "  Remove? [y/N] " _h
    if [[ "${_h,,}" =~ ^(y|yes)$ ]]; then
        [[ -f "$HOOK"    ]] && sudo rm -f "$HOOK"    && ok "Hook removed"
        [[ -f "$REAPPLY" ]] && sudo rm -f "$REAPPLY" && ok "Reapply script removed"
        [[ -d "$SHARE"   ]] && sudo rm -rf "$SHARE"  && ok "Shared files removed"
    fi
fi

# --- Reload KWin ---

echo ""
step "Reloading KWin..."
if qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null; then
    ok "KWin reloaded"
else
    warn "qdbus6 call failed — log out and back in to apply changes"
fi

echo ""
echo -e "${GREEN}Done.${NC} Birman layouts removed."
