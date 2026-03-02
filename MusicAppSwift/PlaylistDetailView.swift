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
                                    playback.play(song: first)
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
                                if let shuffled = playlistSongs.shuffled().first {
                                    playback.play(song: shuffled)
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
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
