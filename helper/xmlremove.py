#!/usr/bin/env python3
# Remove typo-birman-* variants from evdev.xml (used by uninstall-arch.sh)

import sys
import xml.etree.ElementTree as ET

if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} <evdev.xml> <output.xml>", file=sys.stderr)
    sys.exit(1)

xml_file, output = sys.argv[1], sys.argv[2]

tree = ET.parse(xml_file)
root = tree.getroot()

for layout in root.findall("./layoutList/layout"):
    name = layout.findtext("./configItem/name")
    if name in ("us", "ru"):
        variant_list = layout.find("./variantList")
        if variant_list is not None:
            for variant in list(variant_list.findall("./variant")):
                vname = variant.findtext("./configItem/name") or ""
                if "typo-birman" in vname:
                    variant_list.remove(variant)

tree.write(output, encoding="unicode", xml_declaration=False)
