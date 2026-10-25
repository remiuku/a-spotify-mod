// The saved composition of the redesign's bar, as NSUserDefaults property lists, apart from the native look's.
#import "Navbar.h"
#import "Shared/Navigation/Links.h"

NSString *const ASMVitrineRNavbarID = @"id";
NSString *const ASMVitrineRNavbarTitle = @"title";
NSString *const ASMVitrineRNavbarURI = @"uri";
NSString *const ASMVitrineRNavbarIcon = @"icon";
NSString *const ASMVitrineRNavbarIconSet = @"iconSet";
NSString *const ASMVitrineRNavbarHidden = @"hidden";

static NSString *const kNavbarLayout = @"asm.interface.vitrine.redesign.navbar.layout";
static NSString *const kNavbarStock = @"asm.interface.vitrine.redesign.navbar.stock";
static NSString *const kNavbarSplit = @"asm.interface.vitrine.redesign.navbar.split";

// Only property list types go in, so a corrupt read cannot be anything but an array of dictionaries.
static NSArray *listOfKind(NSString *key, Class kind) {
    NSArray *list = [NSUserDefaults.standardUserDefaults arrayForKey:key];
    for (id item in list) if (![item isKindOfClass:kind]) return @[];
    return list ?: @[];
}

NSArray<NSDictionary *> *ASMVitrineRNavbarLayout(void) {
    return listOfKind(kNavbarLayout, NSDictionary.class);
}

void ASMVitrineRSetNavbarLayout(NSArray<NSDictionary *> *layout) {
    [NSUserDefaults.standardUserDefaults setObject:layout ?: @[] forKey:kNavbarLayout];
}

NSArray<NSString *> *ASMVitrineRNavbarSplit(void) {
    return listOfKind(kNavbarSplit, NSString.class);
}

void ASMVitrineRSetNavbarSplit(NSArray<NSString *> *split) {
    [NSUserDefaults.standardUserDefaults setObject:split ?: @[] forKey:kNavbarSplit];
}

NSArray<NSString *> *ASMVitrineRNavbarStock(void) {
    return listOfKind(kNavbarStock, NSString.class);
}

void ASMVitrineRSetNavbarStock(NSArray<NSString *> *stock) {
    [NSUserDefaults.standardUserDefaults setObject:stock ?: @[] forKey:kNavbarStock];
}

NSURL *ASMVitrineRNavbarTabURL(NSString *uri) {
    NSURL *url = ASMVitrineSpotifyURIFromText(uri);
    if ([url.absoluteString isEqualToString:@"spotify:collection:playlists"]) return [NSURL URLWithString:@"spotify:playlists"];
    return url;
}
