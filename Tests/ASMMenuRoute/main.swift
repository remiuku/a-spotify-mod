import Foundation
precondition(ASMMenuRoute.root.children == [.lyrics,.sound,.look,.advanced,.about])
precondition(ASMMenuRoute.lyrics.children.prefix(2) == [.viewers, .funLyrics])
var seen=Set<ASMMenuRoute>(), queue:[(ASMMenuRoute,Int)]=[(.root,0)]
var maximum=0
while !queue.isEmpty {
    let (route,depth)=queue.removeFirst()
    precondition(seen.insert(route).inserted,"duplicate/cyclic settings route: \(route)")
    precondition(!route.symbol.isEmpty && !route.titleKey.isEmpty)
    maximum=max(maximum,depth)
    for child in route.children {queue.append((child,depth+1))}
}
precondition(seen == Set(ASMMenuRoute.allCases),"unreachable settings page")
precondition(maximum<=3,"settings nested too deeply")
precondition(ASMMenuRoute.look.children == [.interface,.presets,.theme,.covers,.layout])
print("PASS menu reachability: five main entries, all \(seen.count) destinations reachable without cycles, at most \(maximum) taps, Viewers and Fun lyrics directly in Lyrics")
