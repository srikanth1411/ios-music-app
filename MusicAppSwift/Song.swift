import Foundation

// MARK: - Stable UUID from String
extension UUID {
    /// Creates a deterministic UUID by hashing `string`.
    /// The same string will always produce the same UUID, which is
    /// critical for keeping playlist song references stable after restarts.
    init(stableFrom string: String) {
        var hash = string.utf8.reduce(into: (UInt64(0), UInt64(0))) { acc, byte in
            acc.0 = acc.0 &* 31 &+ UInt64(byte)
            acc.1 = acc.1 &* 37 &+ UInt64(byte)
        }
        // Build 16 bytes from the two 8-byte hashes
        let a = withUnsafeBytes(of: &hash.0) { Array($0) }
        let b = withUnsafeBytes(of: &hash.1) { Array($0) }
        let bytes = a + b
        self = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            // Set version 5-style bits
            (bytes[6] & 0x0F) | 0x50, bytes[7],
            // Set variant bits
            (bytes[8] & 0x3F) | 0x80, bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

struct Song: Identifiable, Codable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let fileURL: URL
    let duration: TimeInterval
    
    // We'll handle artwork via a helper or at the UI layer to avoid Model-level UI framework dependencies
    
    init(id: UUID = UUID(), title: String, artist: String = "Unknown Artist", album: String = "Unknown Album", fileURL: URL, duration: TimeInterval = 0) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.fileURL = fileURL
        self.duration = duration
    }
}

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var songIDs: [UUID]
    
    init(id: UUID = UUID(), name: String, songIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.songIDs = songIDs
    }
}
