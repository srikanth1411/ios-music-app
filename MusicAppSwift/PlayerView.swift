import SwiftUI

struct PlayerView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    // Scrubbing states
    @State private var isDraggingSlider = false
    @State private var sliderValue: TimeInterval = 0
    
    @State private var showingAddToPlaylist = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Adaptive Background (Blit of Artwork)
                Group {
                    if let artworkURL = playback.currentSong?.artworkURL {
                        AsyncImage(url: artworkURL) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray.opacity(0.1)
                            }
                        }
                    } else {
                        Color.gray.opacity(0.1)
                    }
                }
                .frame(width: geometry.size.width * 1.5, height: geometry.size.height * 1.5)
                .blur(radius: 100)
                .opacity(0.6)
                .background(Color.black)
                .ignoresSafeArea()
                
                VStack(spacing: geometry.size.height * 0.04) {
                    Spacer()
                    
                    // Adaptive Artwork
                    let size = min(geometry.size.width * 0.8, geometry.size.height * 0.4)
                    
                    Group {
                        if let artworkURL = playback.currentSong?.artworkURL {
                            AsyncImage(url: artworkURL) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    artworkFallback(size: size)
                                }
                            }
                        } else {
                            artworkFallback(size: size)
                        }
                    }
                    .frame(width: size, height: size)
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Text(playback.currentSong?.title ?? "Not Playing")
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                Text(playback.currentSong?.artist ?? "")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Spacer()
                        }
                        .overlay(alignment: .trailing) {
                            Menu {
                                Button(action: {
                                    showingAddToPlaylist = true
                                }) {
                                    Label("Add to a Playlist...", systemImage: "plus.circle")
                                }
                                
                                Divider()
                                
                                Menu("Sleep Timer") {
                                    if playback.sleepTimerRemaining != nil {
                                        Button(action: { playback.cancelSleepTimer() }) {
                                            Label("Turn Off Timer", systemImage: "timer.circle")
                                        }
                                    }
                                    
                                    Button("15 Minutes") { playback.setSleepTimer(minutes: 15) }
                                    Button("30 Minutes") { playback.setSleepTimer(minutes: 30) }
                                    Button("45 Minutes") { playback.setSleepTimer(minutes: 45) }
                                    Button("1 Hour") { playback.setSleepTimer(minutes: 60) }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.trailing, 20)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Sleep Timer Status
                    if let remaining = playback.sleepTimerRemaining {
                        Text("Timer: \(formatTime(remaining))")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .foregroundColor(.white)
                    }
                    
                    // Progress Slider
                    VStack {
                        Slider(
                            value: Binding(
                                get: { isDraggingSlider ? sliderValue : playback.currentTime },
                                set: { newValue in
                                    sliderValue = newValue
                                }
                            ),
                            in: 0...max(0.1, playback.duration),
                            onEditingChanged: { editing in
                                isDraggingSlider = editing
                                if !editing {
                                    playback.seek(to: sliderValue)
                                }
                            }
                        )
                        .accentColor(.white)
                        
                        HStack {
                            Text(formatTime(isDraggingSlider ? sliderValue : playback.currentTime))
                            Spacer()
                            Text(formatTime(playback.duration))
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 30)
                    
                    // Controls
                    VStack(spacing: 30) {
                        HStack(spacing: 50) {
                            Button(action: { playback.playPrevious() }) {
                                Image(systemName: "backward.fill")
                                    .font(.title)
                            }
                            
                            Button(action: {
                                if playback.isPlaying {
                                    playback.pause()
                                } else {
                                    playback.resume()
                                }
                            }) {
                                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 50))
                            }
                            
                            Button(action: { playback.playNext() }) {
                                Image(systemName: "forward.fill")
                                    .font(.title)
                            }
                        }
                        .accentColor(.white)
                        
                        HStack(spacing: 60) {
                            Button(action: { playback.toggleShuffle() }) {
                                Image(systemName: "shuffle")
                                    .font(.headline)
                                    .foregroundColor(playback.shuffleMode == .on ? .pink : .white.opacity(0.7))
                            }
                            
                            Button(action: { playback.toggleRepeat() }) {
                                Image(systemName: playback.repeatMode == .one ? "repeat.1" : "repeat")
                                    .font(.headline)
                                    .foregroundColor(playback.repeatMode != .off ? .pink : .white.opacity(0.7))
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingAddToPlaylist) {
            if let song = playback.currentSong {
                AddToPlaylistView(song: song)
            }
        }
    }
    
    private func artworkFallback(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3))
                    .foregroundColor(.gray)
            )
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
