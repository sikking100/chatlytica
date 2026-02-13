//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by grocee on 11/02/26.
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    let appGroupId = "group.com.mvp.chatlytica"
    let kSchemePrefix = "ShareMedia"
    var hostAppBundleIdentifier = ""
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleIncomingFile()
    }
    
    private func handleIncomingFile() {
            guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
                  let attachments = extensionItem.attachments else {
                completeRequest()
                return
            }
            
            let dispatchGroup = DispatchGroup()
            
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    dispatchGroup.enter()
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                        if let url = item as? URL {
                            self.saveFileToGroup(url: url)
                        }
                        
                        dispatchGroup.leave()
                    }
                }
                break
            }
            
            dispatchGroup.notify(queue: .main) {
                self.showBackToAppAlert()
            }
        }
        
        private func showBackToAppAlert() {
            let alert = UIAlertController(title: "Success", message: "Back to Chatlytica", preferredStyle: .alert)
            
            let okAction = UIAlertAction(title: "Ok", style: .default) { _ in
                self.openApp()
                self.completeRequest()
            }
            let closeAction = UIAlertAction(title: "Close", style: .cancel) { _ in
                self.completeRequest()
            }
            
            alert.addAction(okAction)
            alert.addAction(closeAction)
            present(alert, animated: true)
        }
        
        private func saveFileToGroup(url: URL) {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }
            
            let destinationURL = containerURL.appendingPathComponent(url.lastPathComponent)
            
            do {
                let existingFiles = try FileManager.default.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
                for file in existingFiles {
                    let ext = file.pathExtension.lowercased()

                    // Hanya proses zip atau txt
                    guard ext == "zip" || ext == "txt" else {
                        continue
                    }

                    // Pastikan benar-benar file (bukan folder)
                    let resourceValues = try file.resourceValues(forKeys: [.isRegularFileKey])
                    if resourceValues.isRegularFile == true {
                        try? FileManager.default.removeItem(at: file)
                    }
                    try FileManager.default.removeItem(at: file)
                }
                
    //            if FileManager.default.fileExists(atPath: destinationURL.path) {
    //                try FileManager.default.removeItem(at: destinationURL)
    //            }

                try FileManager.default.copyItem(at: url, to: destinationURL)

            } catch {
                print("Error copying file: \(error)")
            }
        }
        
        private func completeRequest() {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        
        private func openApp() {
            loadIds()
            let url = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share")
            var responder = self as UIResponder?
            
            if #available(iOS 18.0, *) {
                while responder != nil {
                    if let application = responder as? UIApplication {
                        application.open(url!, options: [:], completionHandler: nil)
                    }
                    responder = responder?.next
                }
            } else {
                let selectorOpenURL = sel_registerName("openURL:")
                
                while (responder != nil) {
                    if (responder?.responds(to: selectorOpenURL))! {
                        _ = responder?.perform(selectorOpenURL, with: url)
                    }
                    responder = responder!.next
                }
            }
        }
        
        private func loadIds() {
            // loading Share extension App Id
            let shareExtensionAppBundleIdentifier = Bundle.main.bundleIdentifier!
            
            
            // extract host app bundle id from ShareExtension id
            // by default it's <hostAppBundleIdentifier>.<ShareExtension>
            // for example: "com.kasem.sharing.Share-Extension" -> com.kasem.sharing
            let lastIndexOfPoint = shareExtensionAppBundleIdentifier.lastIndex(of: ".")
            hostAppBundleIdentifier = String(shareExtensionAppBundleIdentifier[..<lastIndexOfPoint!])
        }
}
