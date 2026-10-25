#import "ASMVitrinePage.h"
#import "ASMVitrinePageStyle.h"
#import "Core/ASMVitrineCore.h"


// Spotify's navigation controller asserts that everything on its stack is one of its own pages
// (SPNavigationController.m:645, "[viewController conformsToProtocol:@protocol(SPTPageController)]"),
// and the tab bar asks it for that page on every tab tap to log the interaction. A plain view
// controller of the mod's pushed onto that stack therefore takes the app down the next time a tab
// is pressed, from wherever it was left. The pages below answer the protocol's two questions
// instead and are registered as conforming at load; if the protocol is gone they are presented
// rather than pushed, so a rename in some later Spotify costs the push, not the app.
static BOOL asm_vitrine_pagesConform;

@implementation ASMVitrinePage

// Inset grouped cards on black, the way Settings draws them, a hairline between the rows of a card.
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.tableView.backgroundColor = ASMVitrinePageBackground();
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.1];
    self.tableView.sectionHeaderTopPadding = 0;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if (![previous.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory])
        [self.tableView reloadData];
}

- (NSString *)spt_pageIdentifier {
    return @"asm.interface.vitrine";
}

- (NSURL *)spt_pageURI {
    return [NSURL URLWithString:@"spotify:internal:spotifyglass"];
}

@end

void ASMVitrineRegisterPages(void) {
    // Swift's own name for the protocol, which is what the runtime registers it under.
    Protocol *page = objc_getProtocol("_TtP19Tome_PageAttributes17SPTPageController_") ?: objc_getProtocol("SPTPageController");
    asm_vitrine_pagesConform = page && class_addProtocol(ASMVitrinePage.class, page);
    if (!asm_vitrine_pagesConform) ASMVitrineLog(@"SPTPageController not found, the mod's pages are presented instead of pushed");
}

void ASMVitrineShowPage(UIViewController *owner, UIViewController *page) {
    if (owner.navigationController && asm_vitrine_pagesConform) [owner.navigationController pushViewController:page animated:YES];
    else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:page];
        ASMVitrinePresentDark(nav);
        [owner presentViewController:nav animated:YES completion:nil];
    }
}
