import Foundation

@main
struct UpdateCheckerTests {
    static func main() throws {
        precondition(ReleaseVersion("v1.10")! > ReleaseVersion("1.9")!)
        precondition(ReleaseVersion("1.7")! == ReleaseVersion("1.7.0")!)
        for bad in ["", "1..7", "1.7-beta", "1.7+1", "v", "1.2.3.4.5", "-1", "99999999999999999999999"] {
            precondition(ReleaseVersion(bad) == nil, bad)
        }
        let fixture = Data(#"{"tag_name":"v1.8","html_url":"https://github.com/giulioschiavo/lg-remote-for-macos/releases/tag/v1.8","draft":false,"prerelease":false}"#.utf8)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: fixture)
        precondition(release.isNewer(than: "1.7"))
        precondition(!release.isNewer(than: "1.8"))
        precondition(!release.isNewer(than: "2.0"))
        precondition(!GitHubRelease(tag_name: "v1.8", html_url: release.html_url, draft: true, prerelease: false).isNewer(than: "1.7"))
        precondition(!GitHubRelease(tag_name: "v1.8", html_url: release.html_url, draft: false, prerelease: true).isNewer(than: "1.7"))
        for url in ["http://github.com/giulioschiavo/lg-remote-for-macos/releases/tag/v1.8", "https://evil.example/releases/tag/v1.8", "https://github.com/another/repo/releases/tag/v1.8", "https://user@github.com/giulioschiavo/lg-remote-for-macos/releases/tag/v1.8"] {
            precondition(!GitHubRelease(tag_name: "v1.8", html_url: url, draft: false, prerelease: false).isNewer(than: "1.7"))
        }
        if CommandLine.arguments.count > 1 {
            let live = try JSONDecoder().decode(GitHubRelease.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            precondition(live.safeURL != nil && ReleaseVersion(live.tag_name) != nil)
            print("Validated real GitHub response: \(live.tag_name)")
        }
        print("PASS: release decoding, numeric versions, stable-only updates and trusted release URLs")
    }
}
