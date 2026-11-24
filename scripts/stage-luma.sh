#!/usr/bin/env bash
# Stage the pinned Luma checkout and overlay yhs's Fedora 45 deltas.
# The submodule stays pristine: every yhs change to package inputs, patches or
# build scripts lives under overlay/luma/ and is copied over the staged tree.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source_dir="$repo_root/upstream/luma"
overlay_dir="$repo_root/overlay/luma"
stage_dir=${1:-"$repo_root/build/luma-stage"}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[ -d "$source_dir" ] || fail "Luma submodule is not checked out at $source_dir"
[ -f "$source_dir/scripts/os/build-image.sh" ] || fail "unexpected Luma checkout at $source_dir"

rm -rf "$stage_dir"
mkdir -p "$stage_dir"
cp -a "$source_dir/." "$stage_dir/"
rm -rf "$stage_dir/.git"
if [ -d "$overlay_dir" ]; then
  cp -a "$overlay_dir/." "$stage_dir/"
fi

printf '%s\n' "$stage_dir"
