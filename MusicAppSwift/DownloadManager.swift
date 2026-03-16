import Foundation
import Combine

enum DownloadState: Equatable {
    case waiting
    case downloading(progress: Double)
    case completed
    case failed(error: String)
}

struct DownloadTask: Identifiable {
    let id: UUID
    let song: NaaSong
    var state: DownloadState
}

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    @Published var activeDownloads: [UUID: DownloadTask] = [:]
    
    private var urlSession: URLSession!
    private var tasks: [Int: UUID] = [:] // mapping sessionTaskID to songID
    
    private override init() {
        super.init()
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.srikanth1411.MusicAppSwift.downloads")
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    func download(_ song: NaaSong) {
        // Prevent duplicate downloads
        if activeDownloads.values.contains(where: { $0.song.downloadUrl == song.downloadUrl }) {
            return
        }
        
        guard let url = URL(string: song.downloadUrl) else { return }
        
        let songID = song.id
        let task = DownloadTask(id: songID, song: song, state: .waiting)
        activeDownloads[songID] = task
        
        let downloadTask = urlSession.downloadTask(with: url)
        tasks[downloadTask.taskIdentifier] = songID
        downloadTask.resume()
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let songID = tasks[downloadTask.taskIdentifier],
              var download = activeDownloads[songID] else { return }
        
        let fileManager = FileManager.default
        let destinationURL = LibraryStore.shared.downloadsFolder.appendingPathComponent("\(download.song.title).mp3")
        
        do {
            // Remove existing file if any
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.moveItem(at: location, to: destinationURL)
            
            DispatchQueue.main.async {
                download.state = .completed
                self.activeDownloads[songID] = download
                
                // Refresh library to show the new song
                LibraryStore.shared.refreshLibrary()
                
                // Remove from active downloads after a delay or immediately
                self.activeDownloads.removeValue(forKey: songID)
            }
        } catch {
            print("Download error: \(error)")
            DispatchQueue.main.async {
                download.state = .failed(error: error.localizedDescription)
                self.activeDownloads[songID] = download
            }
        }
        
        tasks.removeValue(forKey: downloadTask.taskIdentifier)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let songID = tasks[downloadTask.taskIdentifier],
              var download = activeDownloads[songID] else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            download.state = .downloading(progress: progress)
            self.activeDownloads[songID] = download
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            guard let songID = tasks[task.taskIdentifier],
                  var download = activeDownloads[songID] else { return }
            
            DispatchQueue.main.async {
                download.state = .failed(error: error.localizedDescription)
                self.activeDownloads[songID] = download
            }
        }
        tasks.removeValue(forKey: task.taskIdentifier)
    }
}
