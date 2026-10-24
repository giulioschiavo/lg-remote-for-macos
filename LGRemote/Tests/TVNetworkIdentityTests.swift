import Foundation

@main
struct TVNetworkIdentityTests {
    static func main() {
        precondition(TVNetworkIdentity.resolveIPv4("localhost") == "127.0.0.1")
        precondition(TVNetworkIdentity.resolveIPv4("192.168.1.20") == "192.168.1.20")
        precondition(TVNetworkIdentity.directedBroadcast(localIP: "192.168.1.20", mask: "255.255.255.0", targetIP: "192.168.1.50") == "192.168.1.255")
        precondition(TVNetworkIdentity.directedBroadcast(localIP: "192.168.1.20", mask: "255.255.254.0", targetIP: "192.168.1.50") == "192.168.1.255")
        precondition(TVNetworkIdentity.directedBroadcast(localIP: "192.168.1.20", mask: "255.255.0.0", targetIP: "192.168.2.50") == "192.168.255.255")
        precondition(TVNetworkIdentity.directedBroadcast(localIP: "192.168.1.20", mask: "255.255.255.0", targetIP: "192.168.2.50") == nil)
        precondition(TVNetworkIdentity.directedBroadcast(localIP: "192.168.1.20", mask: "255.0.255.0", targetIP: "192.168.1.50") == nil)
        precondition(TVNetworkIdentity.directedBroadcast(localIP: "192.168.1.20", mask: "255.255.255.254", targetIP: "192.168.1.20") == nil)
        let active: [String: Any] = [
            "wifi": ["state": "connected", "macAddress": "a:b:c:d:e:f"],
            "wired": ["connected": false, "mac": "02:00:00:00:00:02"]
        ]
        precondition(TVNetworkIdentity.fromAPI(active) == [MACCandidate(address: "0a:0b:0c:0d:0e:0f", source: "wifi")])
        let infoOnly: [String: Any] = ["wifiInfo": ["macAddress": "02:00:00:00:00:03"]]
        precondition(TVNetworkIdentity.fromAPI(infoOnly) == [MACCandidate(address: "02:00:00:00:00:03", source: "wifi-unverified")])
        let enrichedStatus: [String: Any] = ["wifi": ["connected": true]]
        precondition(TVNetworkIdentity.fromAPI(infoOnly, status: enrichedStatus) == [MACCandidate(address: "02:00:00:00:00:03", source: "wifi")])
        let disconnectedStatus: [String: Any] = ["wifi": ["state": "disconnected"]]
        precondition(TVNetworkIdentity.fromAPI(infoOnly, status: disconnectedStatus).isEmpty)
        precondition(TVNetworkIdentity.fromAPI(["wifiInfo": ["macAddress": "02::00:00:00:00:04"]]).isEmpty)

        let ambiguous: [String: Any] = [
            "wifi": ["connected": true, "mac": "02:00:00:00:00:01"],
            "wired": ["state": "connected", "macAddress": "02-00-00-00-00-02"]
        ]
        precondition(TVNetworkIdentity.fromAPI(ambiguous).count == 2)
        precondition(TVNetworkIdentity.fromAPI(["wifi": ["state": "disconnected", "mac": "02:00:00:00:00:01"]]).isEmpty)

        let invalid: [String: Any] = [
            "wifi": ["connected": true, "mac": "00:00:00:00:00:00"],
            "wired": ["connected": true, "mac": "ff:ff:ff:ff:ff:ff"]
        ]
        precondition(TVNetworkIdentity.fromAPI(invalid).isEmpty)
        precondition(TVNetworkIdentity.parseARPOutput("? (192.168.1.20) at 02:00:00:00:00:20 on en0 ifscope [ethernet]", ip: "192.168.1.20") == MACCandidate(address: "02:00:00:00:00:20", source: "arp-unverified"))
        precondition(TVNetworkIdentity.parseARPOutput("? (192.168.1.20) at incomplete on en0", ip: "192.168.1.20") == nil)
        precondition(TVNetworkIdentity.parseARPOutput("? (192.168.1.21) at 02:00:00:00:00:21 on en0", ip: "192.168.1.20") == nil)
        print("PASS: active API identities, ambiguity, MAC validation and ARP parsing")
    }
}
