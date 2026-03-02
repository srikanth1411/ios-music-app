import Foundation
import Combine

class LibraryStore: ObservableObject {
    @Published var songs: [Song] = []
    @Published var playlists: [Playlist] = []
    
    static let shared = LibraryStore()
    
    private let storageKey = "saved_songs"
    private let playlistsKey = "saved_playlists"
    private let folderBookmarkKey = "watched_folder_bookmark"
    private var folderWatcher: DispatchSourceFileSystemObject?
    
    private init() {
        loadSongs()
        loadPlaylists()
        loadFolderBookmark()
    }
    
    func setWatchedFolder(url: URL) {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Save bookmark for persistence
        if let bookmarkData = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmarkData, forKey: folderBookmarkKey)
        }
        
        startWatching(url: url)
        scanFolder(url: url)
    }
    
    private func loadFolderBookmark() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: folderBookmarkKey) else {
            loadSongs() // Fallback to old storage if no folder set
            return
        }
        
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            if isStale {
                // Handle stale bookmark if needed
            }
            
            if url.startAccessingSecurityScopedResource() {
                startWatching(url: url)
                scanFolder(url: url)
                // Note: We don't stopAccessing here because the watcher needs it
            }
        }
    }
    
    private func startWatching(url: URL) {
        folderWatcher?.cancel()
        
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else { return }
        
        folderWatcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        
        folderWatcher?.setEventHandler { [weak self] in
            print("Folder changed, re-scanning...")
            self?.scanFolder(url: url)
        }
        
        folderWatcher?.setCancelHandler {
            close(descriptor)
        }
        
        folderWatcher?.resume()
    }
    
    func scanFolder(url: URL) {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.nameKey, .isDirectoryKey]
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return }
        
        var newSongs: [Song] = []
        
        for case let fileURL as URL in enumerator {
            let pathExtension = fileURL.pathExtension.lowercased()
            if ["mp3", "m4a", "wav", "aac"].contains(pathExtension) {
                let title = fileURL.deletingPathExtension().lastPathComponent
                // Use a stable UUID derived from the absolute file path so that
                // playlist references remain valid across app restarts.
                let stableID = UUID(stableFrom: fileURL.path)
                let song = Song(id: stableID, title: title, fileURL: fileURL)
                newSongs.append(song)
            }
        }
        
        DispatchQueue.main.async {
            self.songs = newSongs
            self.saveSongs()
        }
    }
    
    func addSong(_ song: Song) {
        songs.append(song)
        saveSongs()
    }
    
    private func saveSongs() {
        if let encoded = try? JSONEncoder().encode(songs) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadSongs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Song].self, from: data) {
            self.songs = decoded
        }
    }
    
    // MARK: - Playlist Management
    
    func createPlaylist(name: String) {
        let newPlaylist = Playlist(name: name)
        playlists.append(newPlaylist)
        savePlaylists()
    }
    
    func deletePlaylist(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        savePlaylists()
    }
    
    func addSongToPlaylist(song: Song, playlist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            if !playlists[index].songIDs.contains(song.id) {
                playlists[index].songIDs.append(song.id)
                savePlaylists()
            }
        }
    }
    
    func removeSongFromPlaylist(songID: UUID, playlistID: UUID) {
        if let index = playlists.firstIndex(where: { $0.id == playlistID }) {
            playlists[index].songIDs.removeAll(where: { $0 == songID })
            savePlaylists()
        }
    }
    
    private func savePlaylists() {
        if let encoded = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(encoded, forKey: playlistsKey)
        }
    }
    
    private func loadPlaylists() {
        if let data = UserDefaults.standard.data(forKey: playlistsKey),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            self.playlists = decoded
        }
    }
}
