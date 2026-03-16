import Foundation

struct ReplacementChunkInfo {
    let allowMultiple: Bool
    let targetContent: String
    let replacementContent: String
    let startLine: Int
    let endLine: Int
}
struct BrowserRecordingInfo {
    let taskId: String
    let relativePath: String
    let originalAbsFilepath: Data?
    let originalCanceledEntry: String?
}

// A lightweight wrapper dict that will hold values for all properties locally.
struct ArtifactDict {
    // Basic types that get returned often
    private var _DataDict: [String: Data] = [:]
    
    init(dataDict: [String: Data]) {
        self._DataDict = dataDict
    }

    var keys: [String] {
        return Array(_DataDict.keys)
    }
    
    private mutating func assignDictInternal(
        data: Data,
        type: String,
        description: String,
        complexity: Int,
        instructions: String?,
        chunks: [ReplacementChunkInfo]?,
        replacedChunksCount: Int?
    ) throws {
        
        // This array dictionary allows storage inside of NS/JSONSerialization structures
        // that handles Any?
        let assignment: [String: Any?] = [
            "Content": data,
            "Type": type,
            "Description": description,
            "Complexity": complexity,
            "Instructions": instructions,
            "Chunks": try Self.encodeChunksInfo(chunks),
            "ReplacedChunksCount": replacedChunksCount
        ]
        
        self._DataDict["Assignment"] = try Self.JSONData(from: assignment as Any)
    }

    private static func encodeChunksInfo(_ items: [ReplacementChunkInfo]?) throws -> Data? {
        guard let items else { return nil }
        return try Self.JSONData(from: items.map {
            [
                "AllowMultiple": $0.allowMultiple,
                "TargetContent": $0.targetContent,
                "ReplacementContent": $0.replacementContent,
                "StartLine": $0.startLine,
                "EndLine": $0.endLine
            ]
        } as Any)
    }

    // Keep encodeRecordings for example, simplified
    private mutating func encodeRecordings(_ items: [BrowserRecordingInfo]) throws {
        _DataDict["Recordings"] = try Self.JSONData(from: items.map {
            [
                "TaskId": $0.taskId,
                "RelativePath": $0.relativePath,
                "AbsoluteFilepath": $0.originalAbsFilepath,
                "IsCanceled": $0.originalCanceledEntry ?? "unknown"
            ]
        } as Any)
    }

    // Mock functions to make the mock structs compile
    private static func JSONData(from object: Any) throws -> Data { return Data() }
}
