//
//  Shine.swift
//  Shine
//
//  Created by Cory Imdieke on 4/6/18.
//  Copyright © 2018 Eighty Three Creative, Inc. All rights reserved.
//

import UIKit
import SWXMLHash

// MARK: - User Default Accessors
fileprivate extension Shine {
	private struct UserDefaultKeys {
		static let LastCheckVersion = "Shine:LastCheckVersion"
		static let LastCheckDate = "Shine:LastCheckDate"
		static let LastCheckWasForcedUpdate = "Shine:LastCheckForcedUpdate"
		static let UserRemindLaterDate = "Shine:UserRemindLaterDate"
		static let CompletedFirstCheck = "Shine:CompletedFirstCheck"
	}
	
	fileprivate var lastCheckLatestVersion: String? {
		get {
			return UserDefaults.standard.string(forKey: UserDefaultKeys.LastCheckVersion)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: UserDefaultKeys.LastCheckVersion)
			UserDefaults.standard.synchronize()
		}
	}
	fileprivate var lastCheckDate: Date {
		get {
			return UserDefaults.standard.object(forKey: UserDefaultKeys.LastCheckDate) as? Date ?? Date.distantPast
		}
		set {
			UserDefaults.standard.set(newValue, forKey: UserDefaultKeys.LastCheckDate)
			UserDefaults.standard.synchronize()
		}
	}
	fileprivate var selectedRemindLaterDate: Date? {
		get {
			return UserDefaults.standard.object(forKey: UserDefaultKeys.UserRemindLaterDate) as? Date
		}
		set {
			UserDefaults.standard.set(newValue, forKey: UserDefaultKeys.UserRemindLaterDate)
			UserDefaults.standard.synchronize()
		}
	}
	fileprivate var lastCheckWasForcedUpdate: Bool {
		get {
			return UserDefaults.standard.bool(forKey: UserDefaultKeys.LastCheckWasForcedUpdate)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: UserDefaultKeys.LastCheckWasForcedUpdate)
			UserDefaults.standard.synchronize()
		}
	}
	fileprivate var completedFirstCheck: Bool {
		get {
			return UserDefaults.standard.bool(forKey: UserDefaultKeys.CompletedFirstCheck)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: UserDefaultKeys.CompletedFirstCheck)
			UserDefaults.standard.synchronize()
		}
	}
}

@objcMembers public class Shine: NSObject {
	
	// MARK: Singleton
	public static let shared = Shine()
	
	// MARK: Public vars
	public var config = ShineConfig()
	
	// MARK: Private vars
	private let xml = SWXMLHash.config { config in
		config.shouldProcessLazily = true
		config.shouldProcessNamespaces = true
	}
	private let backgroundQueue = DispatchQueue.init(label: "com.eightythreecreative.shine.backgroundqueue")
	
	/// Master setup method, must be called with a config block to get everything running
	///
	/// - Parameter configClosure: Set config values in this block
	public func setup(_ configClosure: (ShineConfig) -> Void) {
		let defaultConfig = ShineConfig()
		configClosure(defaultConfig)
		defaultConfig.validate()
		self.config = defaultConfig
		
		NotificationCenter.default.addObserver(self, selector: #selector(Shine.appDidResume), name: .UIApplicationDidBecomeActive, object: nil)
	}
	
	
	/// Trigger a manual update check by downloading the appcast.xml file and checking versions
	///
	/// - Parameter forceNotify: Set this to true if the user is doing something that calls this method. Will show the update dialog even in cases that it normally wouldn't be shown, like if the check interval hasn't passed yet or if the user ignored this update. It will also show a "no update available" dialog if there is no update to let the user know the check succeeded.
	public func checkForUpdates(forceNotify: Bool = false) {
		self.config.validate()
		
		self.backgroundQueue.async {
			do {
				let feedXML = try String.init(contentsOf: self.config.feedURL)
				
				let parsedXML = self.xml.parse(feedXML)
				let items: [AppCastItem] = try parsedXML["rss"]["channel"]["item"].value()
				
				// Run through the list of updates and find if there is one that is newer than our current version, and can be installed on our system OS
				guard let currentVersionCode = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
					assertionFailure("Shine: CFBundleVersion must be set")
					return
				}
				let systemVersion = UIDevice.current.systemVersion
				
				var newItem: AppCastItem? = nil
				for potentialNewItem in items {
					var tempItem: AppCastItem? = nil
					if potentialNewItem.versionCode.isNewerThanVersion(currentVersionCode) {
						if potentialNewItem.requiredSystemVersion != nil {
							// Has required system version
							if systemVersion.isNewerThanVersion(potentialNewItem.requiredSystemVersion!) {
								// New enough
								tempItem = potentialNewItem
							}
						} else {
							// No required system version, newer than current
							tempItem = potentialNewItem
						}
					}
					
					if tempItem != nil {
						// Final check to make sure it's newer than the item we already have
						if tempItem!.versionCode.isNewerThanVersion(newItem?.versionCode ?? "-1") {
							newItem = tempItem
						}
					}
				}
				
				if newItem != nil {
					// We have an update available
					print("Shine: Found update from version \(currentVersionCode) to version \(newItem!.versionCode)")
					DispatchQueue.main.sync {
						self.notifyUserOfUpdate(toVersion: newItem!, force: forceNotify || newItem!.forcedUpdate)
					}
				} else {
					// No update available
					print("Shine: No update found, \(currentVersionCode) is the latest version")
					if forceNotify {
						DispatchQueue.main.sync {
							let infoDictionary = Bundle.main.infoDictionary!
							let displayVersion = infoDictionary["CFBundleShortVersionString"] as? String
							let bundleDisplayname = self.config.customDisplayName ?? infoDictionary["CFBundleDisplayName"] as? String
							let noUpdateAlert = UIAlertController(title: "You’re up-to-date!", message: "\(bundleDisplayname ?? "Version") \(displayVersion ?? currentVersionCode) is currently the newest version available.", preferredStyle: .alert)
							noUpdateAlert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
							
							if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
								noUpdateAlert.present(from: rootVC, animated: true, completion: nil)
							}
						}
					}
				}
				
				// Update completed and user notified, mark this time and version for the next time
				self.lastCheckDate = Date()
				self.lastCheckLatestVersion = newItem?.versionCode ?? currentVersionCode
				self.lastCheckWasForcedUpdate = newItem?.forcedUpdate ?? false
				
			} catch let error {
				print("Shine: Error downloading Feed: \(error)")
				return
			}
		}
	}
	
	// MARK: Internal notification methods
	
	@objc private func appDidResume() {
		DispatchQueue.main.asyncAfter(wallDeadline: .now() + self.config.updateDialogDelay) {
			let timeSinceLastCheck = abs(self.lastCheckDate.timeIntervalSinceNow)
			let beenLongEnoughToCheckAgain = timeSinceLastCheck > self.config.updateCheckInterval
			
			if self.lastCheckWasForcedUpdate || self.completedFirstCheck && self.config.automaticallyChecksForUpdates && beenLongEnoughToCheckAgain {
				self.checkForUpdates()
			} else if !beenLongEnoughToCheckAgain {
				print("Shine: Too soon to check for update: (\(Int(timeSinceLastCheck)) seconds passed, \(self.config.updateCheckInterval) seconds between checks")
			}
			
			self.completedFirstCheck = true
		}
	}
	
	// MARK: Internal methods
	
	private func notifyUserOfUpdate(toVersion: AppCastItem, force: Bool) {
		// Check to see if we should notify for this version
		guard force || self.lastCheckLatestVersion != toVersion.versionCode || abs((self.selectedRemindLaterDate ?? Date.distantPast).timeIntervalSinceNow) > self.config.remindLaterInterval else {
			print("Shine: Not notifying user of new update")
			return
		}
		
		let infoDictionary = Bundle.main.infoDictionary!
		guard let currentVersionCode = infoDictionary["CFBundleVersion"] as? String else {
			assertionFailure("Shine: CFBundleVersion must be set")
			return
		}
		let displayVersion = infoDictionary["CFBundleShortVersionString"] as? String
		let bundleDisplayname = self.config.customDisplayName ?? infoDictionary["CFBundleDisplayName"] as? String
		
		var releaseNotes = ""
		if let content = toVersion.releaseNotes, self.config.showReleaseNotes {
			releaseNotes = "\n\nRelease Notes:\n\n\(content)"
		}
		
		let updateStatement = (toVersion.forcedUpdate) ? "This is a required update." : "Would you like to update now?"
		
		let updateAlert = UIAlertController(title: "A new version of \(bundleDisplayname ?? "this app") is available!", message: "\(bundleDisplayname ?? "") \(toVersion.displayVersion ?? toVersion.versionCode) is now available—you have \(displayVersion ?? currentVersionCode). \(updateStatement)\(releaseNotes)", preferredStyle: .alert)
		updateAlert.messageLabel?.textAlignment = .left
		
		if !toVersion.forcedUpdate {
			updateAlert.addAction(UIAlertAction(title: "Remind me Later", style: .cancel) { _ in
				self.selectedRemindLaterDate = Date()
			})
		}
		
		updateAlert.addAction(UIAlertAction(title: "Install Update", style: .default) { _ in
			self.beginUpdateProcess(toVersion: toVersion)
		})
		
		if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
			updateAlert.present(from: rootVC, animated: true, completion: nil)
		}
	}
	
	private func beginUpdateProcess(toVersion: AppCastItem) {
		let downloadTriggerURL: URL
		let givenURL = toVersion.appURL
		if givenURL.scheme == "itms-services" {
			downloadTriggerURL = givenURL
		} else {
			downloadTriggerURL = URL(string: "itms-services://?action=download-manifest&url=\(givenURL.absoluteString)")!
		}
		
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(downloadTriggerURL, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(downloadTriggerURL)
        }
	}
}

// MARK: - App Cast Data Model

fileprivate struct AppCastItem: XMLIndexerDeserializable {
	let title: String?
	let releaseNotes: String?
	let pubDate: Date
	let versionCode: String
	let displayVersion: String?
	let appURL: URL
	let requiredSystemVersion: String?
	let forcedUpdate: Bool

	static func deserialize(_ element: XMLIndexer) throws -> AppCastItem {
		guard let appURL = URL(string: try element["enclosure"].value(ofAttribute: "url")) else {
			throw IndexingError.attribute(attr: "enclosure:url")
		}
		
		return try AppCastItem(title: element["title"].value(),
						   releaseNotes: element["description"].value(),
						   pubDate: element["pubDate"].value(),
						   versionCode: element["enclosure"].value(ofAttribute: "sparkle:version"),
						   displayVersion: element["enclosure"].value(ofAttribute: "sparkle:shortVersionString"),
						   appURL: appURL,
						   requiredSystemVersion: element["minimumSystemVersion"].value(),
						   forcedUpdate: element["forcedUpdate"].element != nil)
	}
}

extension Date: XMLElementDeserializable, XMLAttributeDeserializable {
	public static func deserialize(_ element: XMLElement) throws -> Date {
		let date = stringToDate(element.text)
		
		guard let validDate = date else {
			throw XMLDeserializationError.typeConversionFailed(type: "Date", element: element)
		}
		
		return validDate
	}
	
	public static func deserialize(_ attribute: XMLAttribute) throws -> Date {
		let date = stringToDate(attribute.text)
		
		guard let validDate = date else {
			throw XMLDeserializationError.attributeDeserializationFailed(type: "Date", attribute: attribute)
		}
		
		return validDate
	}
	
	private static func stringToDate(_ dateAsString: String) -> Date? {
		let dateFormatter = DateFormatter()
		dateFormatter.locale = Locale(identifier: "en_US")
		dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZZ"
		return dateFormatter.date(from: dateAsString)
	}
}

// MARK: - Utilities

fileprivate extension String {
	func isNewerThanVersion(_ v: String) -> Bool {
		return self.compare(v, options: .numeric) == .orderedDescending
	}
}

fileprivate extension UIViewController {
	func present(from viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
		if let visibleVC = (viewController as? UINavigationController)?.visibleViewController {
			present(from: visibleVC, animated: animated, completion: completion)
		} else if let selectedVC = (viewController as? UITabBarController)?.selectedViewController {
			present(from: selectedVC, animated: animated, completion: completion)
		} else if let presentedViewController = viewController.presentedViewController {
			present(from: presentedViewController, animated: animated, completion: completion)
		} else {
			viewController.present(self, animated: animated, completion: completion)
		}
	}
}

/// This snippet is used to access the labels in the alert dialog so we can modify the appearance of them. It is likely fragile so we may need to screw with it later.
/// Adapted from an answer from https://stackoverflow.com/questions/25962559/uialertcontroller-text-alignment
fileprivate extension UIAlertController {
	private func labelViewArray(_ root: UIView) -> [UIView]? {
		var _subviews: [UIView]? = nil
		for v in root.subviews {
			if _subviews != nil {
				break
			}
			if v is UILabel {
				_subviews = root.subviews
				return _subviews
			} else {
				_subviews = labelViewArray(v)
			}
		}
		return _subviews
	}
	
	var titleLabel: UILabel? {
		return self.labelViewArray(self.view)?.first as? UILabel
	}
	
	var messageLabel: UILabel? {
		return self.labelViewArray(self.view)?[1] as? UILabel
	}
}
