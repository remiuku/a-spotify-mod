import Foundation

func check(_ condition: Bool, _ message: String) { if !condition { fatalError(message) } }
for globalGlass in [true, false] {
    for background in ["art", "mesh", "solid"] {
        check(!KaraokeBackdropPolicy.presentsTransparently(isSweet: true, mildEnabled: true,
                                                         mildBackground: background, glassEnabled: globalGlass),
              "An opaque Mild background must hide the Spotify player regardless of global glass")
    }
    check(KaraokeBackdropPolicy.presentsTransparently(isSweet: true, mildEnabled: true,
                                                    mildBackground: "clear", glassEnabled: globalGlass),
          "The explicit clear background must remain available")
    check(KaraokeBackdropPolicy.presentsTransparently(isSweet: true, mildEnabled: false,
                                                    mildBackground: "art", glassEnabled: globalGlass) == globalGlass,
          "Sweet without Mild retains its glass preference")
    check(KaraokeBackdropPolicy.presentsTransparently(isSweet: false, mildEnabled: true,
                                                    mildBackground: "clear", glassEnabled: globalGlass) == globalGlass,
          "Mild preferences must not alter Eevee presentation")
}
print("Karaoke background selection and opaque/glass presentation checks passed")
