import SwiftUI
import AVFoundation

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // App-level Audio Session Initialization inside the true iOS Foundation Lifecycle
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true)
            print("Successfully configured AppDelegate AVAudioSession for rock-solid background playback")
        } catch {
            print("Failed to configure AppDelegate AVAudioSession: \(error)")
        }
        
        // Pre-warm PlaybackManager
        _ = PlaybackManager.shared
        
        return true
    }
}
#endif

@main
struct MusicAppSwift: App {
    // Bind to the traditional robust iOS background lifecycle
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
