#!/usr/bin/env swift

import Foundation

print("🧪 Testing BSD Sockets")
print("=====================")

// Import required C functions
func socket(_ domain: Int32, _ type: Int32, _ protocol: Int32) -> Int32 {
    return Darwin.socket(domain, type, `protocol`)
}

func bind(_ socket: Int32, _ addr: UnsafePointer<sockaddr>, _ len: socklen_t) -> Int32 {
    return Darwin.bind(socket, addr, len)
}

func listen(_ socket: Int32, _ backlog: Int32) -> Int32 {
    return Darwin.listen(socket, backlog)
}

// Test BSD socket creation
let sockfd = socket(AF_INET, SOCK_STREAM, 0)
if sockfd == -1 {
    print("❌ Failed to create socket: \(String(cString: strerror(errno)))")
    exit(1)
}
print("✅ BSD socket created successfully: \(sockfd)")

// Setup socket address
var addr = sockaddr_in()
addr.sin_family = sa_family_t(AF_INET)
addr.sin_port = in_port_t(8888).bigEndian
addr.sin_addr.s_addr = INADDR_ANY.bigEndian

let result = withUnsafePointer(to: addr) { ptr in
    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
        bind(sockfd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
}

if result == -1 {
    print("❌ Failed to bind socket to port 8888: \(String(cString: strerror(errno)))")
    close(sockfd)
    exit(1)
}
print("✅ Socket bound to port 8888")

if listen(sockfd, 5) == -1 {
    print("❌ Failed to listen on socket: \(String(cString: strerror(errno)))")
    close(sockfd)
    exit(1)
}
print("🎉 Socket listening on port 8888!")

// Check with netstat
print("📊 Verifying with netstat...")
let task = Process()
task.launchPath = "/usr/bin/netstat"
task.arguments = ["-an", "-p", "tcp"]
let pipe = Pipe()
task.standardOutput = pipe
task.launch()
task.waitUntilExit()

let data = pipe.fileHandleForReading.readDataToEndOfFile()
if let output = String(data: data, encoding: .utf8) {
    let lines = output.components(separatedBy: .newlines)
    for line in lines {
        if line.contains(":8888") {
            print("✅ Found listening socket: \(line)")
        }
    }
}

close(sockfd)
print("🏁 BSD socket test completed")