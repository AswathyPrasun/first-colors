#!/bin/sh
# Renders Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png from apple.svg,
# reusing the app's own SVG parser. Placeholder until a designed icon exists.
set -e
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/make_app_icon"
swiftc -O -o "$OUT" scripts/appicon/main.swift \
  Core/Drawing/SVGPathParser.swift Core/Drawing/SVGDocumentParser.swift Core/Drawing/Drawing.swift \
  Core/Models/ContentItem.swift Core/Models/Category.swift Core/DesignSystem/DSColor.swift Core/Support/Log.swift
"$OUT" "$PWD"
