import Cocoa
import UserNotifications

struct ReleaseVersion: Comparable {
    let components: [Int]
    init?(_ value: String) {
        let raw = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 4 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let n = Int(part) else { return nil }
            numbers.append(n)
        }
        components = numbers + Array(repeating: 0, count: 4 - numbers.count)
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.components.lexicographicallyPrecedes(rhs.components) }
}

struct GitHubRelease: Decodable {
    let tag_name: String
    let html_url: String
    let draft: Bool
    let prerelease: Bool
    var safeURL: URL? {
        guard let url = URL(string: html_url), url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil,
              url.path.hasPrefix("/giulioschiavo/lg-remote-for-macos/releases/tag/") else { return nil }
        return url
    }
    func isNewer(than current: String) -> Bool {
        guard !draft, !prerelease, safeURL != nil,
              let remote = ReleaseVersion(tag_name), let local = ReleaseVersion(current) else { return false }
        return remote > local
    }
}

@MainActor
final class UpdateChecker: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = UpdateChecker()
    @Published private(set) var automatic = UserDefaults.standard.bool(forKey: "automaticUpdateChecks")
    @Published private(set) var checking = false
    @Published private(set) var message = ""
    @Published private(set) var available: GitHubRelease?
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var generation = 0
    private let defaults = UserDefaults.standard
    private let interval: TimeInterval = 24 * 60 * 60
    private var notifications: UNUserNotificationCenter { .current() }

    func start() {
        notifications.delegate = self
        if automatic { schedule(); check() }
    }
    func setAutomatic(_ enabled: Bool) {
        automatic = enabled; defaults.set(enabled, forKey: "automaticUpdateChecks")
        timer?.invalidate(); timer = nil
        generation += 1; task?.cancel(); task = nil; checking = false
        if enabled {
            schedule()
            Task {
                let granted = (try? await notifications.requestAuthorization(options: [.alert, .sound])) ?? false
                guard automatic else { return }
                if !granted { message = L("Notifiche non consentite: gli aggiornamenti restano visibili nell’app.") }
                check(manual: true)
            }
        } else {
            message = ""
            notifications.removeDeliveredNotifications(withIdentifiers: ["lg-remote-update"])
            notifications.removePendingNotificationRequests(withIdentifiers: ["lg-remote-update"])
        }
    }
    private func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }
    func check(manual: Bool = false) {
        guard !checking, manual || automatic else { return }
        if !manual, let last = defaults.object(forKey: "updateLastAttempt") as? Date,
           Date().timeIntervalSince(last) < interval { return }
        checking = true; message = L("Controllo aggiornamenti…")
        defaults.set(Date(), forKey: "updateLastAttempt")
        let token = generation
        task = Task {
            do {
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/giulioschiavo/lg-remote-for-macos/releases/latest")!)
                request.timeoutInterval = 20
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("LGRemote-macOS", forHTTPHeaderField: "User-Agent")
                let config = URLSessionConfiguration.ephemeral
                config.httpCookieStorage = nil; config.urlCache = nil
                let session = URLSession(configuration: config)
                defer { session.invalidateAndCancel() }
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard token == generation else { return }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                guard ReleaseVersion(release.tag_name) != nil, release.safeURL != nil, !release.draft, !release.prerelease else {
                    throw URLError(.cannotParseResponse)
                }
                let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
                available = release.isNewer(than: current) ? release : nil
                message = available == nil ? L("La versione installata è aggiornata.") : LF("Disponibile la versione %@", release.tag_name)
                if automatic, available != nil { await notify(release) }
            } catch {
                guard token == generation, !Task.isCancelled else { return }
                message = L("Controllo non riuscito. Riprova più tardi.")
            }
            guard token == generation else { return }
            checking = false; task = nil
        }
    }
    private func notify(_ release: GitHubRelease) async {
        guard defaults.string(forKey: "updateLastNotified") != release.tag_name else { return }
        let settings = await notifications.notificationSettings()
        guard automatic, settings.authorizationStatus == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = L("Aggiornamento disponibile")
        content.body = LF("LG Remote %@ è disponibile. Apri la Release per scaricarlo.", release.tag_name)
        content.sound = .default
        content.userInfo = ["releaseURL": release.html_url]
        do {
            try await notifications.add(UNNotificationRequest(identifier: "lg-remote-update", content: content, trigger: nil))
            defaults.set(release.tag_name, forKey: "updateLastNotified")
        } catch { /* The in-app banner remains available if system delivery fails. */ }
    }
    func openRelease() { if let url = available?.safeURL { NSWorkspace.shared.open(url) } }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let raw = response.notification.request.content.userInfo["releaseURL"] as? String
        Task { @MainActor in
            if let raw, let url = GitHubRelease(tag_name: "", html_url: raw, draft: false, prerelease: false).safeURL { NSWorkspace.shared.open(url) }
            completionHandler()
        }
    }
}
