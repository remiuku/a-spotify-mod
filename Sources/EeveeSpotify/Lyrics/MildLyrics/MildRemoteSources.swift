import Foundation
import EeveeSpotifyC

// Endpoint/format adaptations from Mild Lyrics; requests use ordinary TLS verification.
final class MildRemoteSources {
    let query: LyricsSearchQuery
    let duration: Double
    private let redLock = NSLock()
    private var redLoaded = false
    private var redDocuments: [Bool: KaraokeLyricsDto] = [:]
    init(query: LyricsSearchQuery, duration: Double) { self.query = query; self.duration = duration }
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5; config.timeoutIntervalForResource = 7
        return URLSession(configuration: config)
    }()
    private func data(_ base: String, _ params: [String: String] = [:]) throws -> Data {
        guard var url = URLComponents(string: base) else { throw LyricsError.decodingError }
        if !params.isEmpty { url.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let endpoint = url.url else { throw LyricsError.decodingError }
        var request = URLRequest(url: endpoint)
        request.setValue("EeveeSpotify-MildLyrics/1.0", forHTTPHeaderField: "User-Agent")
        if endpoint.host?.hasSuffix("qq.com") == true { request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer") }
        let ready = DispatchSemaphore(value: 0)
        var result: Data?, failure: Error?
        let task = Self.session.dataTask(with: request) { bytes, response, error in
            if let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), let bytes, bytes.count <= 4_194_304 { result = bytes }
            else { failure = error ?? LyricsError.noSuchSong }
            ready.signal()
        }
        task.resume(); ready.wait()
        if let result { return result }; throw failure ?? LyricsError.noSuchSong
    }
    private func json(_ base: String, _ params: [String: String] = [:]) throws -> [String: Any] {
        let raw = try data(base, params)
        guard let object = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else { throw LyricsError.decodingError }
        return object
    }
    private func str(_ value: Any?) -> String { value as? String ?? (value as? NSNumber)?.stringValue ?? "" }
    private func num(_ value: Any?) -> Double { (value as? NSNumber)?.doubleValue ?? Double(str(value)) ?? 0 }
    private func same(_ title: String, _ artist: String, _ seconds: Double = 0) -> Bool {
        MildLyricsParsing.recordingMatches(title: title, artist: artist, duration: seconds, query: query, expectedDuration: duration)
    }
    func fetch(_ id: String) throws -> KaraokeLyricsDto? {
        switch id {
        case "netease": return try netease()
        case "kugou": return try kugou()
        case "qq": return try qq()
        case "kuwo": return try kuwo()
        case "apple": return try apple(model: false)
        case "lrcmodel": return try apple(model: true)
        case "amll": return try amll()
        case "unison": return try unison()
        default: return nil
        }
    }
    private func netease() throws -> KaraokeLyricsDto? {
        let root = try json("https://music.163.com/api/search/get", ["s": "\(query.primaryArtist) \(query.title)", "type": "1", "limit": "8"])
        let songs = (root["result"] as? [String: Any])?["songs"] as? [[String: Any]] ?? []
        for song in songs {
            let artists = (song["ar"] ?? song["artists"]) as? [[String: Any]] ?? []
            guard same(str(song["name"]), artists.map { str($0["name"]) }.joined(separator: "/"), num(song["dt"] ?? song["duration"]) / 1000) else { continue }
            let lyric = try json("https://music.163.com/api/song/lyric", ["os": "pc", "id": str(song["id"]), "lv": "-1", "kv": "-1", "tv": "-1", "yv": "-1", "rv": "-1"])
            if let yrc = (lyric["yrc"] as? [String: Any])?["lyric"] as? String,
               let parsed = MildLyricsParsing.words(yrc, format: "yrc", name: "NetEase") { return parsed }
            if let lrc = (lyric["lrc"] as? [String: Any])?["lyric"] as? String { return MildLyricsParsing.lrc(lrc, name: "NetEase") }
        }
        return nil
    }
    private func kugou() throws -> KaraokeLyricsDto? {
        let root = try json("https://mobileservice.kugou.com/api/v3/search/song", ["format": "json", "keyword": "\(query.primaryArtist) \(query.title)", "page": "1", "pagesize": "8"])
        let songs = (root["data"] as? [String: Any])?["info"] as? [[String: Any]] ?? []
        for song in songs where same(str(song["songname"]), str(song["singername"]), num(song["duration"])) {
            let candidates = try json("https://krcs.kugou.com/search", ["ver": "1", "man": "yes", "client": "mobi", "keyword": query.title, "duration": str(song["duration"].map { num($0) * 1000 }), "hash": str(song["hash"])])["candidates"] as? [[String: Any]] ?? []
            for candidate in candidates.prefix(2) {
                let got = try json("https://lyrics.kugou.com/download", ["ver": "1", "client": "pc", "id": str(candidate["id"]), "accesskey": str(candidate["accesskey"]), "fmt": "krc", "charset": "utf8"])
                guard let raw = Data(base64Encoded: str(got["content"])), raw.count > 4, raw.prefix(4) == Data([107,114,99,49]) else { continue }
                let key: [UInt8] = [0x40,0x47,0x61,0x77,0x5e,0x32,0x74,0x47,0x51,0x36,0x31,0x2d,0xce,0xd2,0x6e,0x69]
                let encoded = Data(raw.dropFirst(4).enumerated().map { $0.element ^ key[$0.offset % key.count] })
                guard let inflated = EeveeMildInflate(encoded), let text = String(data: inflated, encoding: .utf8) else { continue }
                if let parsed = MildLyricsParsing.words(text, format: "krc", name: "Kugou") { return parsed }
            }
        }
        return nil
    }
    private func qq() throws -> KaraokeLyricsDto? {
        let root = try json("https://c.y.qq.com/soso/fcgi-bin/client_search_cp", ["format": "json", "p": "1", "n": "10", "w": "\(query.title) \(query.primaryArtist)", "cr": "1", "t": "0", "aggr": "1", "lossless": "0", "flag_qc": "0"])
        let songs = ((root["data"] as? [String: Any])?["song"] as? [String: Any])?["list"] as? [[String: Any]] ?? []
        for song in songs {
            let artists = (song["singer"] as? [[String: Any]] ?? []).map { str($0["name"]) }.joined(separator: "/")
            guard same(str(song["songname"]), artists, num(song["interval"])) else { continue }
            let raw = try data("https://c.y.qq.com/qqmusic/fcgi-bin/lyric_download.fcg", ["version": "15", "miniversion": "82", "lrctype": "4", "musicid": str(song["songid"])])
            guard let text = String(data: raw, encoding: .utf8) else { continue }
            let blob = MildLyricsParsing.matches(#"<content\b[^>]*>\s*<!\[CDATA\[(.*?)\]\]>"#, text).first?[1]
                ?? MildLyricsParsing.matches(#"content="(.*?)""#, text).first?[1] ?? ""
            let compact = blob.filter { !$0.isWhitespace }
            var decoded = blob
            if !compact.isEmpty, compact.count % 16 == 0, compact.allSatisfy(\.isHexDigit) {
                let chars = Array(compact); var bytes = stride(from: 0, to: chars.count, by: 2).compactMap { UInt8(String(chars[$0...$0+1]), radix: 16) }
                let count = bytes.count
                bytes.withUnsafeMutableBufferPointer { EeveeMildQRCDecrypt($0.baseAddress!, count) }
                guard let inflated = EeveeMildInflate(Data(bytes)), let plain = String(data: inflated, encoding: .utf8) else { continue }
                decoded = plain
            }
            if let parsed = MildLyricsParsing.words(decoded, format: "qrc", name: "QQ Music") { return parsed }
        }
        return nil
    }
    private func kuwo() throws -> KaraokeLyricsDto? {
        let root = try json("https://search.kuwo.cn/r.s", ["all": "\(query.title) \(query.primaryArtist)", "ft": "music", "rformat": "json", "encoding": "utf8", "rn": "8", "pn": "0", "client": "kt", "ver": "kwplayer_ar_9.2.2.1", "vipver": "1", "show_copyright_off": "1", "newver": "1", "cluster": "0", "strategy": "2012", "vermerge": "1", "mobi": "1", "issubtitle": "1"])
        let key = Array("yeelion".utf8)
        func xor(_ bytes: Data) -> Data { Data(bytes.enumerated().map { $0.element ^ key[$0.offset % key.count] }) }
        for row in root["abslist"] as? [[String: Any]] ?? [] where same(str(row["SONGNAME"]), str(row["ARTIST"]), num(row["DURATION"])) {
            let rid = str(row["MUSICRID"])
            guard rid.range(of: #"^MUSIC_\d+$"#, options: .regularExpression) != nil else { continue }
            let ask = "user=12345,web,web,web&requester=localhost&req=1&rid=\(rid)&lrcx=1"
            let raw = try data("https://newlyric.kuwo.cn/newlyric.lrc?" + xor(Data(ask.utf8)).base64EncodedString())
            guard let split = raw.range(of: Data([13,10,13,10])), let inflated = EeveeMildInflate(Data(raw[split.upperBound...])) else { continue }
            let payload = inflated.first == 91 ? inflated : Data(base64Encoded: inflated).map(xor) ?? inflated
            let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
            guard let text = String(data: payload, encoding: encoding) ?? String(data: payload, encoding: .utf8) else { continue }
            if let k = MildLyricsParsing.matches(#"\[kuwo:(\d+)\]"#, text).first.flatMap({ Int($0[1], radix: 8) }), k / 10 > 0, k % 10 > 0 {
                var krc = ""
                for line in text.components(separatedBy: .newlines) {
                    guard let head = MildLyricsParsing.matches(#"^\[(\d+):(\d+)(?:\.(\d+))?\]"#, line).first else { continue }
                    let start = (Int(head[1])! * 60 + Int(head[2])!) * 1000 + Int((head[3] + "000").prefix(3))!
                    let tokens = MildLyricsParsing.matches(#"<(-?\d+),(-?\d+)>([^<]*)"#, line)
                    guard tokens.contains(where: { $0[1] != "0" || $0[2] != "0" }) else { continue }
                    let spans = tokens.map { token -> String in
                        let a = Int(token[1]) ?? 0, b = Int(token[2]) ?? 0
                        return "<\(abs(a + b) / (2 * (k / 10))),\(abs(a - b) / (2 * (k % 10))),0>\(token[3])"
                    }.joined()
                    krc += "[\(start),0]\(spans)\n"
                }
                if let parsed = MildLyricsParsing.words(krc, format: "krc", name: "Kuwo") { return parsed }
            }
            if let parsed = MildLyricsParsing.lrc(text, name: "Kuwo") { return parsed }
        }
        return nil
    }
    private func apple(model: Bool) throws -> KaraokeLyricsDto? {
        redLock.lock(); defer { redLock.unlock() }
        if redLoaded { return redDocuments[model] }
        let rows = try json("https://lrc.red/search.json", ["q": "\(query.title) \(query.primaryArtist)"])["hits"] as? [[String: Any]] ?? []
        for row in rows.filter({ same(str($0["title"]), str($0["artist"]), num($0["duration"])) }).prefix(3) {
            let isrc = str(row["isrc"])
            guard isrc.range(of: #"^[A-Za-z0-9]{12}$"#, options: .regularExpression) != nil else { continue }
            let song = try json("https://lrc.red/s/\(isrc).song.json")
            let byModel = song["byModel"] as? Bool ?? false
            if let text = song["source"] as? String,
               let parsed = MildLyricsParsing.ttml(text, name: byModel ? "lrc.red model sync" : "Apple Music · lrc.red") {
                if redDocuments[byModel] == nil { redDocuments[byModel] = parsed }
            }
        }
        redLoaded = true
        return redDocuments[model]
    }
    private func amll() throws -> KaraokeLyricsDto? {
        let root = try json("https://api.amll.dev/v1/lyrics/search", ["trackName": query.title, "artistName": query.primaryArtist])
        for row in (root["data"] as? [String: Any])?["items"] as? [[String: Any]] ?? [] {
            let names = row["musicNames"] as? [String] ?? [], artists = row["artistNames"] as? [String] ?? []
            guard names.contains(where: { name in artists.contains { same(name, $0) } }) else { continue }
            let root = try json("https://api.amll.dev/v1/lyrics/get", ["id": str(row["id"])])
            let body = root["data"] as? [String: Any] ?? root
            for key in ["lyrics", "ttml", "content"] {
                if let text = body[key] as? String, var parsed = MildLyricsParsing.ttml(text, name: "AMLL TTML DB") {
                    parsed.makerName = (row["authorUsernames"] as? [String])?.first
                    if let name = parsed.makerName, name.range(of: "^[A-Za-z0-9-]{1,39}$", options: .regularExpression) != nil {
                        parsed.makerUrl = "https://github.com/" + name
                        let id = (row["authorIds"] as? [Any])?.first.map { String(describing: $0) } ?? ""
                        if !id.isEmpty && id.allSatisfy({ $0.isASCII && $0.isNumber }) { parsed.makerAvatarUrl = "https://avatars.githubusercontent.com/u/" + id + "?s=96" }
                    }
                    return parsed
                }
            }
        }
        return nil
    }
    private func unison() throws -> KaraokeLyricsDto? {
        let body = try json("https://unison.boidu.dev/lyrics", ["song": query.title, "artist": query.primaryArtist])["data"] as? [String: Any] ?? [:]
        guard same(str(body["song"] ?? body["title"]), str(body["artist"])), let text = body["lyrics"] as? String,
              var parsed = MildLyricsParsing.content(text, name: "Unison") else { return nil }
        let submitter = body["submitter"] as? [String: Any]
        parsed.uploaderName = submitter?["displayName"] as? String
        parsed.uploaderAvatarUrl = submitter?["avatarUrl"] as? String
        if let name = submitter?["keyId"] as? String, name.range(of: "^[0-9a-f]{16,128}$", options: .regularExpression) != nil {
            parsed.uploaderUrl = "https://unison.boidu.dev/curator/" + name
        }
        return parsed
    }
}
