//
//  SleepSchedulerApp.swift
//  SleepScheduler
//
//  Created by Emil Zlatinov on 29.03.25.
//

import SwiftUI

@main
struct SleepSchedulerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
