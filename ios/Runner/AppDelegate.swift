import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let EVENT_CHANNEL = "share_event_channel"
    private let appGroupId = "group.com.mvp.chatlytica"
    
    private var eventSink: FlutterEventSink?
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
            
        let eventChannel = FlutterEventChannel(
                    name: EVENT_CHANNEL,
                    binaryMessenger: controller.binaryMessenger
                )

      eventChannel.setStreamHandler(self)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        if let files = getSharedFiles() {
            eventSink?(files)
        }
    }
    
    
    private func getSharedFiles() -> String? {

            guard let containerURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
                return nil
            }

            let fileURLs = try? FileManager.default.contentsOfDirectory(
                at: containerURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        
            let validFile = fileURLs?.first { url in
                let ext = url.pathExtension.lowercased()

                if ext != "zip" && ext != "txt" {
                    return false
                }

                let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
                return resourceValues?.isRegularFile == true
            }

            // Return full path agar Flutter bisa baca langsung
            return validFile?.path
        }
        
        private func clearSharedFiles() -> Bool {

            guard let containerURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
                return false
            }

            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: containerURL,
                    includingPropertiesForKeys: nil
                )

                for url in fileURLs {
                    try FileManager.default.removeItem(at: url)
                }

                return true

            } catch {
                print("Error clearing shared files: \(error)")
                return false
            }
        }
}

extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
