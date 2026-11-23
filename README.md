# yhs

oh hi stranger; have a nice day

## Releases

| Branch   | Image tag         | Audience                       |
| -------- | ----------------- | ------------------------------ |
| `main`   | `:stable-testing` | Testers and release candidates |
| `stable` | `:stable`         | Production                     |

A push to `main` publishes `:stable-testing`. Promotion to `:stable` copies the exact signed digest and does not rebuild the image.

## Image signing

Images are signed with keyless OIDC via Cosign in CI. The promotion gate checks the signature before it reports a candidate ready; it is not verified on the device. An installed system pulls updates over an unverified transport, and the inherited `policy.json` catch-all would accept the image regardless. Device-side verification would require key-based signing and a matching policy scope.

To verify a published image yourself:

```sh
cosign verify \
  --certificate-identity-regexp='^https://github\.com/kikaraage/yhs/\.github/workflows/' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/kikaraage/yhs:stable
```

## Local builds

```sh
just build              # build the container image
just build-qcow2        # build a QCOW2 disk image
just run-vm-qcow2       # boot it in a browser-based VM
just build-iso          # build an installer ISO
just test-unit          # run the test suite
```

Documentation-only changes do not trigger an image rebuild: the build and unit-test workflows ignore `**.md` on push to `main`.
