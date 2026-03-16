import SwiftUI

struct OfflineSongsView: View {
    @StateObject var library = LibraryStore.shared
    @StateObject var playback = PlaybackManager.shared
    @State private var showingAddToPlaylist = false
    @State private var selectedSong: Song?
    
    var body: some View {
        NavigationView {
            List {
                if library.downloadedSongs.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Offline Songs")
                            .font(.title2.bold())
                        Text("Songs you download from search will appear here for offline playback.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    ForEach(library.downloadedSongs) { song in
                        Button(action: {
                            playback.play(song: song)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(song.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(song.artist)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if playback.currentSong?.id == song.id && playback.isPlaying {
                                    Image(systemName: "speaker.wave.3.fill")
                                        .foregroundColor(.pink)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                        }
                        .contextMenu {
                            Button(action: {
                                selectedSong = song
                                showingAddToPlaylist = true
                            }) {
                                Label("Add to a Playlist...", systemImage: "plus.circle")
                            }
                            
                            Button(role: .destructive, action: {
                                deleteSong(song)
                            }) {
                                Label("Delete from Downloads", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Offline Songs")
            .sheet(isPresented: $showingAddToPlaylist) {
                if let song = selectedSong {
                    AddToPlaylistView(song: song)
                }
            }
        }
    }
    
    private func deleteSong(_ song: Song) {
        try? FileManager.default.removeItem(at: song.fileURL)
        library.refreshLibrary()
    }
}
