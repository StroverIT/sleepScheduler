import SwiftUI
import UserNotifications


class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

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
            
            Button(action: {
                checkNotificationAuthorization { granted in
                    if granted {
                        scheduleSleep()
                        sendSleepNotification()
                    }
                }
            }) {
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
            
            // Debugging button
            Button("Test Notification") {
                sendTestNotification()
            }
            .padding()
        }
        .frame(width: 400, height: 350)
        .onAppear {
            checkNotificationSettings()
            printNotificationSettings()
            listPendingNotifications()
            requestNotificationPermission()
            checkExistingSchedule()
        }
       .alert(isPresented: $showAlert) {
        Alert(
            title: Text(alertMessage.lowercased().contains("fail") ? "Error" : "Success"),
            message: Text(alertMessage),
            dismissButton: .default(Text("OK"))
        )
    }
    }
    
    // MARK: - Notification Functions
    
    func checkNotificationAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    completion(true)
                case .denied:
                    self.alertMessage = "Notifications are disabled in System Preferences > Notifications"
                    self.showAlert = true
                    completion(false)
                case .notDetermined:
                    self.requestNotificationPermission(completion: completion)
                case .ephemeral:
                    completion(true)
                @unknown default:
                    completion(false)
                }
            }
        }
    }
    
    func requestNotificationPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.alertMessage = "Notification permission error: \(error.localizedDescription)"
                    self.showAlert = true
                    completion?(false)
                    return
                }
                
                if !granted {
                    self.alertMessage = "Please enable notifications in System Preferences > Notifications"
                    self.showAlert = true
                }
                completion?(granted)
            }
        }
    }
    
    func printNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("\n=== Notification Settings ===")
            print("Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("Alert Setting: \(settings.alertSetting.rawValue)")
            print("Sound Setting: \(settings.soundSetting.rawValue)")
            print("Badge Setting: \(settings.badgeSetting.rawValue)\n")
        }
    }
    
    func listPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("\n=== Pending Notifications (\(requests.count)) ===")
            requests.forEach { request in
                print("\nID: \(request.identifier)")
                print("Title: \(request.content.title)")
                print("Body: \(request.content.body)")
                if let trigger = request.trigger {
                    print("Trigger: \(trigger)")
                }
            }
            print("===========================\n")
        }
    }

    func sendTestNotification() {
    checkNotificationAuthorization { granted in
        guard granted else {
            DispatchQueue.main.async {
                self.alertMessage = "Notifications not authorized. Check System Preferences > Notifications."
                self.showAlert = true
            }
            return
        }
        
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                guard settings.authorizationStatus == .authorized else {
                    self.alertMessage = "Notifications not authorized. Current status: \(settings.authorizationStatus.rawValue)"
                    self.showAlert = true
                    return
                }
                
                let content = UNMutableNotificationContent()
                content.title = "Test Notification"
                content.body = "This is a test notification to verify they're working"
                content.sound = UNNotificationSound.default
                
                // Corrected notification request with proper closing parenthesis
                let request = UNNotificationRequest(
                    identifier: "test-\(UUID().uuidString)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                ) // This closing parenthesis was missing
                
                center.add(request) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.alertMessage = "Failed to schedule test notification: \(error.localizedDescription)"
                        } else {
                            self.alertMessage = "Test notification was scheduled successfully. Check Notification Center if you don't see it."
                            print("Test notification scheduled successfully. Check console for settings:")
                            self.printNotificationSettings()
                        }
                        self.showAlert = true
                    }
                }
            }
        }
    }
}
                        

    func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("\n=== Current Notification Settings ===")
            print("Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("Alert Style: \(settings.alertSetting.rawValue)")
            print("Show Previews: \(settings.showPreviewsSetting.rawValue)")
            print("Sound Enabled: \(settings.soundSetting.rawValue)")
            print("Badge Enabled: \(settings.badgeSetting.rawValue)")
            print("Lock Screen Enabled: \(settings.lockScreenSetting.rawValue)")
            print("Notification Center Enabled: \(settings.notificationCenterSetting.rawValue)")
            print("Critical Alerts Enabled: \(settings.criticalAlertSetting.rawValue)")
            print("===================================\n")
        }
    }                      
                            
   func sendSleepNotification() {


    checkNotificationAuthorization { granted in
        guard granted else { return }
        
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Schedule Notification"
        
        if self.showTimePicker {
            content.body = "Schedule notification set for \(self.selectedTime.formatted(date: .omitted, time: .shortened))"
        } else {
            content.body = "Schedule notification set after \(self.hoursDelay)h \(self.minutesDelay)m"
        }
        
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: "sleep-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        ) // This closing parenthesis was missing
        
        center.add(request) { error in
            if let error = error {
                print("Error showing sleep notification: \(error.localizedDescription)")
            }
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
        var amount: String
        
        if showTimePicker {
            sleepTime = selectedTime
            if sleepTime < Date() {
                sleepTime = Calendar.current.date(byAdding: .day, value: 1, to: sleepTime) ?? sleepTime
            }
            notificationTime = Calendar.current.date(byAdding: .minute, value: -5, to: sleepTime) ?? sleepTime
            amount = "specific time: \(sleepTime.formatted(date: .omitted, time: .shortened))"
        } else {
            let totalSeconds = (hoursDelay * 3600) + (minutesDelay * 60)
            sleepTime = Date().addingTimeInterval(TimeInterval(totalSeconds))
            notificationTime = Date().addingTimeInterval(TimeInterval(totalSeconds - 300))
            amount = "\(hoursDelay)h \(minutesDelay)m"
        }
        
        do {
            currentPlistLabel = "com.user.sleep.\(UUID().uuidString)"
            let plistContent = createPlistContent(sleepTime: sleepTime, label: currentPlistLabel)
            try savePlistToLaunchAgents(plistContent: plistContent, label: currentPlistLabel)
            
            sendConfirmationNotification(sleepTime: sleepTime, amount: amount)
            scheduleNotification(at: notificationTime, sleepTime: sleepTime)
            
            isScheduled = true
        } catch {
            alertMessage = "Failed to schedule sleep: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func sendConfirmationNotification(sleepTime: Date, amount: String) {
        checkNotificationAuthorization { granted in
            guard granted else { return }
            
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = "Schedule Notification"
            
            if self.showTimePicker {
                content.body = "Schedule notification set for \(sleepTime.formatted(date: .omitted, time: .shortened))"
            } else {
                content.body = "Schedule notification set after \(self.hoursDelay)h \(self.minutesDelay)m"
            }
            
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: "confirmation-\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Error showing confirmation: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func scheduleNotification(at date: Date, sleepTime: Date) {
    checkNotificationAuthorization { granted in
        guard granted else { return }
        
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [self.notificationID])
        
        let content = UNMutableNotificationContent()
        content.title = "Schedule Notification"
        
        if self.showTimePicker {
            content.body = "Schedule notification set for \(sleepTime.formatted(date: .omitted, time: .shortened))"
        } else {
            content.body = "Schedule notification set after \(self.hoursDelay)h \(self.minutesDelay)m"
        }
        
        content.sound = UNNotificationSound.default
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: self.notificationID,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.alertMessage = "Notification error: \(error.localizedDescription)"
                    self.showAlert = true
                }
            } else {
                print("Successfully scheduled notification for \(date)")
                self.listPendingNotifications()
            }
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
        
        sendCancellationNotification()
    }
    
    func sendCancellationNotification() {
        checkNotificationAuthorization { granted in
            guard granted else { return }
            
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = "Schedule Cancelled"
            content.body = "Your scheduled sleep has been cancelled"
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: "cancellation-\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Error showing cancellation: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
