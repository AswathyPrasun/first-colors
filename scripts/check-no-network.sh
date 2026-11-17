#!/bin/sh
# Fails if any network API or URL appears in app or test sources.
# The app must stay 100% offline (CLAUDE.md §2). License texts are excluded.
cd "$(dirname "$0")/.." || exit 1
matches=$(grep -RInE 'URLSession|NWConnection|WKWebView|SFSafariViewController|https?://' \
  App Coordinators Features Core Tests \
  --include='*.swift' --include='*.json' 2>/dev/null)
if [ -n "$matches" ]; then
  echo "error: network code or URLs found:"
  echo "$matches"
  exit 1
fi
echo "No network code found."
