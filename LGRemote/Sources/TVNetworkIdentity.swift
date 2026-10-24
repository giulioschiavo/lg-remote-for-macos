import Foundation
import Darwin

struct MACCandidate: Identifiable, Equatable {
    let address: String
    let source: String

    var id: String { "\(source):\(address)" }
}

enum TVNetworkIdentity {
    static func fromAPI(_ value: [String: Any], status: [String: Any]? = nil) -> [MACCandidate] {
        var candidates: [MACCandidate] = []
        for (interface, infoKey) in [("wifi", "wifiInfo"), ("wired", "wiredInfo")] {
            guard let details = (value[interface] as? [String: Any]) ?? (value[infoKey] as? [String: Any]),
                  let raw = details["macAddress"] as? String ?? details["mac"] as? String,
                  let address = normalize(raw) else { continue }
            let statusDetails = status?[interface] as? [String: Any]
            guard !isExplicitlyInactive(details), !(statusDetails.map(isExplicitlyInactive) ?? false) else { continue }
            let confirmed = isExplicitlyActive(details) || (statusDetails.map(isExplicitlyActive) ?? false)
            let source = confirmed ? interface : "\(interface)-unverified"
            let candidate = MACCandidate(address: address, source: source)
            if let index = candidates.firstIndex(where: { $0.address == address }) {
                if candidates[index].source.hasSuffix("-unverified") && confirmed { candidates[index] = candidate }
            } else { candidates.append(candidate) }
        }
        return candidates
    }

    static func fromARP(host: String) async -> MACCandidate? {
        await Task.detached(priority: .utility) {
            guard let ip = resolveIPv4(host) else { return nil }
            return queryARP(ip: ip)
        }.value
    }

    static func broadcast(for host: String) async -> String? {
        await Task.detached(priority: .utility) {
            guard let target = resolveIPv4(host) else { return nil }
            let broadcasts = directedBroadcasts(targetIP: target)
            return broadcasts.count == 1 ? broadcasts.first : nil
        }.value
    }

    static func directedBroadcast(localIP: String, mask: String, targetIP: String) -> String? {
        guard let local = numericIPv4(localIP), let networkMask = numericIPv4(mask), let target = numericIPv4(targetIP),
              let prefix = maskPrefix(networkMask), prefix > 0, prefix <= 30, local & networkMask == target & networkMask else { return nil }
        return dotted(local | ~networkMask)
    }

    static func parseARPOutput(_ output: String, ip: String) -> MACCandidate? {
        for line in output.split(whereSeparator: { $0.isNewline }) {
            let text = String(line)
            guard text.contains("(\(ip))") else { continue }
            let tokens = text.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let index = tokens.firstIndex(of: Substring("at")), tokens.indices.contains(index + 1),
                  let address = normalize(String(tokens[index + 1])) else { continue }
            return MACCandidate(address: address, source: "arp-unverified")
        }
        return nil
    }

    private static func isExplicitlyActive(_ details: [String: Any]) -> Bool {
        (details["connected"] as? Bool == true) || (details["state"] as? String)?.lowercased() == "connected"
    }

    private static func isExplicitlyInactive(_ details: [String: Any]) -> Bool {
        (details["connected"] as? Bool == false) || (details["state"] as? String)?.lowercased() == "disconnected"
    }

    private static func normalize(_ raw: String) -> String? {
        let compact: String
        let separators = CharacterSet(charactersIn: ":-.")
        if raw.rangeOfCharacter(from: separators) != nil {
            let parts = raw.split(omittingEmptySubsequences: false) { separators.contains($0.unicodeScalars.first!) }
            guard parts.count == 6, parts.allSatisfy({ (1...2).contains($0.count) }) else { return nil }
            compact = parts.map { String($0).leftPad(to: 2, with: "0") }.joined()
        } else {
            guard raw.count == 12 else { return nil }
            compact = raw
        }
        guard compact.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        let octets = stride(from: 0, to: compact.count, by: 2).compactMap { index -> UInt8? in
            let start = compact.index(compact.startIndex, offsetBy: index)
            let end = compact.index(start, offsetBy: 2)
            return UInt8(compact[start..<end], radix: 16)
        }
        guard octets.count == 6, octets.contains(where: { $0 != 0 }), octets.contains(where: { $0 != 255 }),
              octets[0] & 1 == 0 else { return nil }
        return octets.map { String(format: "%02x", $0) }.joined(separator: ":")
    }

    static func resolveIPv4(_ host: String) -> String? {
        var literal = in_addr()
        if inet_pton(AF_INET, host, &literal) == 1 { return host }
        var hints = addrinfo(ai_flags: 0, ai_family: AF_INET, ai_socktype: SOCK_STREAM, ai_protocol: 0,
                             ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { return nil }
        defer { freeaddrinfo(first) }
        var addresses = Set<String>()
        var current: UnsafeMutablePointer<addrinfo>? = first
        while let item = current {
            guard let pointer = item.pointee.ai_addr, item.pointee.ai_family == AF_INET else { return nil }
            var address = pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
            addresses.insert(String(cString: buffer))
            current = item.pointee.ai_next
        }
        return addresses.count == 1 ? addresses.first : nil
    }

    private static func queryARP(ip: String) -> MACCandidate? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        process.arguments = ["-n", ip]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return parseARPOutput(String(decoding: data, as: UTF8.self), ip: ip)
        } catch { return nil }
    }

    private static func directedBroadcasts(targetIP: String) -> Set<String> {
        var result = Set<String>(); var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return result }
        defer { freeifaddrs(first) }
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let item = current {
            defer { current = item.pointee.ifa_next }
            let flags = item.pointee.ifa_flags
            guard flags & UInt32(IFF_UP | IFF_BROADCAST) == UInt32(IFF_UP | IFF_BROADCAST), flags & UInt32(IFF_LOOPBACK) == 0,
                  let address = item.pointee.ifa_addr, let mask = item.pointee.ifa_netmask,
                  address.pointee.sa_family == UInt8(AF_INET), mask.pointee.sa_family == UInt8(AF_INET) else { continue }
            let localIP = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { dotted(UInt32(bigEndian: $0.pointee.sin_addr.s_addr)) }
            let maskIP = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { dotted(UInt32(bigEndian: $0.pointee.sin_addr.s_addr)) }
            if let broadcast = directedBroadcast(localIP: localIP, mask: maskIP, targetIP: targetIP) { result.insert(broadcast) }
        }
        return result
    }

    private static func numericIPv4(_ value: String) -> UInt32? {
        var address = in_addr(); guard inet_pton(AF_INET, value, &address) == 1 else { return nil }
        return UInt32(bigEndian: address.s_addr)
    }

    private static func maskPrefix(_ mask: UInt32) -> Int? {
        var seenZero = false; var count = 0
        for bit in stride(from: 31, through: 0, by: -1) {
            if mask & (UInt32(1) << UInt32(bit)) != 0 {
                guard !seenZero else { return nil }; count += 1
            } else { seenZero = true }
        }
        return count
    }

    private static func dotted(_ value: UInt32) -> String {
        "\((value >> 24) & 255).\((value >> 16) & 255).\((value >> 8) & 255).\(value & 255)"
    }
}

private extension String {
    func leftPad(to length: Int, with character: Character) -> String {
        String(repeating: String(character), count: max(0, length - count)) + self
    }
}
