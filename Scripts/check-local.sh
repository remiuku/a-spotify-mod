#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"
test_dir=$(mktemp -d /tmp/eevee-checks.XXXXXX)
failures=0
run_swift_check() {
    local name=$1
    shift
    if swiftc "$@" -o "$test_dir/$name" >"$test_dir/$name.log" 2>&1 &&
       "$test_dir/$name" >>"$test_dir/$name.log" 2>&1; then
        printf 'PASS %s\n' "$name"
        tail -n 3 "$test_dir/$name.log"
    else
        printf 'FAIL %s\n' "$name"
        tail -n 25 "$test_dir/$name.log"
        failures=$((failures + 1))
    fi
}
run_swift_check BrowsitaSectionStripper Sources/EeveeSpotify/Premium/Helpers/BrowsitaSectionStripper.swift Tests/BrowsitaSectionStripper/main.swift
run_swift_check URLAdClassification Sources/EeveeSpotify/Shared/Models/Extensions/URL+Extension.swift Tests/URLAdClassification/main.swift
run_swift_check ASMAdProductState Sources/EeveeSpotify/Premium/Helpers/ASMAdProductStatePolicy.swift Tests/ASMAdProductState/main.swift
run_swift_check ASMCoreAd Sources/EeveeSpotify/Shared/Models/Extensions/URL+Extension.swift Sources/EeveeSpotify/Premium/Helpers/ASMCoreAdPolicy.swift Tests/ASMCoreAd/main.swift
run_swift_check ServerSidedFeaturePolicy Sources/EeveeSpotify/Premium/Helpers/ServerSidedFeaturePolicy.swift Tests/ServerSidedFeaturePolicy/main.swift
run_swift_check BundledConfigurationPolicy Sources/EeveeSpotify/Premium/Helpers/BundledConfigurationPolicy.swift Tests/BundledConfigurationPolicy/main.swift
run_swift_check CustomTabsActivation Tests/CustomTabsActivation/main.swift
run_swift_check KaraokeLineSeek Sources/EeveeSpotify/Karaoke/KaraokeLineSeek.swift Tests/KaraokeLineSeek/main.swift
run_swift_check KaraokeLookup Sources/EeveeSpotify/Karaoke/KaraokeLookupRequests.swift Tests/KaraokeLookup/main.swift
run_swift_check ASMPlaybackClock Sources/EeveeSpotify/Karaoke/ASMPlaybackClock.swift Tests/ASMPlaybackClock/main.swift
run_swift_check ASMViewerLifecycle Sources/EeveeSpotify/Karaoke/ASMLyricsPresentationState.swift Tests/ASMViewerLifecycle/main.swift
run_swift_check ASMActivityLog Sources/EeveeSpotify/Shared/Helpers/ASMActivityLogStore.swift Tests/ASMActivityLog/main.swift
run_swift_check ASMLyricsResponseDelivery Sources/EeveeSpotify/Lyrics/ASMLyricsResponseDelivery.swift Tests/ASMLyricsResponseDelivery/main.swift
if python3 Tests/ASMMainNotificationDelivery/test.py; then
    printf 'PASS ASMMainNotificationDelivery\n'
else
    failures=$((failures + 1))
fi
run_swift_check ASMDancer Sources/EeveeSpotify/Karaoke/ASMPlaybackClock.swift Sources/EeveeSpotify/Karaoke/Dancer/ASMDancerPolicy.swift Tests/ASMDancer/main.swift
run_swift_check ASMTempoEstimator Sources/EeveeSpotify/Karaoke/Dancer/ASMDancerPolicy.swift Sources/EeveeSpotify/Karaoke/Dancer/ASMTempoEstimator.swift Sources/EeveeSpotify/Karaoke/Dancer/ASMDJInfoTempoPolicy.swift Sources/EeveeSpotify/Karaoke/Library/ASMSongLyricsPolicy.swift Tests/ASMTempoEstimator/main.swift
run_swift_check ASMArtwork Sources/EeveeSpotify/Player/ASMArtworkPolicy.swift Tests/ASMArtwork/main.swift
run_swift_check ASMLookProfiles Sources/EeveeSpotify/Player/ASMArtworkPolicy.swift Sources/EeveeSpotify/Settings/Views/ASMLookProfiles.swift Tests/ASMLookProfiles/main.swift
run_swift_check ASMMenuRoute Sources/EeveeSpotify/Settings/Views/ASMMenuRoute.swift Tests/ASMMenuRoute/main.swift
run_swift_check ASMInterface Sources/EeveeSpotify/Settings/Views/ASMInterfaceMode.swift Sources/EeveeSpotify/Lyrics/Models/Settings/KaraokeOptions.swift Tests/ASMInterface/main.swift
run_swift_check KaraokeCredits Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsDto.swift Sources/EeveeSpotify/Lyrics/Models/KaraokeCreditPolicy.swift Sources/EeveeSpotify/Lyrics/Repositories/SpicyLyricsJSON.swift Sources/EeveeSpotify/Lyrics/Repositories/SpicyCreditAttribution.swift Tests/KaraokeCredits/main.swift
run_swift_check ASMTranslation -parse-as-library Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsDto.swift Sources/EeveeSpotify/Karaoke/Library/ASMSongLyricsPolicy.swift Sources/EeveeSpotify/Karaoke/Translation/ASMTranslationPolicy.swift Sources/EeveeSpotify/Karaoke/Translation/ASMTranslationCache.swift Tests/ASMTranslation/main.swift
run_swift_check ASMSongLyrics Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsDto.swift Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsStore.swift Sources/EeveeSpotify/Lyrics/Models/Settings/KaraokeOptions.swift Sources/EeveeSpotify/Karaoke/Library/ASMSongLyricsPolicy.swift Sources/EeveeSpotify/Karaoke/Library/ASMLyricsOfflineLibrary.swift Sources/EeveeSpotify/Karaoke/Library/ASMLyricsPreparedTranslations.swift Sources/EeveeSpotify/Karaoke/Library/ASMLyricRecording.swift Tests/ASMSongLyrics/main.swift
run_swift_check KaraokePlayerPreview Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsDto.swift Sources/EeveeSpotify/Lyrics/Models/Settings/KaraokeOptions.swift Sources/EeveeSpotify/Karaoke/KaraokePlayerPreviewPolicy.swift Tests/KaraokePlayerPreview/main.swift
run_swift_check ASMLyricProfiles Sources/EeveeSpotify/Shared/Models/UserDefaultPropertyWrapper.swift Sources/EeveeSpotify/Lyrics/Models/Settings/KaraokeOptions.swift Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsDto.swift Sources/EeveeSpotify/Lyrics/MildLyrics/MildSequenceMatcher.swift Sources/EeveeSpotify/Lyrics/MildLyrics/MildLyricsBlend.swift Sources/EeveeSpotify/Lyrics/MildLyrics/MildLyricsOptions.swift Sources/EeveeSpotify/Settings/Views/ASMLyricProfiles.swift Tests/ASMLyricProfiles/main.swift
run_swift_check KaraokeBackdropPolicy Sources/EeveeSpotify/Karaoke/KaraokeBackdropPolicy.swift Tests/KaraokeBackdropPolicy/main.swift
run_swift_check MildPlayful Sources/EeveeSpotify/Shared/Models/UserDefaultPropertyWrapper.swift Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsDto.swift Sources/EeveeSpotify/Lyrics/MildLyrics/MildSequenceMatcher.swift Sources/EeveeSpotify/Lyrics/MildLyrics/MildLyricsBlend.swift Sources/EeveeSpotify/Lyrics/MildLyrics/MildLyricsOptions.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/LyricsModels.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/Spring.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/Easing.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/MildPlayfulEffects.swift Tests/MildPlayful/main.swift
run_swift_check MildUncensor Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsDto.swift Sources/EeveeSpotify/Lyrics/Models/LyricsSearchQuery.swift Sources/EeveeSpotify/Lyrics/LyricsUncensorFill.swift Tests/MildUncensor/main.swift
run_swift_check MildLyrics Sources/EeveeSpotify/Shared/Models/UserDefaultPropertyWrapper.swift Sources/EeveeSpotify/Lyrics/Models/LyricsSearchQuery.swift Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsDto.swift Sources/EeveeSpotify/Lyrics/MildLyrics/MildSequenceMatcher.swift Sources/EeveeSpotify/Lyrics/MildLyrics/MildLyricsBlend.swift Sources/EeveeSpotify/Lyrics/MildLyrics/MildLyricsOptions.swift Sources/EeveeSpotify/Lyrics/MildLyrics/MildLyricsParsing.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/LyricsModels.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/TTMLParser.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/SweetLyricsAdapter.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/MildRenderPolicy.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/Spring.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/Easing.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/LyricsAnimator.swift Tests/MildLyrics/main.swift
run_swift_check SweetLyrics Sources/EeveeSpotify/Lyrics/Models/Settings/KaraokeOptions.swift Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsDto.swift Sources/EeveeSpotify/Lyrics/Repositories/SpicyLyricsJSON.swift Sources/EeveeSpotify/Lyrics/Models/KaraokeVocalMetadata.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/LyricsModels.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/SweetLyricsAdapter.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/Spring.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/Easing.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/LyricsAnimator.swift Sources/EeveeSpotify/Karaoke/SweetLyrics/SweetFrameMetrics.swift Tests/SweetLyrics/main.swift
if cc -x c -std=c11 -Wall -Wextra -Werror -ISources/EeveeSpotifyC/include \
      Sources/EeveeSpotifyC/ASMWhimsyText.m Tests/ASMWhimsy/main.c -o "$test_dir/ASMWhimsy" && \
      "$test_dir/ASMWhimsy"; then
    printf 'PASS ASMWhimsy\n'
else
    printf 'FAIL ASMWhimsy\n'
    failures=$((failures + 1))
fi
if cc -x c -std=c11 -Wall -Wextra -Werror -DASM_REBIND_TEST -ITests/ASMAudioRebinding \
      Sources/EeveeSpotifyC/SpotiAudio/Core/SGRebind.m Tests/ASMAudioRebinding/main.c -o "$test_dir/ASMAudioRebinding" && \
      "$test_dir/ASMAudioRebinding"; then
    printf 'PASS ASMAudioRebinding\n'
else
    printf 'FAIL ASMAudioRebinding\n'
    failures=$((failures + 1))
fi
if [[ ! -f "layout/Library/Application Support/EeveeSpotify.bundle/resolveconfiguration.bnk" ]]; then
    printf "SKIP ResolveConfigurationSnapshot (private binary inputs excluded)\n"
elif python3 Tests/ResolveConfigurationSnapshot/test.py; then
    printf 'PASS ResolveConfigurationSnapshot\n'
else
    printf 'FAIL ResolveConfigurationSnapshot\n'
    failures=$((failures + 1))
fi
if python3 Tests/ASMAudioOutput/test.py; then
    printf 'PASS ASMAudioOutput\n'
else
    failures=$((failures + 1))
fi
if python3 Tests/ASMTempoCapture/test.py; then
    printf 'PASS ASMTempoCapture\n'
else
    failures=$((failures + 1))
fi
if cc -std=c11 -Wall -Wextra -Werror -ISources/EeveeSpotifyC Tests/ASMControlTap/main.c -o "$test_dir/ASMControlTap" && "$test_dir/ASMControlTap"; then
    printf 'PASS ASMControlTap\n'
else
    failures=$((failures + 1))
fi
if python3 Tests/SpotifyResponsePatcher/test.py; then
    printf 'PASS SpotifyResponsePatcher\n'
else
    failures=$((failures + 1))
fi
printf '\nLogs: %s\nFailed suites: %s\n' "$test_dir" "$failures"
[[ "$failures" -eq 0 ]]
