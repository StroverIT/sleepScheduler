import SwiftUI
import UserNotifications

class NotificationManager: ObservableObject {
    @Published var alertMessage = ""
    @Published var showAlert = false
    
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
    
    func sendNotification(title: String, body: String, delay: TimeInterval = 1) {
        checkNotificationAuthorization { granted in
            guard granted else { return }
            
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Error sending notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func scheduleNotification(at date: Date, title: String, body: String) {
        checkNotificationAuthorization { granted in
            guard granted else { return }
            
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default
            
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.alertMessage = "Notification error: \(error.localizedDescription)"
                        self.showAlert = true
                    }
                }
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
} 