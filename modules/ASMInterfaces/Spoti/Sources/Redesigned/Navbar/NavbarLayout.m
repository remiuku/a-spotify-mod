// The saved composition of the redesign's bar, as NSUserDefaults property lists, apart from the native look's.
#import "Navbar.h"
#import "Shared/Navigation/Links.h"

NSString *const ASMSpotiRNavbarID = @"id";
NSString *const ASMSpotiRNavbarTitle = @"title";
NSString *const ASMSpotiRNavbarURI = @"uri";
NSString *const ASMSpotiRNavbarIcon = @"icon";
NSString *const ASMSpotiRNavbarHidden = @"hidden";

static NSString *const kNavbarLayout = @"asm.interface.spotipw.redesign.navbar.layout";
static NSString *const kNavbarStock = @"asm.interface.spotipw.redesign.navbar.stock";

// Only property list types go in, so a corrupt read cannot be anything but an array of dictionaries.
static NSArray *listOfKind(NSString *key, Class kind) {
    NSArray *list = [NSUserDefaults.standardUserDefaults arrayForKey:key];
    for (id item in list) if (![item isKindOfClass:kind]) return @[];
    return list ?: @[];
}

NSArray<NSDictionary *> *ASMSpotiRNavbarLayout(void) {
    return listOfKind(kNavbarLayout, NSDictionary.class);
}

void ASMSpotiRSetNavbarLayout(NSArray<NSDictionary *> *layout) {
    [NSUserDefaults.standardUserDefaults setObject:layout ?: @[] forKey:kNavbarLayout];
}

NSArray<NSString *> *ASMSpotiRNavbarStock(void) {
    return listOfKind(kNavbarStock, NSString.class);
}

void ASMSpotiRSetNavbarStock(NSArray<NSString *> *stock) {
    [NSUserDefaults.standardUserDefaults setObject:stock ?: @[] forKey:kNavbarStock];
}

NSURL *ASMSpotiRNavbarTabURL(NSString *uri) {
    NSURL *url = ASMSpotiSpotifyURIFromText(uri);
    if ([url.absoluteString isEqualToString:@"spotify:collection:playlists"]) return [NSURL URLWithString:@"spotify:playlists"];
    return url;
}
