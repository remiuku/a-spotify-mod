var state = ASMLyricsPresentationState()
assert(!state.isPresented)
var previous: UInt64 = 0
for _ in 0..<10_000 {
    let token = state.begin()!
    assert(token > previous && state.isPresented && !state.dismissing)
    assert(state.begin() == nil) // duplicate presents cannot stack hosts
    assert(!state.beginDismiss(previous)) // stale renderer close
    assert(state.beginDismiss(token))
    assert(state.isPresented && state.dismissing)
    assert(state.begin() == nil) // keep ownership during the animation
    assert(!state.beginDismiss(token)) // duplicate close
    assert(!state.finish(previous)) // stale UIKit completion
    assert(state.finish(token))
    assert(!state.isPresented && !state.dismissing)
    assert(!state.finish(token))
    previous = token
}
print("PASS viewer lifecycle: 10000 switches, single host ownership, dismissal serialization and stale close/completion rejection")
