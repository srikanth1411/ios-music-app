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
                    Button(action: {
                        playNaaSong(song)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(song.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Online Stream")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if playback.currentSong?.title == song.title && playback.isPlaying {
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundColor(.pink)
                            }
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
