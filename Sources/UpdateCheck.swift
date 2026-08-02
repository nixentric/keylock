import Foundation

/// Update check against GitHub Releases. No Sparkle, no appcast: one endpoint, one line of UI.

func versionParts(_ s: String) -> [Int] {
    s.drop(while: { !$0.isNumber }).split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
}

func isNewer(_ remote: String, than local: String) -> Bool {
    let r = versionParts(remote), l = versionParts(local)
    for i in 0 ..< max(r.count, l.count) {
        let a = i < r.count ? r[i] : 0, b = i < l.count ? l[i] : 0
        if a != b { return a > b }
    }
    return false
}

/// Calls back on the main queue, and only when a newer release actually exists.
func checkForUpdate(_ found: @escaping (String) -> Void) {
    let info = Bundle.main.infoDictionary ?? [:]
    guard let repo = info["KLUpdateRepo"] as? String, !repo.isEmpty,
          let local = info["CFBundleShortVersionString"] as? String,
          let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")
    else { return }
    URLSession.shared.dataTask(with: url) { data, _, _ in
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String, isNewer(tag, than: local) else { return }
        DispatchQueue.main.async { found("Update \(tag) available — github.com/\(repo)/releases") }
    }.resume()
}
