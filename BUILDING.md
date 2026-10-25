# building this pile

The source layout and Makefile are retained. You need Theos, Orion, a compatible
Apple cross-toolchain/iOS SDK, and a locally built EeveeSwiftProtobuf.framework.
The Makefile has a `build-eeveeswiftprotobuf` target. Original packaging scripts
remain for reference; they assume their own environment and are not promised
to reproduce the personal WSL setup automatically.

This snapshot does not include the prebuilt SwiftProtobuf deb, app IPAs,
generated code/build products, SDKs, logs, pairing records or signing files.
Two serialized bootstrap configuration files (`resolveconfiguration*.bnk`) are
also omitted. Any code path using bundled configuration requires your own
appropriate configuration resources; this source snapshot is not advertised
as a fully provisioned reproducible build. The default Spicy Lyrics key is
empty; supply your own in settings.

`bash Scripts/check-local.sh` runs the available focused checks with a Linux Swift
toolchain plus Python, clang and the other tools referenced by that script.
Those checks do not exercise Spotify, LiveContainer, device UI or network
entitlements. No iOS build was run for this publication cleanup.

The inherited GitHub workflows are preserved under docs/upstream-workflows
as reference, outside .github/workflows, and Actions is disabled on GitHub.
Read them before deliberately enabling any automation.

The bootstrap snapshot suite is explicitly skipped without the excluded binary inputs.
