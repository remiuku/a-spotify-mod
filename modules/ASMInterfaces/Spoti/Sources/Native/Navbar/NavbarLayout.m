// The saved composition of the bar, as NSUserDefaults property lists.
#import "Navbar.h"

NSString *const ASMSpotiNavbarID = @"id";
NSString *const ASMSpotiNavbarTitle = @"title";
NSString *const ASMSpotiNavbarURI = @"uri";
NSString *const ASMSpotiNavbarIcon = @"icon";
NSString *const ASMSpotiNavbarHidden = @"hidden";

static NSString *const kNavbarLayout = @"asm.interface.spotipw.navbar.layout";
static NSString *const kNavbarStock = @"asm.interface.spotipw.navbar.stock";

// Only property list types go in, so a corrupt read cannot be anything but an array of dictionaries.
static NSArray *listOfKind(NSString *key, Class kind) {
    NSArray *list = [NSUserDefaults.standardUserDefaults arrayForKey:key];
    for (id item in list) if (![item isKindOfClass:kind]) return @[];
    return list ?: @[];
}

NSArray<NSDictionary *> *ASMSpotiNavbarLayout(void) {
    return listOfKind(kNavbarLayout, NSDictionary.class);
}

void ASMSpotiSetNavbarLayout(NSArray<NSDictionary *> *layout) {
    [NSUserDefaults.standardUserDefaults setObject:layout ?: @[] forKey:kNavbarLayout];
}

NSArray<NSString *> *ASMSpotiNavbarStock(void) {
    return listOfKind(kNavbarStock, NSString.class);
}

void ASMSpotiSetNavbarStock(NSArray<NSString *> *stock) {
    [NSUserDefaults.standardUserDefaults setObject:stock ?: @[] forKey:kNavbarStock];
}
