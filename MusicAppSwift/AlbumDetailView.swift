import SwiftUI

struct AlbumDetailView: View {
    let album: NaaSearchResult
    
    @State private var songs: [NaaSong] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @State private var selectedSongForPlaylist: Song?
    @State private var showingAddToPlaylist = false
    
    @ObservedObject var playback = PlaybackManager.shared
    
    var body: some View {
        List {
            // Album Header
            Section {
                VStack(spacing: 20) {
                    if let imageUrlString = album.imageUrl, let imageUrl = URL(string: imageUrlString) {
                        AsyncImage(url: imageUrl) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.1))
                            }
                        }
                        .frame(width: 200, height: 200)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                    
                    VStack(spacing: 4) {
                        Text(album.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Telugu Album")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            playAlbum()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            shuffleAlbum()
                        }) {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("Shuffle")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }
            
            if !songs.isEmpty {
                Section {
                    Button(action: downloadAll) {
                        Label("Download Entire Album", systemImage: "arrow.down.circle.fill")
                            .font(.headline)
                            .foregroundColor(.pink)
                    }
                }
            }
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading songs from NaaSongs...")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else if songs.isEmpty {
                Text("No songs found for this album.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(songs) { song in
                    HStack {
                        // Artwork Thumbnail
                        if let artworkUrlString = song.artworkUrl, let artworkUrl = URL(string: artworkUrlString) {
                            AsyncImage(url: artworkUrl) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Rectangle().fill(Color.gray.opacity(0.2))
                                }
                            }
                            .frame(width: 44, height: 44)
                            .cornerRadius(4)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .cornerRadius(4)
                                .overlay(Image(systemName: "music.note").foregroundColor(.gray))
                        }
                        
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(isSongDownloaded(song) ? "Downloaded" : "Online Stream")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playNaaSong(song)
                        }
                        
                        Spacer()
                        
                        // Download Section
                        DownloadButton(song: song)
                        
                        if playback.currentSong?.title == song.title && playback.isPlaying {
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.pink)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button(action: {
                            prepareForPlaylist(song)
                        }) {
                            Label("Add to a Playlist...", systemImage: "plus.circle")
                        }
                        
                        if !isSongDownloaded(song) {
                            Button(action: {
                                DownloadManager.shared.download(song)
                            }) {
                                Label("Download", systemImage: "arrow.down")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(album.title)
        .onAppear {
            loadSongs()
            LibraryStore.shared.addToRecentlyPlayed(album: album)
        }
        .sheet(isPresented: $showingAddToPlaylist) {
            if let song = selectedSongForPlaylist {
                AddToPlaylistView(song: song)
            }
        }
    }
    
    private func playAlbum() {
        guard let first = songs.first else { return }
        let queue = songs.map { $0.toSong(albumTitle: album.title) }
        playback.shuffleMode = .off
        playback.play(song: first.toSong(albumTitle: album.title), queue: queue)
    }
    
    private func shuffleAlbum() {
        guard !songs.isEmpty else { return }
        let shuffled = songs.shuffled()
        if let first = shuffled.first {
            let queue = shuffled.map { $0.toSong(albumTitle: album.title) }
            playback.shuffleMode = .on
            playback.play(song: first.toSong(albumTitle: album.title), queue: queue)
        }
    }
    
    private func prepareForPlaylist(_ naaSong: NaaSong) {
        // If it's already downloaded, use the local song for stability
        if let localSong = LibraryStore.shared.songs.first(where: { $0.title == naaSong.title }) {
            selectedSongForPlaylist = localSong
        } else {
            selectedSongForPlaylist = naaSong.toSong(albumTitle: album.title)
        }
        showingAddToPlaylist = true
    }
    
    private func downloadAll() {
        for song in songs {
            if !isSongDownloaded(song) {
                DownloadManager.shared.download(song)
            }
        }
    }
    
    
    // Subview for the download button/status
    struct DownloadButton: View {
        let song: NaaSong
        @ObservedObject var downloadManager = DownloadManager.shared
        @ObservedObject var library = LibraryStore.shared
        
        private var download: DownloadTask? {
            downloadManager.activeDownloads.values.first { $0.song.title == song.title }
        }
        
        private var isDownloaded: Bool {
            library.songs.contains { $0.title == song.title }
        }
        
        var body: some View {
            Group {
                if isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if let download = download {
                    switch download.state {
                    case .waiting:
                        ProgressView()
                            .scaleEffect(0.8)
                    case .downloading(let progress):
                        ZStack {
                            CircularProgressView(progress: progress)
                                .frame(width: 24, height: 24)
                            Button(action: {}) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.pink)
                            }
                        }
                    case .failed(let error):
                        Button(action: { downloadManager.download(song) }) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .help(error)
                    case .completed:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } else {
                    Button(action: {
                        downloadManager.download(song)
                    }) {
                        Image(systemName: "arrow.down.circle")
                            .font(.title3)
                            .foregroundColor(.pink)
                    }
                }
            }
            .frame(width: 30)
        }
        
    }
    
    struct CircularProgressView: View {
        let progress: Double
        
        var body: some View {
            ZStack {
                Circle()
                    .stroke(lineWidth: 3)
                    .opacity(0.3)
                    .foregroundColor(.gray)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.pink)
                    .rotationEffect(Angle(degrees: 270.0))
            }
        }
    }
    
    private func loadSongs() {
        guard songs.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedSongs = try await NaaSongsService.shared.getSongs(from: album.link)
                await MainActor.run {
                    self.songs = fetchedSongs
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load songs from NaaSongs: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func isSongDownloaded(_ song: NaaSong) -> Bool {
        LibraryStore.shared.songs.contains { $0.title == song.title }
    }
    
    private func playNaaSong(_ song: NaaSong) {
        let queue = songs.map { $0.toSong(albumTitle: album.title) }
        playback.shuffleMode = .off
        
        if let localSong = LibraryStore.shared.songs.first(where: { $0.title == song.title }) {
            playback.play(song: localSong, queue: queue)
            return
        }
        
        playback.play(song: song.toSong(albumTitle: album.title), queue: queue)
    }
}


