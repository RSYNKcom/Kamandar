#!/usr/bin/env sh
# Kamandar installer — symlinks the CLI onto your PATH so `kamandar` runs from
# anywhere. A symlink (not a copy) means a later `git pull` updates the command
# in place. Stdlib-only project: this needs nothing but Ruby 3.2+ and sh.
#
#   ./install.sh                 # link into ~/.local/bin
#   KAMANDAR_BIN=/usr/local/bin ./install.sh   # pick a different target dir
set -eu

SRC="$(cd "$(dirname "$0")" && pwd)/lib/kamandar.rb"
DEST="${KAMANDAR_BIN:-$HOME/.local/bin}"

if [ ! -f "$SRC" ]; then
  echo "install: can't find $SRC" >&2
  exit 1
fi

command -v ruby >/dev/null 2>&1 || {
  echo "install: ruby not found — Kamandar needs Ruby 3.2+." >&2
  exit 1
}

mkdir -p "$DEST"
chmod +x "$SRC"
ln -sf "$SRC" "$DEST/kamandar"
echo "linked $DEST/kamandar -> $SRC"

case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo "note: $DEST is not on your PATH — add it, e.g.:"
     echo "      echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.zshrc" ;;
esac

echo "next: run \`kamandar --init\` to save your token once."
