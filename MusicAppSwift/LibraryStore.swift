import Foundation
import Combine

class LibraryStore: ObservableObject {
    @Published var songs: [Song] = []
    @Published var playlists: [Playlist] = []
    @Published var recentlyPlayedAlbums: [NaaSearchResult] = []
    
    static let shared = LibraryStore()
    
    private let storageKey = "saved_songs"
    private let playlistsKey = "saved_playlists"
    private let recentAlbumsKey = "recent_albums"
    private let watchedFolderBookmarkKey = "watched_folder_bookmark"
    private var folderWatcher: DispatchSourceFileSystemObject?
    
    var downloadedSongs: [Song] {
        return songs.filter { $0.fileURL.path.contains("/Documents/Downloads/") }
    }
    
    // Internal directory for downloaded songs
    var downloadsFolder: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let downloadsPath = paths[0].appendingPathComponent("Downloads", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: downloadsPath.path) {
            try? FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)
        }
        return downloadsPath
    }
    
    private init() {
        loadPlaylists()
        loadRecentAlbums()
        loadFolderBookmark()
        // Always scan both on init
        refreshLibrary()
    }
    
    func setWatchedFolder(url: URL) {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Save bookmark for persistence
        if let bookmarkData = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmarkData, forKey: watchedFolderBookmarkKey)
        }
        
        startWatching(url: url)
        refreshLibrary()
    }
    
    private func loadFolderBookmark() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: watchedFolderBookmarkKey) else {
            return
        }
        
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            if isStale {
                // Handle stale bookmark if needed
            }
            
            if url.startAccessingSecurityScopedResource() {
                startWatching(url: url)
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
            self?.refreshLibrary()
        }
        
        folderWatcher?.setCancelHandler {
            close(descriptor)
        }
        
        folderWatcher?.resume()
    }
    
    func refreshLibrary() {
        var allSongs: [Song] = []
        
        // 1. Scan internal Downloads folder
        allSongs.append(contentsOf: scan(url: downloadsFolder))
        
        // 2. Scan external Watched folder if available
        if let bookmarkData = UserDefaults.standard.data(forKey: watchedFolderBookmarkKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                // Since it might already be open or needing security scope:
                let accessed = url.startAccessingSecurityScopedResource()
                allSongs.append(contentsOf: scan(url: url))
                if accessed {
                    // We keep it open if it's the watched folder usually, 
                    // but for a one-off scan we can stop if we handle watcher separately.
                    // However, keeping it simple: scan is fast.
                }
            }
        }
        
        // Sort by title
        let sortedSongs = allSongs.sorted { $0.title.lowercased() < $1.title.lowercased() }
        
        DispatchQueue.main.async {
            self.songs = sortedSongs
            self.saveSongs()
        }
    }
    
    private func scan(url: URL) -> [Song] {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.nameKey, .isDirectoryKey]
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        
        var foundSongs: [Song] = []
        
        for case let fileURL as URL in enumerator {
            let pathExtension = fileURL.pathExtension.lowercased()
            if ["mp3", "m4a", "wav", "aac"].contains(pathExtension) {
                var artworkURL: URL? = nil
                
                // Check if a corresponding .jpg exists for this song (common for downloads)
                let artworkFilename = fileURL.lastPathComponent.replacingOccurrences(of: ".\(pathExtension)", with: ".jpg", options: .caseInsensitive)
                let potentialArtwork = fileURL.deletingLastPathComponent().appendingPathComponent(artworkFilename)
                if FileManager.default.fileExists(atPath: potentialArtwork.path) {
                    artworkURL = potentialArtwork
                }
                
                let song = Song(
                    id: UUID(stableFrom: fileURL.path),
                    title: fileURL.deletingPathExtension().lastPathComponent,
                    fileURL: fileURL,
                    artworkURL: artworkURL
                )
                foundSongs.append(song)
            }
        }
        return foundSongs
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
    
    func addToRecentlyPlayed(album: NaaSearchResult) {
        // Remove if already exists to move to top
        recentlyPlayedAlbums.removeAll { $0.link == album.link }
        recentlyPlayedAlbums.insert(album, at: 0)
        
        // Keep max 20
        if recentlyPlayedAlbums.count > 20 {
            recentlyPlayedAlbums.removeLast()
        }
        
        saveRecentAlbums()
    }
    
    private func saveRecentAlbums() {
        if let encoded = try? JSONEncoder().encode(recentlyPlayedAlbums) {
            UserDefaults.standard.set(encoded, forKey: recentAlbumsKey)
        }
    }
    
    private func loadRecentAlbums() {
        if let data = UserDefaults.standard.data(forKey: recentAlbumsKey),
           let decoded = try? JSONDecoder().decode([NaaSearchResult].self, from: data) {
            self.recentlyPlayedAlbums = decoded
        }
    }
}
