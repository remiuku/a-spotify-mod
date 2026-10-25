# a spotify mod

:3

spotify but i kept adding stuff. then more stuff. then a dancing cat.

personal ios tweak mashup by [remiuku](https://github.com/remiuku), built on
[eeveespotify reincarnated](https://github.com/SideloadLabs/EeveeSpotifyReincarnated).
**the upstream people made a ton of this. [credits here](CREDITS.md).**

### what is in this thing

- spotify / spoti.pw / vitrine interfaces
- spotify, eevee, sweet, spoti.pw and vitrine lyric viewers
- mild lyric sources, blends, word effects and on-device translation support
- speed, pitch, jamesdsp, eq and other sound controls
- artwork motion, video covers, appearance settings
- :3 menu, boykisserfication, and a dancer with tempo sync / manual bpm
- opt-in activity recording for figuring out what broke this time

### does it work

this snapshot targets spotify **9.1.88**. latest local candidate is
`core-ad-requests 1`. its 37 focused check suites and ios build/package checks
passed before this publication cleanup. that does not mean every phone feature
is proven: the newest ad fix still needs phone confirmation. this repo snapshot
passed its available source checks too (bootstrap snapshot skipped because its
binary inputs are excluded). no ios rebuild was done for this upload.
spoti.pw/vitrine interfaces require ios 26.

spotify ai dj and other premium server features are not supplied by this mod.
expect bugs. the little guy has already caused enough troubleshooting.

### building, allegedly

source only. bring your own compatible ios sdk/toolchain, theos + orion,
and your own app input if packaging locally. no ipa or sdk is uploaded here.
see [BUILDING.md](BUILDING.md), the existing Makefile, and
[the inherited build notes](CONTRIBUTING.md).

the built-in spicy lyrics key is deliberately empty in this copy: enter your
own key in settings. binary bootstrap configurations and the prebuilt protobuf
deb are also excluded. see BUILDING.md before expecting a one-command build.

### receipts

[credits](CREDITS.md) · [licences](LICENSING.md) ·
[old eevee readme](docs/UPSTREAM_README.md) · [interface notes](INTERFACES.md)

private personal source backup. no fancy releases, no badges, no claim that i
wrote everyone else's work. the inherited workflows are parked in docs and
github actions is disabled.
