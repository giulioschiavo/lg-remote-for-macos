import Cocoa
import Security
import CryptoKit

// Explicit first-use approval; pin the exact leaf certificate in Keychain.
final class TVTLSDelegate: NSObject, URLSessionDelegate {
    private let host: String
    private let account: String
    init(host: String, account: String) { self.host = host; self.account = "tls:" + account }

    static func permitsLegacyFallback(_ error: Error, account: String) -> Bool {
        do { guard try PairingStore.read("tls:" + account) == nil else { return false } }
        catch { return false }
        return isUnavailableEndpoint(error)
    }

    static func isUnavailableEndpoint(_ error: Error) -> Bool {
        let e = error as NSError
        // Never downgrade on a certificate, TLS, authentication or timeout error.
        return e.domain == NSURLErrorDomain && e.code == NSURLErrorCannotConnectToHost
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil); return
        }
        guard challenge.protectionSpace.host.lowercased() == host.lowercased(),
              let trust = challenge.protectionSpace.serverTrust,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let certificate = chain.first else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }
        let bytes = SecCertificateCopyData(certificate) as Data
        let fingerprint = SHA256.hash(data: bytes).map { String(format: "%02X", $0) }.joined(separator: ":")
        Task { @MainActor in
            do {
                if let saved = try PairingStore.read(account) {
                    guard saved == fingerprint else {
                        let alert = NSAlert()
                        alert.messageText = L("Certificato TV cambiato")
                        alert.informativeText = L("Il certificato non corrisponde a quello approvato. Il collegamento è stato bloccato. Verifica la TV prima di rimuovere l’associazione.")
                        alert.addButton(withTitle: L("Chiudi")); NSApp.activate(ignoringOtherApps: true); alert.runModal()
                        completionHandler(.cancelAuthenticationChallenge, nil); return
                    }
                } else {
                    let alert = NSAlert()
                    alert.messageText = L("Approva il collegamento sicuro alla TV")
                    alert.informativeText = L("Approva solo se riconosci la TV sulla tua rete. L’identità non è ancora verificata. L’impronta verrà conservata nel Portachiavi.") + "\n\n" + host + "\nSHA-256\n" + fingerprint
                    alert.addButton(withTitle: L("Approva certificato")); alert.addButton(withTitle: L("Annulla"))
                    NSApp.activate(ignoringOtherApps: true)
                    guard alert.runModal() == .alertFirstButtonReturn, PairingStore.save(fingerprint, host: account) else {
                        completionHandler(.cancelAuthenticationChallenge, nil); return
                    }
                }
                completionHandler(.useCredential, URLCredential(trust: trust))
            } catch { completionHandler(.cancelAuthenticationChallenge, nil) }
        }
    }
}
