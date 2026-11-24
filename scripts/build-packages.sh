#!/usr/bin/env bash
# Assemble an rpm-md repository, publish it as a scratch OCI image and pin it.
#
# Usage: build-packages.sh --rpm-dir DIR --image-ref REF [--push] [--sign]
#
# --sign signs repomd.xml with cosign sign-blob (bundle stored next to it) and
# signs the pushed image with keyless cosign sign. It requires an OIDC identity
# token, so CI supplies it and local builds do not pass the flag.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "$0")/.." && pwd)

rpm_dir=
image_ref=ghcr.io/kikaraage/yhs-packages
push=0
sign=0

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --rpm-dir)
      rpm_dir=${2:?}
      shift 2
      ;;
    --image-ref)
      image_ref=${2:?}
      shift 2
      ;;
    --push)
      push=1
      shift
      ;;
    --sign)
      sign=1
      shift
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[ -n "$rpm_dir" ] || fail "--rpm-dir is required"
[ -d "$rpm_dir" ] || fail "no RPM directory at $rpm_dir"
command -v createrepo_c >/dev/null || fail "createrepo_c is required"
command -v podman >/dev/null || fail "podman is required"

work="$repo_root/build/packages-image"
rm -rf "$work"
mkdir -p "$work/context/repo/Packages"

shopt -s nullglob
rpms=("$rpm_dir"/*.rpm)
shopt -u nullglob
[ "${#rpms[@]}" -gt 0 ] || fail "no RPMs in $rpm_dir"
cp -- "${rpms[@]}" "$work/context/repo/Packages/"

createrepo_c --quiet "$work/context/repo"

if [ "$sign" -eq 1 ]; then
  command -v cosign >/dev/null || fail "cosign is required for --sign"
  cosign sign-blob --yes \
    --bundle "$work/context/repo/repodata/repomd.xml.bundle" \
    "$work/context/repo/repodata/repomd.xml"
fi

local_ref=localhost/yhs-packages:build
podman build --quiet --security-opt label=disable \
  --file "$repo_root/packages/Containerfile" \
  --tag "$local_ref" "$work/context"

if [ "$push" -eq 0 ]; then
  podman image inspect --format '{{.Id}}' "$local_ref"
  exit 0
fi

digest_file="$work/digest"
podman push --digestfile "$digest_file" "$local_ref" "${image_ref}:latest"
digest=$(cat "$digest_file")
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "invalid pushed digest: $digest"

if [ "$sign" -eq 1 ]; then
  cosign sign --yes "${image_ref}@${digest}"
fi

pin="$repo_root/config/packages.env"
tmp="$pin.new"
cat >"$tmp" <<EOF
# Digest pin for the yhs-packages OCI image consumed by the image build.
# build-packages.yml rewrites this file after publishing a new package image.
YHS_PACKAGES_DIGEST=${digest}
EOF
mv "$tmp" "$pin"

printf '%s@%s\n' "$image_ref" "$digest"
