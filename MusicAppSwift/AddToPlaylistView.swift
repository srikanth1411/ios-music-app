import SwiftUI

struct AddToPlaylistView: View {
    let song: Song
    @StateObject var library = LibraryStore.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(library.playlists) { playlist in
                    Button(action: {
                        library.addSongToPlaylist(song: song, playlist: playlist)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "music.note.list")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            
                            Text(playlist.name)
                                .font(.headline)
                                .padding(.leading, 8)
                            
                            Spacer()
                            
                            if playlist.songIDs.contains(song.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.pink)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
