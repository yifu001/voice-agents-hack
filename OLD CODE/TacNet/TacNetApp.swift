import SwiftUI
import UIKit

// AppDelegate is required to handle the background URLSession callback that iOS
// delivers when the model download completes while the app is not in the foreground.
// Without this, iOS cannot inform the app that the download finished, and the system
// cannot update its background-app snapshot.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        switch identifier {
        case URLSessionDownloadClient.backgroundSessionIdentifier:
            URLSessionDownloadClient.shared.handleBackgroundSessionEvents(completionHandler: completionHandler)
        case URLSessionDownloadClient.parakeetSessionIdentifier:
            URLSessionDownloadClient.parakeet.handleBackgroundSessionEvents(completionHandler: completionHandler)
        default:
            completionHandler()
        }
    }
}

@main
struct TacNetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
