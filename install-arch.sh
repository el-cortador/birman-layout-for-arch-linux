#!/usr/bin/env bash
# Install Birman typography layouts on Arch Linux + KDE Plasma 6 + Wayland
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "→ $*"; }
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}Error:${NC} $*" >&2; exit 1; }

# --- Preflight checks ---

command -v pacman       &>/dev/null || fail "pacman not found — Arch Linux only."
command -v plasmashell  &>/dev/null || fail "plasmashell not found — install KDE Plasma."
command -v kwriteconfig6 &>/dev/null || fail "kwriteconfig6 not found — install package 'kconfig'."
command -v python3      &>/dev/null || fail "python3 not found."

if [[ "${XDG_SESSION_TYPE:-}" != "wayland" ]]; then
    warn "XDG_SESSION_TYPE='${XDG_SESSION_TYPE:-unset}' (expected 'wayland')."
    read -r -p "  Continue anyway? [y/N] " _c
    [[ "${_c,,}" =~ ^(y|yes)$ ]] || { echo "Aborted."; exit 1; }
fi

# --- XKB symbol files ---

step "Installing XKB symbol files..."

if ! grep -q "typo-birman-en" /usr/share/X11/xkb/symbols/us; then
    sudo bash -c "cat '$BASE/symbols/typo-birman-en' >> /usr/share/X11/xkb/symbols/us"
    ok "typo-birman-en appended to symbols/us"
else
    ok "typo-birman-en already present — skipped"
fi

if ! grep -q "typo-birman-ru" /usr/share/X11/xkb/symbols/ru; then
    sudo bash -c "cat '$BASE/symbols/typo-birman-ru' >> /usr/share/X11/xkb/symbols/ru"
    ok "typo-birman-ru appended to symbols/ru"
else
    ok "typo-birman-ru already present — skipped"
fi

# --- XKB rules: evdev.lst ---

step "Registering variants in evdev.lst..."
# Remove stale entries, then re-insert after the "! variant" header
sudo sed -i -E '/[[:space:]]+typo-birman-(en|ru)[[:space:]]/d' \
    /usr/share/X11/xkb/rules/evdev.lst
sudo sed -i -E \
    's/(! variant)/\1\n  typo-birman-en         us: English (Typographic by Ilya Birman)\n  typo-birman-ru         ru: Russian (Typographic by Ilya Birman)/' \
    /usr/share/X11/xkb/rules/evdev.lst
ok "evdev.lst updated"

# --- XKB rules: evdev.xml ---

step "Registering variants in evdev.xml..."
sudo python3 "$BASE/helper/xmladd.py" \
    /usr/share/X11/xkb/rules/evdev.xml \
    "$BASE/rules/variant_en" \
    "$BASE/rules/variant_ru" \
    /tmp/evdev_birman.xml
sudo mv /tmp/evdev_birman.xml /usr/share/X11/xkb/rules/evdev.xml
ok "evdev.xml updated"

# --- KDE Plasma: kxkbrc ---

step "Configuring KDE keyboard settings (~/.config/kxkbrc)..."

KXKBRC="$HOME/.config/kxkbrc"
if [[ -f "$KXKBRC" ]]; then
    cp "$KXKBRC" "${KXKBRC}.bak"
    warn "Backed up existing config → ${KXKBRC}.bak"
fi

# kwriteconfig6 writes to ~/.config/<filename>
kwriteconfig6 --file kxkbrc --group Layout --key Use             "true"
kwriteconfig6 --file kxkbrc --group Layout --key Model           "pc105"
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList      "us,ru"
kwriteconfig6 --file kxkbrc --group Layout --key VariantList     "typo-birman-en,typo-birman-ru"
kwriteconfig6 --file kxkbrc --group Layout --key Options         "lv3:ralt_switch"
kwriteconfig6 --file kxkbrc --group Layout --key ResetOldOptions "true"
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames    ","
ok "kxkbrc configured with us+typo-birman-en and ru+typo-birman-ru"

# --- Optional: layout toggle shortcut (Alt+Shift) ---

echo ""
read -r -p "Set Alt+Shift as layout toggle shortcut? [Y/n] " _r
_r="${_r,,}"
if [[ "$_r" =~ ^(y|yes)$ ]] || [[ -z "$_r" ]]; then
    kwriteconfig6 --file kglobalshortcutsrc \
        --group "KDE Keyboard Layout Switcher" \
        --key "Switch to Next Keyboard Layout" \
        "Alt+Shift,none,Switch to Next Keyboard Layout"
    ok "Alt+Shift shortcut written to kglobalshortcutsrc"
    warn "Shortcut takes effect after re-login or kglobalaccel restart."
fi

# --- Reload KWin compositor ---

echo ""
step "Requesting KWin reload (Wayland compositor)..."
if qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null; then
    ok "KWin reconfigured successfully"
else
    warn "qdbus6 call failed — compositor reload skipped"
fi

echo ""
echo -e "${GREEN}Done!${NC} New layouts are active."
echo "If they don't appear in the system tray — log out and back in."
echo ""
echo "To survive xkeyboard-config package upgrades, install the pacman hook:"
echo "  sudo install -Dm644 '$BASE/hooks/99-birman-xkb.hook' /etc/pacman.d/hooks/99-birman-xkb.hook"
echo "  sudo install -Dm755 '$BASE/hooks/birman-xkb-reapply.sh' /usr/local/bin/birman-xkb-reapply"
echo "  sudo install -dm755 /usr/local/share/birman-xkb"
echo "  sudo cp -r '$BASE/symbols' '$BASE/rules' '$BASE/helper' /usr/local/share/birman-xkb/"
