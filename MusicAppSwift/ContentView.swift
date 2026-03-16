import SwiftUI

struct MiniPlayer: View {
    @ObservedObject var playback = PlaybackManager.shared
    var onTap: () -> Void
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: "music.note").foregroundColor(.gray))
                .onTapGesture(perform: onTap)
            
            VStack(alignment: .leading) {
                Text(playback.currentSong?.title ?? "Not Playing")
                    .font(.body.bold())
                Text(playback.currentSong?.artist ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onTapGesture(perform: onTap)
            
            Spacer()
            
            Button(action: {
                if playback.isPlaying {
                    playback.pause()
                } else {
                    playback.resume()
                }
            }) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .padding(.trailing, 10)
            
            Button(action: {}) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 10)
        .shadow(radius: 5)
    }
}

struct ContentView: View {
    @StateObject var playback = PlaybackManager.shared
    @State private var showFullPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "music.note")
                    }
                
                PlaylistListView()
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
            }
            .accentColor(.pink)
            
            if playback.currentSong != nil {
                MiniPlayer {
                    showFullPlayer = true
                }
                .transition(.move(edge: .bottom))
                .offset(y: -50) // Adjust based on TabView height
            }
            
            if !playback.permissionsAuthorized {
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.pink)
                    
                    Text("Authorize Background Audio")
                        .font(.title2.bold())
                    
                    Text("iOS requires specific authorization for apps to play music in the background. Tap the button below to grant access.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        playback.authorizeBackgroundAudio()
                    }) {
                        Text("Grant Background Permission")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.pink)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    
                    Text("Note: This will request Media Library access and activate the Audio Session for background playback.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #if os(iOS)
                .background(Color(uiColor: .systemBackground))
                #else
                .background(Color(nsColor: .windowBackgroundColor))
                #endif
                .zIndex(100)
            }
        }
        .sheet(isPresented: $showFullPlayer) {
            PlayerView()
        }
    }
}
