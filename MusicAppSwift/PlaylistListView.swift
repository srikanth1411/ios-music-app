import SwiftUI

struct PlaylistListView: View {
    @StateObject var library = LibraryStore.shared
    @State private var showingCreateSheet = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(library.playlists) { playlist in
                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "music.note.list")
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(playlist.name)
                                    .font(.headline)
                                Text("\(playlist.songIDs.count) songs")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
                .onDelete(perform: library.deletePlaylist)
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.pink)
                    }
                }
            }
            .alert("New Playlist", isPresented: $showingCreateSheet) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) { newPlaylistName = "" }
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        library.createPlaylist(name: newPlaylistName)
                        newPlaylistName = ""
                    }
                }
            } message: {
                Text("Enter a name for your new playlist.")
            }
        }
    }
}
