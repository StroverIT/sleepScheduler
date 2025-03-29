//
//  SleepSchedulerApp.swift
//  SleepScheduler
//
//  Created by Emil Zlatinov on 29.03.25.
//

import SwiftUI

@main
struct SleepSchedulerApp: App {
    init() {
        // Optional: Set icon programmatically
        NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
