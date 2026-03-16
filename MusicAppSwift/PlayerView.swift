import SwiftUI

struct PlayerView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    // Scrubbing states
    @State private var isDraggingSlider = false
    @State private var sliderValue: TimeInterval = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background blur
                Rectangle()
                    .fill(Color(white: 0.1).opacity(0.1)) // Placeholder or clear
                    .background(.ultraThinMaterial)
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
                    Text(playback.currentSong?.title ?? "Not Playing")
                        .font(.title2.bold())
                    Text(playback.currentSong?.artist ?? "Unknown Artist")
                        .font(.title3)
                        .foregroundColor(.secondary)
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
                    .accentColor(.pink)
                    
                    HStack {
                        Text(formatTime(isDraggingSlider ? sliderValue : playback.currentTime))
                        Spacer()
                        Text(formatTime(playback.duration))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    .accentColor(.primary)
                    
                    HStack(spacing: 60) {
                        Button(action: { playback.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.headline)
                                .foregroundColor(playback.shuffleMode == .on ? .pink : .secondary)
                        }
                        
                        Button(action: { playback.toggleRepeat() }) {
                            Image(systemName: playback.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.headline)
                                .foregroundColor(playback.repeatMode != .off ? .pink : .secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
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
