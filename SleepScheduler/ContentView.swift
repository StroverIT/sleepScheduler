import SwiftUI
import UserNotifications
import AppKit

struct ContentView: View {
    @StateObject private var statusBarManager = StatusBarManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var sleepSchedulerManager = SleepSchedulerManager()
    
    @State private var selectedTime = Date()
    @State private var hoursDelay: Int = 1
    @State private var minutesDelay: Int = 0
    @State private var showTimePicker = true
    
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
                notificationManager.checkNotificationAuthorization { granted in
                    if granted {
                        scheduleSleep()
                    }
                }
            }) {
                Text(sleepSchedulerManager.isScheduled ? "Sleep Scheduled" : "Schedule Sleep")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(sleepSchedulerManager.isScheduled ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(sleepSchedulerManager.isScheduled)
            .padding()
            
            if sleepSchedulerManager.isScheduled {
                Button("Cancel Schedule") {
                    cancelSchedule()
                }
                .padding()
            }
            
            Button("Test Notification") {
                notificationManager.sendNotification(
                    title: "Test Notification",
                    body: "This is a test notification to verify they're working"
                )
            }
            .padding()
        }
        .frame(width: 400, height: 350)
        .onAppear {
            notificationManager.printNotificationSettings()
            notificationManager.listPendingNotifications()
            notificationManager.requestNotificationPermission()
            sleepSchedulerManager.checkExistingSchedule()
            statusBarManager.setup()
        }
        .alert(isPresented: $notificationManager.showAlert) {
            Alert(
                title: Text(notificationManager.alertMessage.lowercased().contains("fail") ? "Error" : "Success"),
                message: Text(notificationManager.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func scheduleSleep() {
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
        
        sleepSchedulerManager.scheduleSleep(
            at: sleepTime,
            notificationTime: notificationTime,
            hoursDelay: hoursDelay,
            minutesDelay: minutesDelay,
            showTimePicker: showTimePicker
        )
        
        notificationManager.scheduleNotification(
            at: notificationTime,
            title: "Sleep Schedule",
            body: showTimePicker ?
                "Your computer will sleep at \(sleepTime.formatted(date: .omitted, time: .shortened))" :
                "Your computer will sleep in \(hoursDelay)h \(minutesDelay)m"
        )
        
        if !showTimePicker {
            let totalSeconds = (hoursDelay * 3600) + (minutesDelay * 60)
            statusBarManager.startCountdown(totalSeconds: TimeInterval(totalSeconds))
        }
    }
    
    private func cancelSchedule() {
        statusBarManager.stopCountdown()
        sleepSchedulerManager.cancelSchedule()
        notificationManager.sendNotification(
            title: "Schedule Cancelled",
            body: "Your scheduled sleep has been cancelled"
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
