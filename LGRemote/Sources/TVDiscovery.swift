import Foundation
import Darwin

struct DiscoveredTV: Identifiable, Equatable {
    let host: String
    let name: String
    var deviceID: String? = nil
    var id: String { host }
}

enum TVDiscoveryError: Error, Equatable {
    case noEligibleInterfaces
    case unableToSend
}

enum TVDiscovery {
    private static let service = "urn:lge-com:service:webos-second-screen:1"
    private static let group = "239.255.255.250"

    static func search() async throws -> [DiscoveredTV] {
        let flag = CancellationFlag()
        return try await withTaskCancellationHandler(operation: {
            try await Task.detached(priority: .utility) { try discover(flag: flag) }.value
        }, onCancel: { flag.cancel() })
    }

    static func parseResponse(_ text: String, sourceIP: String) -> DiscoveredTV? {
        guard validIPv4(sourceIP) else { return nil }
        let lines = text.components(separatedBy: .newlines)
        guard let status = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return nil }
        let statusParts = status.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard statusParts.count >= 2, statusParts[0].hasPrefix("http/"), statusParts[1] == "200" else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }
        let st = headers["st"]?.lowercased() ?? ""
        let usn = headers["usn"]?.lowercased() ?? ""
        guard st == service || usn.components(separatedBy: "::").last == service else { return nil }
        if let location = headers["location"] {
            guard let url = URL(string: location), url.scheme?.lowercased() == "http", url.host == sourceIP else { return nil }
        }
        let name = headers["x-device-name"] ?? headers["device-name"] ?? headers["friendlyname"] ?? "LG webOS TV"
        let rawID = usn.components(separatedBy: "::").first ?? ""
        let identity = rawID.hasPrefix("uuid:") && rawID.count <= 128 && rawID.dropFirst(5).allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) && rawID.count > 5 ? rawID : nil
        return DiscoveredTV(host: sourceIP, name: name.isEmpty ? "LG webOS TV" : String(name.prefix(80)), deviceID: identity)
    }

    static func eligibleInterface(flags: UInt32, address: String) -> Bool {
        let required = UInt32(IFF_UP | IFF_RUNNING | IFF_MULTICAST)
        return flags & required == required && flags & UInt32(IFF_LOOPBACK) == 0 && validIPv4(address)
    }

    private static func discover(flag: CancellationFlag) throws -> [DiscoveredTV] {
        let interfaces = interfaceAddresses()
        guard !interfaces.isEmpty else { throw TVDiscoveryError.noEligibleInterfaces }
        var sockets: [(fd: Int32, source: String)] = []
        defer { sockets.forEach { close($0.fd) } }
        var sent = 0
        for source in interfaces {
            guard !flag.cancelled else { return [] }
            let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard fd >= 0 else { continue }
            var local = sockaddr_in(); local.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); local.sin_family = sa_family_t(AF_INET)
            inet_pton(AF_INET, source, &local.sin_addr)
            let bound = withUnsafePointer(to: &local) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            guard bound == 0, fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else { close(fd); continue }
            var interfaceAddress = local.sin_addr
            guard setsockopt(fd, IPPROTO_IP, IP_MULTICAST_IF, &interfaceAddress, socklen_t(MemoryLayout<in_addr>.size)) == 0 else { close(fd); continue }
            var ttl: UInt8 = 2; setsockopt(fd, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout.size(ofValue: ttl)))
            var destination = sockaddr_in(); destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); destination.sin_family = sa_family_t(AF_INET); destination.sin_port = UInt16(1900).bigEndian; inet_pton(AF_INET, group, &destination.sin_addr)
            let data = Data("M-SEARCH * HTTP/1.1\r\nHOST: \(group):1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: \(service)\r\n\r\n".utf8)
            for _ in 0..<2 {
                let result = data.withUnsafeBytes { buffer in withUnsafePointer(to: &destination) { pointer in pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, buffer.baseAddress, buffer.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } } }
                if result == data.count { sent += 1 }
            }
            sockets.append((fd, source))
        }
        guard sent > 0 else { throw TVDiscoveryError.unableToSend }
        let deadline = Date().addingTimeInterval(8); var found: [String: DiscoveredTV] = [:]; var packets = 0
        while Date() < deadline && packets < 64 && !flag.cancelled {
            var pollfds = sockets.map { pollfd(fd: $0.fd, events: Int16(POLLIN), revents: 0) }
            _ = poll(&pollfds, nfds_t(pollfds.count), 100)
            for (index, item) in sockets.enumerated() where pollfds[index].revents & Int16(POLLIN) != 0 {
                var buffer = [UInt8](repeating: 0, count: 4096); var peer = sockaddr_in(); var length = socklen_t(MemoryLayout<sockaddr_in>.size)
                let count = withUnsafeMutablePointer(to: &peer) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(item.fd, &buffer, buffer.count, 0, $0, &length) }
                }
                guard count > 0 else { continue }; packets += 1
                var peerAddress = peer.sin_addr; var chars = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN)); guard inet_ntop(AF_INET, &peerAddress, &chars, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
                if let tv = parseResponse(String(decoding: buffer.prefix(count), as: UTF8.self), sourceIP: String(cString: chars)) { found[tv.host] = tv }
            }
        }
        return Array(found.values).sorted { $0.host < $1.host }
    }

    private static func interfaceAddresses() -> [String] {
        var result = Set<String>(); var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }; defer { freeifaddrs(first) }
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let item = current { defer { current = item.pointee.ifa_next }; guard let addr = item.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }; var sin = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }; var chars = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN)); guard inet_ntop(AF_INET, &sin.sin_addr, &chars, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }; let ip = String(cString: chars); if eligibleInterface(flags: item.pointee.ifa_flags, address: ip) { result.insert(ip) } }
        return result.sorted()
    }

    private static func validIPv4(_ value: String) -> Bool { var address = in_addr(); guard inet_pton(AF_INET, value, &address) == 1 else { return false }; let host = UInt32(bigEndian: address.s_addr); return host >> 24 > 0 && host >> 24 != 127 && host >> 24 < 224 }
}

private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock(); private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
