import Foundation

func url(_ path: String) -> URL { URL(string: "https://spclient.wg.spotify.com" + path)! }
for path in ["/ads/v2/config", "/ad-logic/state/config", "/ad-slot/v1/fetch", "/ad-inventory/v1"] {
    precondition(ASMCoreAdPolicy.endpoint(for: url(path)) != nil)
}
for path in ["/esperanto/com.spotify.ads.v1.Service/Fetch", "/esperanto/ads_config/Fetch", "/esperanto/foo.ad-slot/Fetch"] {
    precondition(url(path).isEsperantoAdRequest)
    precondition(ASMCoreAdPolicy.endpoint(for: url(path)) == "esperanto-ad")
}
for path in ["/metadata/4/track/id", "/track/id", "/connect-state/v1/devices", "/apresolve", "/login5", "/v1/customize", "/v1/bootstrap", "/esperanto/player/Load", "/esperanto/player/Download", "/esperanto/metadata/Get", "/esperanto/slotmachine/Get"] {
    precondition(ASMCoreAdPolicy.endpoint(for: url(path)) == nil, path)
}
for host in ["spotify.com.attacker.invalid", "notspotify.com", "example.com"] {
    precondition(ASMCoreAdPolicy.endpoint(for: URL(string: "https://" + host + "/ads/v2/config")!) == nil)
}
precondition(ASMCoreAdPolicy.endpoint(for: URL(string: "https://SPCLIENT.WG.SPOTIFY.COM/ADS/V2/CONFIG?device=private")!) == "ads-configuration")
print("PASS native core ad routes: config/state endpoints and token boundaries; playback, login, AP lookup, metadata, lookalike hosts and private queries excluded")
