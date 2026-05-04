#!/usr/bin/env bash
# Called by pacman hook after xkeyboard-config upgrade.
# Requires prior `install-arch.sh` run with system-wide file installation:
#   sudo install -dm755 /usr/local/share/birman-xkb
#   sudo cp -r symbols rules helper /usr/local/share/birman-xkb/
set -euo pipefail

SRC=/usr/local/share/birman-xkb

if [[ ! -d "$SRC" ]]; then
    echo "birman-xkb-reapply: source directory $SRC not found, skipping." >&2
    exit 0
fi

# Re-append symbol blocks if they were wiped by the package upgrade
grep -q "typo-birman-en" /usr/share/X11/xkb/symbols/us \
    || cat "$SRC/symbols/typo-birman-en" >> /usr/share/X11/xkb/symbols/us

grep -q "typo-birman-ru" /usr/share/X11/xkb/symbols/ru \
    || cat "$SRC/symbols/typo-birman-ru" >> /usr/share/X11/xkb/symbols/ru

# Re-register in evdev.lst
sed -i -E '/[[:space:]]+typo-birman-(en|ru)[[:space:]]/d' \
    /usr/share/X11/xkb/rules/evdev.lst
sed -i -E \
    's/(! variant)/\1\n  typo-birman-en         us: English (Typographic by Ilya Birman)\n  typo-birman-ru         ru: Russian (Typographic by Ilya Birman)/' \
    /usr/share/X11/xkb/rules/evdev.lst

# Re-register in evdev.xml
python3 "$SRC/helper/xmladd.py" \
    /usr/share/X11/xkb/rules/evdev.xml \
    "$SRC/rules/variant_en" \
    "$SRC/rules/variant_ru" \
    /tmp/evdev_birman_hook.xml
mv /tmp/evdev_birman_hook.xml /usr/share/X11/xkb/rules/evdev.xml

echo "birman-xkb-reapply: layouts re-applied successfully."
