import Foundation
import AppKit

class SleepSchedulerManager: ObservableObject {
    @Published var currentPlistLabel = "com.user.sleep.\(UUID().uuidString)"
    @Published var isScheduled = false
    
    func scheduleSleep(at sleepTime: Date, notificationTime: Date, hoursDelay: Int, minutesDelay: Int, showTimePicker: Bool) {
        do {
            currentPlistLabel = "com.user.sleep.\(UUID().uuidString)"
            let plistContent = createPlistContent(sleepTime: sleepTime, label: currentPlistLabel)
            try savePlistToLaunchAgents(plistContent: plistContent, label: currentPlistLabel)
            
            isScheduled = true
        } catch {
            print("Failed to schedule sleep: \(error.localizedDescription)")
        }
    }
    
    func cancelSchedule() {
        guard !currentPlistLabel.isEmpty else { return }
        
        let launchAgentsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
        let plistURL = launchAgentsURL.appendingPathComponent("\(currentPlistLabel).plist")
        
        let unloadProcess = Process()
        unloadProcess.launchPath = "/bin/launchctl"
        unloadProcess.arguments = ["unload", plistURL.path]
        try? unloadProcess.run()
        unloadProcess.waitUntilExit()
        
        try? FileManager.default.removeItem(at: plistURL)
        
        currentPlistLabel = "com.user.sleep.\(UUID().uuidString)"
        isScheduled = false
    }
    
    func checkExistingSchedule() {
        let launchAgentsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: launchAgentsURL, includingPropertiesForKeys: nil)
            for file in files where file.lastPathComponent.hasPrefix("com.user.sleep") {
                currentPlistLabel = file.lastPathComponent.replacingOccurrences(of: ".plist", with: "")
                isScheduled = true
                break
            }
        } catch {
            print("No existing schedule found: \(error.localizedDescription)")
        }
    }
    
    private func createPlistContent(sleepTime: Date, label: String) -> String {
        let calendar = Calendar.current
        let h = calendar.component(.hour, from: sleepTime)
        let m = calendar.component(.minute, from: sleepTime)
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/osascript</string>
                <string>-e</string>
                <string>tell application "System Events" to sleep</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Hour</key>
                <integer>\(h)</integer>
                <key>Minute</key>
                <integer>\(m)</integer>
            </dict>
            <key>StandardOutPath</key>
            <string>/tmp/\(label).log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/\(label).err</string>
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """
    }
    
    private func savePlistToLaunchAgents(plistContent: String, label: String) throws {
        let launchAgentsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
        let plistURL = launchAgentsURL.appendingPathComponent("\(label).plist")
        
        if !FileManager.default.fileExists(atPath: launchAgentsURL.path) {
            try FileManager.default.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true)
        }
        
        try plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: plistURL.path)
        
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["load", plistURL.path]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "SleepScheduler", code: 1, userInfo: [NSLocalizedDescriptionKey: "launchctl load failed"])
        }
    }
} 