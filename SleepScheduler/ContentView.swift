import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var selectedTime = Date()
    @State private var hoursDelay: Int = 1
    @State private var minutesDelay: Int = 0
    @State private var showTimePicker = true
    @State private var notificationID = UUID().uuidString
    @State private var isScheduled = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var currentPlistLabel = "com.user.sleep.\(UUID().uuidString)"
    
    private let hourOptions = Array(0...23)
    private let minuteOptions = [0, 15, 30, 45]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sleep Scheduler")
                .font(.largeTitle)
                .padding()
            
            Picker("Schedule Type", selection: $showTimePicker) {
                Text("Specific Time").tag(true)
                Text("After Duration").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if showTimePicker {
                DatePicker("Sleep at:", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .padding()
            } else {
                VStack(spacing: 15) {
                    Text("Sleep after:")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        Picker("Hours", selection: $hoursDelay) {
                            ForEach(hourOptions, id: \.self) { hour in
                                Text("\(hour) hour\(hour == 1 ? "" : "s")").tag(hour)
                            }
                        }
                        .frame(width: 150)
                        .labelsHidden()
                        
                        Picker("Minutes", selection: $minutesDelay) {
                            ForEach(minuteOptions, id: \.self) { minute in
                                Text("\(minute) min").tag(minute)
                            }
                        }
                        .frame(width: 150)
                        .labelsHidden()
                    }
                    
                    Text("Total: \(hoursDelay)h \(minutesDelay)m")
                        .font(.subheadline)
                }
                .padding()
            }
            
            Button(action: scheduleSleep) {
                Text(isScheduled ? "Sleep Scheduled" : "Schedule Sleep")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isScheduled ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isScheduled)
            .padding()
            
            if isScheduled {
                Button("Cancel Schedule") {
                    cancelSchedule()
                }
                .padding()
            }
        }
        .frame(width: 400, height: 300)
        .onAppear {
            requestNotificationPermission()
            checkExistingSchedule()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                alertMessage = "Notification permission error: \(error.localizedDescription)"
                showAlert = true
            }
        }
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
    
    func scheduleSleep() {
        var sleepTime: Date
        let notificationTime: Date
        
        if showTimePicker {
            sleepTime = selectedTime
            if sleepTime < Date() {
                sleepTime = Calendar.current.date(byAdding: .day, value: 1, to: sleepTime) ?? sleepTime
            }
            notificationTime = Calendar.current.date(byAdding: .minute, value: -5, to: sleepTime) ?? sleepTime
        } else {
            let totalSeconds = (hoursDelay * 3600) + (minutesDelay * 60)
            sleepTime = Date().addingTimeInterval(TimeInterval(totalSeconds))
            notificationTime = Date().addingTimeInterval(TimeInterval(totalSeconds - 300))
        }
        
        do {
            currentPlistLabel = "com.user.sleep.\(UUID().uuidString)"
            let plistContent = createPlistContent(sleepTime: sleepTime, label: currentPlistLabel)
            try savePlistToLaunchAgents(plistContent: plistContent, label: currentPlistLabel)
            
            // Send immediate confirmation notification
            sendConfirmationNotification(sleepTime: sleepTime)
            
            // Schedule reminder notification
            scheduleNotification(at: notificationTime, sleepTime: sleepTime)
            
            isScheduled = true
        } catch {
            alertMessage = "Failed to schedule sleep: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func sendConfirmationNotification(sleepTime: Date) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Sleep Scheduled"
        content.body = "Your Mac is scheduled to sleep at \(sleepTime.formatted(date: .omitted, time: .shortened))"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "confirmation-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error showing confirmation: \(error.localizedDescription)")
            }
        }
    }
    
    func createPlistContent(sleepTime: Date, label: String) -> String {
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
    
    func savePlistToLaunchAgents(plistContent: String, label: String) throws {
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
    
    func scheduleNotification(at date: Date, sleepTime: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        
        let content = UNMutableNotificationContent()
        content.title = "Sleep Schedule Reminder"
        content.body = "Your Mac will go to sleep at \(sleepTime.formatted(date: .omitted, time: .shortened))"
        content.sound = UNNotificationSound.default
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage = "Notification error: \(error.localizedDescription)"
                    showAlert = true
                }
            }
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
        
        // Send cancellation notification
        sendCancellationNotification()
    }
    
    func sendCancellationNotification() {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Sleep Schedule Cancelled"
        content.body = "Your scheduled sleep has been cancelled"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "cancellation-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error showing cancellation: \(error.localizedDescription)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
