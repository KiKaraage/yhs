# yhs-packages

This directory defines the OCI image that carries yhs's RPM repository. The image is built from `scratch` and contains only the output of `createrepo_c`: `Packages/*.rpm` and `repodata/*`. No shell, no package manager, no configuration.

The image is published as `ghcr.io/kikaraage/yhs-packages` and pinned by digest in [config/packages.env](../config/packages.env). The final bootc image consumes the pin, so a package change cannot silently change the OS build.

`repomd.xml` is signed with `cosign sign-blob --bundle`, and the image itself is signed with keyless `cosign sign`. Both signatures are checked in CI promotion, not on the device.
