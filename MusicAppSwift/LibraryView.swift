import SwiftUI

struct LibraryView: View {
    @StateObject var library = LibraryStore.shared
    @StateObject var playback = PlaybackManager.shared
    @State private var showingPicker = false
    @State private var showingAddToPlaylist = false
    @State private var selectedSong: Song?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: PlaylistListView()) {
                        Label("Playlists", systemImage: "music.note.list")
                            .foregroundColor(.pink)
                    }
                    
                    NavigationLink(destination: OfflineSongsView()) {
                        Label("Downloaded", systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.pink)
                    }
                }
                
                Section(header: Text("Recently Added")) {
                    if library.songs.isEmpty {
                        Text("No songs in library")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(library.songs.prefix(20)) { song in
                            Button(action: {
                                playback.play(song: song)
                            }) {
                                HStack {
                                    // Artwork Thumbnail
                                    if let artworkURL = song.artworkURL {
                                        AsyncImage(url: artworkURL) { phase in
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
                                        Text(song.artist)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if playback.currentSong?.id == song.id && playback.isPlaying {
                                        Image(systemName: "speaker.wave.3.fill")
                                            .foregroundColor(.pink)
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
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingPicker = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.pink)
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                #if os(iOS)
                DocumentPicker(isPresented: $showingPicker) { url in
                    library.setWatchedFolder(url: url)
                }
                #else
                Text("Import only supported on iOS")
                #endif
            }
            .sheet(isPresented: $showingAddToPlaylist) {
                if let song = selectedSong {
                    AddToPlaylistView(song: song)
                }
            }
        }
    }
}
