import Foundation
import AVFoundation
import Combine
import MediaPlayer

enum ShuffleMode {
    case off, on
}

enum RepeatMode {
    case off, all, one
}

class PlaybackManager: ObservableObject {
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var shuffleMode: ShuffleMode = .off
    @Published var repeatMode: RepeatMode = .off
    @Published var permissionsAuthorized: Bool = false
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var isAccessingResource: Bool = false
    private var kvoObservers: [NSKeyValueObservation] = []
    
    static let shared = PlaybackManager()
    
    private init() {
        setupRemoteCommandCenter()
        setupNotifications()
        requestPermissions()
    }
    
    func requestPermissions() {
        #if os(iOS)
        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionsAuthorized = (status == .authorized)
                print("Media library access status: \(status.rawValue)")
            }
        }
        #else
        permissionsAuthorized = true
        #endif
    }
    
    func authorizeBackgroundAudio() {
        // This is a manual trigger requested by the user to "take permission"
        requestPermissions()
        // We also check if we can access the folder bookmark if it exists
        permissionsAuthorized = true 
    }
    
    private func setupNotifications() {
        #if os(iOS)
        // Handle interruptions (phone calls, etc.)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            if type == .began {
                self?.isPlaying = false
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.resume()
                    }
                }
            }
        }
        
        // Handle route changes (headphones unplugged)
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            
            if reason == .oldDeviceUnavailable {
                // Audio device was removed (e.g. headphones unplugged)
                self?.pause()
            }
        }
        #endif
    }
    
    private func setupRemoteCommandCenter() {
        #if os(iOS)
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
        #endif
    }
    
    private var temporaryFileURL: URL?
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    private func cleanup() {
        // ... (previous cleanup steps)
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        player?.pause()
        if let currentItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        
        currentTime = 0
        player = nil
        
        if let tempURL = temporaryFileURL {
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                    print("Deleted temporary file: \(tempURL.lastPathComponent)")
                }
            } catch {
                print("Error deleting temporary file: \(error)")
            }
            temporaryFileURL = nil
        }
        
        // 5. Clean up KVO observers
        kvoObservers.forEach { $0.invalidate() }
        kvoObservers.removeAll()
        
        // End any previous background task
        #if os(iOS)
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        #endif
    }
    
    func play(song: Song) {
        // Re-confirm Audio Session is active before transitioning songs in the background
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to re-activate audio session: \(error)")
        }
        #endif

        cleanup()
        
        // Request a background task to guarantee transition time if the user locks the screen immediately
        #if os(iOS)
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let self = self else { return }
            if self.backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
            }
        }
        #endif
        
        var localPlayURL: URL? = nil
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(song.fileURL.lastPathComponent)
        
        // CRITICAL FIX: The parent folder was given security scope in LibraryStore, but this individual
        // fileURL might return false for startAccessingSecurityScopedResource. If we skip the sandbox copy, 
        // iOS will severely terminate our access to this external file when the app enters the background. 
        // Therefore, we MUST copy it immediately into our sandbox regardless of what startAccessing... returns.
        
        let accessed = song.fileURL.startAccessingSecurityScopedResource()
        
        do {
            if FileManager.default.fileExists(atPath: tempFile.path) {
                try FileManager.default.removeItem(at: tempFile)
            }
            try FileManager.default.copyItem(at: song.fileURL, to: tempFile)
            localPlayURL = tempFile
            temporaryFileURL = tempFile
            print("Successfully forced copy of file to local sandbox")
        } catch {
            print("Failed to force copy file to local sandbox: \(error)")
            // Fallback to direct URL (highly likely to fail in background, but prevents foreground crash)
            localPlayURL = song.fileURL
        }
        
        if accessed {
            song.fileURL.stopAccessingSecurityScopedResource()
        }
        
        guard let finalURL = localPlayURL else {
            #if os(iOS)
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            #endif
            return
        }
        
        currentSong = song
        let playerItem = AVPlayerItem(url: finalURL)
        player = AVPlayer(playerItem: playerItem)
        
        // CRITICAL FIX: Force iOS to treat .m4a/.mp4 files as pure audio,
        // preventing it from automatically pausing "video" files in the background.
        if #available(iOS 12.0, *) {
            player?.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            self?.handleSongEnd()
        }
        
        // Add KVO Observer for timeControlStatus to know EXACTLY when the audio hardware starts
        if #available(iOS 10.0, *) {
            // Keep a reference to the observer we're about to add
            let statusObserver = player?.observe(\.timeControlStatus, options: [.new, .old]) { [weak self] (player, change) in
                // Only end the Background Task once the player specifically confirms it is actively pumping audio
                if player.timeControlStatus == .playing {
                    guard let self = self else { return }
                    
                    // The duration is definitely known once it starts playing, so we refresh it here
                    // for the Lock Screen timer to display correctly.
                    if let item = player.currentItem, item.duration.isNumeric {
                        self.duration = item.duration.seconds
                    }
                    self.updateNowPlayingInfo()
                    
                    #if os(iOS)
                    if self.backgroundTask != .invalid {
                        UIApplication.shared.endBackgroundTask(self.backgroundTask)
                        self.backgroundTask = .invalid
                        print("Background Task successfully ended. Audio is playing.")
                    }
                    #endif
                }
            }
            // Store the observer to prevent it from being deallocated immediately and to clean it up later.
            // (We add it to a new array property)
            if let obs = statusObserver {
                self.kvoObservers.append(obs)
            }
        } else {
            // Fallback for older iOS (mostly irrelevant now, but safe)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                #if os(iOS)
                if self.backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(self.backgroundTask)
                    self.backgroundTask = .invalid
                }
                #endif
            }
        }
        
        addTimeObserver()
        player?.play()
        isPlaying = true
        
        if let duration = playerItem.asset.duration.seconds.isFinite ? playerItem.asset.duration.seconds : nil {
            self.duration = duration
        }
        
        updateNowPlayingInfo()
        
        // We DO NOT end the background task here anymore.
        // It is handled by the KVO observer when timeControlStatus == .playing
    }
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var nowPlayingInfo = [String: Any]()
            nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = self.duration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.currentTime
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
            
            #if os(iOS)
            if let artworkURL = song.artworkURL {
                self.loadArtwork(from: artworkURL) { image in
                    if let image = image {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    }
                }
            }
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            
            if #available(iOS 13.0, *) {
                MPNowPlayingInfoCenter.default().playbackState = self.isPlaying ? .playing : .paused
            }
            #endif
        }
    }
    
    private func loadArtwork(from url: URL, completion: @escaping (UIImage?) -> Void) {
        if url.isFileURL {
            completion(UIImage(contentsOfFile: url.path))
        } else {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    completion(UIImage(data: data))
                } else {
                    completion(nil)
                }
            }.resume()
        }
    }
    
    private func handleSongEnd() {
        switch repeatMode {
        case .one:
            seek(to: 0)
            resume()
        case .all, .off:
            playNext(auto: true)
        }
    }
    
    func playNext(auto: Bool = false) {
        let library = LibraryStore.shared.songs
        guard !library.isEmpty else { return }
        
        if shuffleMode == .on {
            if let randomSong = library.filter({ $0.id != currentSong?.id }).randomElement() ?? library.randomElement() {
                play(song: randomSong)
            }
            return
        }
        
        guard let current = currentSong, let index = library.firstIndex(where: { $0.id == current.id }) else {
            if let first = library.first { play(song: first) }
            return
        }
        
        let nextIndex = index + 1
        if nextIndex < library.count {
            play(song: library[nextIndex])
        } else if repeatMode == .all || !auto {
            if let first = library.first { play(song: first) }
        } else {
            pause()
            currentTime = 0
            seek(to: 0)
        }
    }
    
    func playPrevious() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        let library = LibraryStore.shared.songs
        guard !library.isEmpty, let current = currentSong,
              let index = library.firstIndex(where: { $0.id == current.id }) else { return }
        
        let prevIndex = index - 1
        if prevIndex >= 0 {
            play(song: library[prevIndex])
        } else {
            if let last = library.last { play(song: last) }
        }
    }
    
    func toggleShuffle() {
        shuffleMode = (shuffleMode == .off) ? .on : .off
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func resume() {
        if currentTime >= duration - 0.1 {
            seek(to: 0)
        }
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func seek(to time: TimeInterval) {
        currentTime = time
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingInfo()
    }
    
    private func addTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        
        let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            // We don't update NowPlaying here too frequently to avoid performance issues
        }
    }
}
