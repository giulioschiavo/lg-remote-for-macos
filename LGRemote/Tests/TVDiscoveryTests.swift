import Foundation

@main
struct TVDiscoveryTests {
    static func main() {
        let response = "HTTP/1.1 200 OK\r\nST: urn:lge-com:service:webos-second-screen:1\r\nX-Device-Name: Sala TV\r\nLOCATION: http://192.168.1.20:3000/\r\n\r\n"
        precondition(TVDiscovery.parseResponse(response, sourceIP: "192.168.1.20") == DiscoveredTV(host: "192.168.1.20", name: "Sala TV"))
        let usn = "HTTP/1.1 200 OK\nUSN: uuid:x::URN:LGE-COM:SERVICE:WEBOS-SECOND-SCREEN:1\n\n"
        precondition(TVDiscovery.parseResponse(usn, sourceIP: "192.168.1.21") == DiscoveredTV(host: "192.168.1.21", name: "LG webOS TV", deviceID: "uuid:x"))
        let moved = TVDiscovery.parseResponse(usn, sourceIP: "192.168.1.22")!
        precondition(moved.deviceID == "uuid:x" && moved.host == "192.168.1.22")
        precondition(TVDiscovery.parseResponse(usn.replacingOccurrences(of: "uuid:x", with: "uuid:other"), sourceIP: "192.168.1.21")!.deviceID != moved.deviceID)
        for bad in ["HTTP/1.1 404 Not Found\r\nST: urn:lge-com:service:webos-second-screen:1", "HTTP/1.1 200 OK\r\nST: ssdp:all", "HTTP/1.1 200 OK\r\nST: urn:lge-com:service:webos-second-screen:1\r\nLOCATION: https://192.168.1.20/x", "HTTP/1.1 200 OK\r\nST: urn:lge-com:service:webos-second-screen:1\r\nLOCATION: http://192.168.1.99/x"] {
            precondition(TVDiscovery.parseResponse(bad, sourceIP: "192.168.1.20") == nil)
        }
        precondition(TVDiscovery.parseResponse(response, sourceIP: "127.0.0.1") == nil)
        precondition(TVDiscovery.eligibleInterface(flags: UInt32(IFF_UP | IFF_RUNNING | IFF_MULTICAST), address: "192.168.1.20"))
        precondition(!TVDiscovery.eligibleInterface(flags: UInt32(IFF_UP | IFF_RUNNING | IFF_MULTICAST | IFF_LOOPBACK), address: "127.0.0.1"))
        print("PASS: SSDP status/service filtering, source validation, spoof rejection and interface bounds")
    }
}
