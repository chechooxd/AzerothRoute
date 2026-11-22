#!/usr/bin/env bash
# Copies AzerothRoute's addon folders (addon/*) into the game's AddOns folder, replacing older
# copies of each folder so no stale file stays behind.
#   bash tools/install.sh ["<path to Interface/AddOns>"]
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
dest="${1:-/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns}"
if [ ! -d "$dest" ]; then
	echo "AddOns folder not found: $dest" >&2
	echo "Pass it as the first argument." >&2
	exit 1
fi
# Folders an older AzerothRoute shipped and this one does not (Polestar's looks and skins) go.
for old in "$dest"/AzerothRoute_Looks/ "$dest"/AzerothRoute_SkinAPI/ "$dest"/AzerothRoute_Skin_*/; do
	[ -d "$old" ] || continue
	name="$(basename "$old")"
	if [ ! -d "$here/addon/$name" ]; then
		rm -rf "${dest:?}/$name"
		echo "removed $name"
	fi
done
for dir in "$here"/addon/*/; do
	name="$(basename "$dir")"
	rm -rf "${dest:?}/$name"
	cp -r "$dir" "$dest/$name"
	echo "installed $name"
done
echo "Done. Restart the game (a /reload does not load new folders)."
