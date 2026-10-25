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

mild customization is on by default in sweet lyrics. spin, no gravity, float
away and jelly start at zero. an explicitly saved on/off choice is preserved.

### does it work

current source matches the **spotify 9.1.94** preview work (`preview-stable 1`).
the animated preview is now visible on the phone. it uses a fixed three-row
card so loading and word animation do not keep changing its height. the settings
integration also avoids changing spotify's list during layout.

the personal build passed all 37 focused suites and ios compile/package checks.
this source copy still excludes private binary inputs and the built-in spicy
key; its local runner skips the bootstrap snapshot check for that reason.
phone confirmation of every feature and the intermittent settings crash is
still incomplete. [preview notes](docs/PREVIEW_UPDATE.md).
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
