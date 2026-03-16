import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @StateObject var library = LibraryStore.shared
    @StateObject var playback = PlaybackManager.shared
    
    var playlistSongs: [Song] {
        playlist.songIDs.compactMap { id in
            library.songs.first(where: { $0.id == id })
        }
    }
    
    @State private var selectedSongForPlaylist: Song?
    @State private var showingAddToPlaylist = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 200, height: 200)
                            Image(systemName: "music.note.list")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                        }
                        .shadow(radius: 10)
                        
                        Text(playlist.name)
                            .font(.title.bold())
                            .padding(.top)
                        
                        Text("Playlist • \(playlistSongs.count) songs")
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                if let first = playlistSongs.first {
                                    playback.shuffleMode = .off
                                    playback.play(song: first, queue: playlistSongs)
                                }
                            }) {
                                Label("Play", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                // Shuffle play
                                if !playlistSongs.isEmpty {
                                    let shuffled = playlistSongs.shuffled()
                                    if let first = shuffled.first {
                                        playback.shuffleMode = .on
                                        playback.play(song: first, queue: shuffled)
                                    }
                                }
                            }) {
                                Label("Shuffle", systemImage: "shuffle")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.top)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical)
            }
            
            ForEach(playlistSongs) { song in
                Button(action: {
                    playback.shuffleMode = .off
                    playback.play(song: song, queue: playlistSongs)
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
                        }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        library.removeSongFromPlaylist(songID: song.id, playlistID: playlist.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(action: {
                        selectedSongForPlaylist = song
                        showingAddToPlaylist = true
                    }) {
                        Label("Add to a Playlist...", systemImage: "plus.circle")
                    }
                    
                    Button(role: .destructive, action: {
                        library.removeSongFromPlaylist(songID: song.id, playlistID: playlist.id)
                    }) {
                        Label("Remove from this Playlist", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingAddToPlaylist) {
            if let song = selectedSongForPlaylist {
                AddToPlaylistView(song: song)
            }
        }
    }
}
