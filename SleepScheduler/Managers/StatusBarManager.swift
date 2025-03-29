import SwiftUI
import AppKit

class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    @Published var timeRemaining: TimeInterval = 0
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarTitle()
    }
    
    func startCountdown(totalSeconds: TimeInterval) {
        timeRemaining = totalSeconds
        print("Starting countdown with \(totalSeconds) seconds")
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
                self.updateMenuBarTitle()
            } else {
                self.timer?.invalidate()
                self.updateMenuBarTitle()
            }
        }
    }
    
    func stopCountdown() {
        timer?.invalidate()
        timeRemaining = 0
        updateMenuBarTitle()
    }
    
    private func updateMenuBarTitle() {
        guard let button = statusItem?.button else { return }
        
        if timeRemaining > 0 {
            let hours = Int(timeRemaining) / 3600
            let minutes = (Int(timeRemaining) % 3600) / 60
            
            let timeString = String(format: "%02d:%02d", hours, minutes)
            button.title = "⏰ \(timeString)"
        }
    }
} 