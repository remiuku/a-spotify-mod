// Spotify's streaming quality, read and set through its own preferences object (Shared/SpotifyPrefs).
#import "Core/ASMVitrineCore.h"
#import "Shared/SpotifyPrefs/SpotifyPrefs.h"
#import "LosslessQuality.h"
#import "ASMVitrineLossless.h"

#define ASMVitrineKeyLosslessSavedQuality @"asm.interface.vitrine.lossless.savedQuality"   // [cellular, Wi-Fi] while lowered
static const NSInteger kLowest = 1;

BOOL ASMVitrineStreamQuality(NSInteger *metered, NSInteger *nonMetered) {
    SPTPreferences *preferences = ASMVitrineSpotifyPreferences();
    if (!preferences) return NO;
    *metered = preferences.audioPlayBitrate;
    *nonMetered = preferences.audioPlayBitrateNonMetered;
    return YES;
}

BOOL ASMVitrineSetStreamQuality(NSInteger metered, NSInteger nonMetered) {
    SPTPreferences *preferences = ASMVitrineSpotifyPreferences();
    if (!preferences) return NO;
    preferences.audioPlayBitrate = metered;
    preferences.audioPlayBitrateNonMetered = nonMetered;
    return YES;
}

void ASMVitrineLosslessLowerQuality(BOOL lower) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSArray<NSNumber *> *saved = [defaults arrayForKey:ASMVitrineKeyLosslessSavedQuality];
    NSInteger metered, nonMetered;
    if (!ASMVitrineStreamQuality(&metered, &nonMetered)) return;
    if (lower && !saved) {
        if (metered == kLowest && nonMetered == kLowest) return;
        [defaults setObject:@[@(metered), @(nonMetered)] forKey:ASMVitrineKeyLosslessSavedQuality];
        ASMVitrineSetStreamQuality(kLowest, kLowest);
        ASMVitrineLog(@"lossless: Spotify's quality lowered for the next track (was %ld, %ld)", (long)metered, (long)nonMetered);
    } else if (!lower && saved.count == 2) {
        if (metered == kLowest && nonMetered == kLowest) ASMVitrineSetStreamQuality(saved[0].integerValue, saved[1].integerValue);
        [defaults removeObjectForKey:ASMVitrineKeyLosslessSavedQuality];
        ASMVitrineLog(@"lossless: Spotify's quality back to %ld, %ld", (long)saved[0].integerValue, (long)saved[1].integerValue);
    }
}
