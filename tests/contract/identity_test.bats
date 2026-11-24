#!/usr/bin/env bats
# Contract: the project name is restated in files that cannot read each other, so
# nothing but this test keeps them in agreement. build-image.yml publishes under
# the repository name; the sites below are the local fallbacks a fork edits by
# hand, and a fork that renames only some of them ships an image that
# misidentifies itself.
#
# Only sites that restate the name literally are checked. build-image.yml and
# clean.yml derive it from github.event.repository.name at runtime and cannot
# drift. README.md restates it in prose and is not checked here.

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
CONTAINERFILE="${REPO_ROOT}/Containerfile"

# The Containerfile ARG is the authoritative local value; every site must match.
image_name() {
    sed -n 's/^ARG IMAGE_NAME="\(.*\)"$/\1/p' "${CONTAINERFILE}"
}

assert_same_name() {
    local site=$1 actual=$2 expected
    expected="$(image_name)"
    if [[ "${actual}" != "${expected}" ]]; then
        printf 'FAIL: %s says %q; Containerfile ARG IMAGE_NAME says %q\n' \
            "${site}" "${actual}" "${expected}" >&2
        return 1
    fi
}

@test "identity: the Containerfile declares exactly one image name" {
    run image_name
    [ "$status" -eq 0 ]
    [ -n "${output}" ]
    [ "$(printf '%s\n' "${output}" | wc -l)" -eq 1 ]
}

@test "identity: the Containerfile name comment matches ARG IMAGE_NAME" {
    actual="$(sed -n 's/^# Name: //p' "${CONTAINERFILE}")"
    assert_same_name "Containerfile '# Name:'" "${actual}"
}

@test "identity: the Justfile IMAGE_NAME default matches ARG IMAGE_NAME" {
    actual="$(sed -n 's/^export IMAGE_NAME := env("IMAGE_NAME", "\(.*\)")$/\1/p' "${REPO_ROOT}/Justfile")"
    assert_same_name "Justfile export IMAGE_NAME" "${actual}"
}

@test "identity: artifacthub-repo.yml repositoryID matches ARG IMAGE_NAME" {
    [ -f "${REPO_ROOT}/artifacthub-repo.yml" ] || skip "this fork does not publish to Artifact Hub"
    actual="$(sed -n 's/^repositoryID: \([^ ]*\).*$/\1/p' "${REPO_ROOT}/artifacthub-repo.yml")"
    assert_same_name "artifacthub-repo.yml repositoryID" "${actual}"
}

@test "identity: clean.yml derives its package name instead of hardcoding it" {
    run grep -F 'github.event.repository.name' "${REPO_ROOT}/.github/workflows/clean.yml"
    [ "$status" -eq 0 ]
}

@test "identity: clean.yml does not restate the canonical image name" {
    run grep -F "$(image_name)" "${REPO_ROOT}/.github/workflows/clean.yml"
    [ "$status" -ne 0 ]
}

# Aurora-style pin file: image-versions.yml is the single source of truth for
# external images. Every Containerfile FROM must carry the exact image:tag@digest
# recorded there, or a Renovate bump can leave the build on the old digest.
pin_for() {
    awk -v want="$1" '
        $1 == "-" && $2 == "name:" && $3 == want { found = 1; next }
        found && $1 == "image:" { image = $2 }
        found && $1 == "tag:" { tag = $2 }
        found && $1 == "digest:" { digest = $2 }
        found && $1 == "digest:" {
            printf "%s:%s@%s\n", image, tag, digest
            exit
        }
    ' "${REPO_ROOT}/image-versions.yml"
}

from_stage() {
    if [[ -n "${1:-}" ]]; then
        grep -iE "^FROM[[:space:]]+.*[[:space:]]+[Aa][Ss][[:space:]]+${1}([[:space:]]|$)" "${CONTAINERFILE}" | head -n1 | awk '{print $2}'
    else
        grep -iE '^FROM[[:space:]]' "${CONTAINERFILE}" | grep -viE '[[:space:]]as[[:space:]]' | head -n1 | awk '{print $2}'
    fi
}

@test "pins: the base FROM matches the fedora-bootc pin" {
    [ "$(from_stage)" = "$(pin_for fedora-bootc)" ]
}

@test "pins: the common context FROM matches its pin" {
    [ "$(from_stage common)" = "$(pin_for common)" ]
}

@test "pins: the brew context FROM matches its pin" {
    [ "$(from_stage brew)" = "$(pin_for brew)" ]
}
