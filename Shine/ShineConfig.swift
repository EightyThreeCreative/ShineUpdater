//
//  ShineConfig.swift
//  Shine
//
//  Created by Lucas Romano Marquez Rizzi on 04/05/2018.
//  Copyright © 2018 Eighty Three Creative, Inc. All rights reserved.
//

import Foundation

/// Stores configuration settings for Shine
@objcMembers public class ShineConfig: NSObject {
    
	/// Whether or not the app automatically checks for updates on launch. If this is changed to false, the app will only check for updates and notify when the checkForUpdates() func is called.
	///
	/// Default: true
    public var automaticallyChecksForUpdates = true
	
	/// Number of seconds between automatically checking for updates on launch.
	///
	/// Default: 3600 (one hour)
    public var updateCheckInterval: TimeInterval = 3600 // 1 hour
	
	/// Number of seconds to suppress update dialogs for when the user selects "Remind me Later".
	///
	/// Default: 3600 * 24 (one day)
    public var remindLaterInterval: TimeInterval = 3600 * 24 // 1 day
	
	/// Adds a delay to the presentation of the update dialog on launch. Useful if the app UI takes a moment to load or if there is a splash screen to avoid.
	///
	/// Default: 0 (no delay)
	public var updateDialogDelay: TimeInterval = 0.0 // No delay
	
	/// URL to connect to that contains the cast feed
    public var feedURL = URL(string: "http://notset.com")!
	
	/// Whether or not to show release notes from the App Cast in the update dialog.
	///
	/// Default: true
    public var showReleaseNotes = true
	
	/// Customize the app title used in the update dialog. This dialog uses the CFBundleDisplayName by default, but can be overridden if a shortened name is used for the Springboard.
	public var customDisplayName: String?
    
    public func validate() {
        assert(feedURL.absoluteString != "http://notset.com", "Shine: Must set feedURL in config")
        assert(feedURL.scheme?.lowercased() == "https" || feedURL.absoluteString.contains("localhost"), "Shine: feedURL must be an HTTPS URL")
    }
}
