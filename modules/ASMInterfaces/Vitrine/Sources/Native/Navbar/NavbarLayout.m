// The saved composition of the bar, as NSUserDefaults property lists.
#import "Navbar.h"

NSString *const ASMVitrineNavbarID = @"id";
NSString *const ASMVitrineNavbarTitle = @"title";
NSString *const ASMVitrineNavbarURI = @"uri";
NSString *const ASMVitrineNavbarIcon = @"icon";
NSString *const ASMVitrineNavbarIconSet = @"iconSet";
NSString *const ASMVitrineNavbarHidden = @"hidden";

static NSString *const kNavbarLayout = @"asm.interface.vitrine.navbar.layout";
static NSString *const kNavbarStock = @"asm.interface.vitrine.navbar.stock";
static NSString *const kNavbarSplit = @"asm.interface.vitrine.navbar.split";

// Only property list types go in, so a corrupt read cannot be anything but an array of dictionaries.
static NSArray *listOfKind(NSString *key, Class kind) {
    NSArray *list = [NSUserDefaults.standardUserDefaults arrayForKey:key];
    for (id item in list) if (![item isKindOfClass:kind]) return @[];
    return list ?: @[];
}

NSArray<NSDictionary *> *ASMVitrineNavbarLayout(void) {
    return listOfKind(kNavbarLayout, NSDictionary.class);
}

void ASMVitrineSetNavbarLayout(NSArray<NSDictionary *> *layout) {
    [NSUserDefaults.standardUserDefaults setObject:layout ?: @[] forKey:kNavbarLayout];
}

NSArray<NSString *> *ASMVitrineNavbarSplit(void) {
    return listOfKind(kNavbarSplit, NSString.class);
}

void ASMVitrineSetNavbarSplit(NSArray<NSString *> *split) {
    [NSUserDefaults.standardUserDefaults setObject:split ?: @[] forKey:kNavbarSplit];
}

NSArray<NSString *> *ASMVitrineNavbarStock(void) {
    return listOfKind(kNavbarStock, NSString.class);
}

void ASMVitrineSetNavbarStock(NSArray<NSString *> *stock) {
    [NSUserDefaults.standardUserDefaults setObject:stock ?: @[] forKey:kNavbarStock];
}
