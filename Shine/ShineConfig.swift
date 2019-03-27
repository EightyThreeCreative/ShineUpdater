//
//  ShineConfig.swift
//  Shine
//
//  Created by Lucas Romano Marquez Rizzi on 04/05/2018.
//  Copyright © 2018 Eighty Three Creative, Inc. All rights reserved.
//

import Foundation

@objcMembers public class ShineConfig: NSObject {
    
    public var automaticallyChecksForUpdates = true
    public var updateCheckInterval: TimeInterval = 3600 // 1 hour
    public var remindLaterInterval: TimeInterval = 3600 * 24 // 1 day
	public var updateDialogDelay: TimeInterval = 0.0 // No delay
    public var feedURL = URL(string: "http://notset.com")!
    public var showReleaseNotes = true
	public var customDisplayName: String?
    
    public func validate() {
        assert(feedURL.absoluteString != "http://notset.com", "Shine: Must set feedURL in config")
        assert(feedURL.scheme?.lowercased() == "https" || feedURL.absoluteString.contains("localhost"), "Shine: feedURL must be an HTTPS URL")
    }
}
