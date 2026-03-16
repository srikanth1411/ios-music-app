import SwiftUI

struct NaaAlbumDetailView: View {
    let albumResult: NaaSearchResult
    
    @State private var songs: [NaaSong] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @ObservedObject var playback = PlaybackManager.shared
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading songs...")
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
                        Button(action: {
                            playNaaSong(song)
                        }) {
                            VStack(alignment: .leading) {
                                Text(song.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Online Stream")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
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
                }
            }
        }
        .navigationTitle(albumResult.title)
        .onAppear {
            loadSongs()
        }
    }
    
    // Subview for the download button/status
    struct DownloadButton: View {
        let song: NaaSong
        @ObservedObject var downloadManager = DownloadManager.shared
        @ObservedObject var library = LibraryStore.shared
        
        private var download: DownloadTask? {
            downloadManager.activeDownloads[song.id]
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
                let fetchedSongs = try await NaaSongsService.shared.getSongs(from: albumResult.link)
                await MainActor.run {
                    self.songs = fetchedSongs
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load songs: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func playNaaSong(_ naaSong: NaaSong) {
        guard let url = URL(string: naaSong.downloadUrl) else { return }
        
        // We temporarily create a pseudo-Song object with the remote URL to feed to the PlaybackManager
        // Since Song id usually expects a stable local UUID, we'll generate one
        let newSong = Song(id: UUID(), title: naaSong.title, fileURL: url)
        
        // Our existing PlaybackManager expects URL streams to work fine since AVPlayer handles it transparently
        playback.play(song: newSong)
    }
}
