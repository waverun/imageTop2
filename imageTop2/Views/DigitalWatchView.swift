//import SwiftUI
//
//struct DigitalWatchView: View {
//    let backgroundColor = Color.black.opacity(0.6)
//    let timeFont = Font.system(size: 80, weight: .bold, design: .rounded)
//    let cpuUsage = getCpuUsage()
//
//    @State  var watchPosition = CGPoint(x: 0, y: 0)
//    @State  var timeString = ""
//
//    let x: CGFloat?
//    let y: CGFloat?
//
//    @ViewBuilder var body: some View {
//        Text(timeString)
//            .font(timeFont)
//            .foregroundColor(.white)
//            .frame(width: 250, height: 100)
//            .background(backgroundColor)
//            .cornerRadius(10)
//            .position(watchPosition)
//            .onAppear {
//                updateTime()
//                iPrint("watchPosition: \(x!), \(y!)")
//                watchPosition = CGPoint(x: x ?? 100, y: y ?? 100)
//            }
//            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
//                updateTime()
//            }
//    }
//
//     func updateTime() {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm"
//        timeString = formatter.string(from: Date())
//        print("CPU Usage: \(cpuUsage)%")
//        timeString = cpuUsage
//    }
//}

import SwiftUI

struct DigitalWatchView: View {
    @EnvironmentObject var appDelegate: AppDelegate

    let backgroundColor = Color.black.opacity(0.6)
    let timeFont = Font.system(size: 80, weight: .bold, design: .rounded)
//    let monitor = CPUUsageMonitor()

    @Binding var timerIsActive: Bool  // External condition binding

    @State private var watchPosition = CGPoint(x: 0, y: 0)
    @State private var timeString = ""
    @State private var currentCpuLoad: Double? = nil
    @State private var timer: Timer? = nil
    @State private var weatherTemperatureText = "--"
    @State private var weatherLastFetchDate: Date? = nil
    @State private var weatherFetchInProgress = false
    @State private var sunEventDisplayText = "--"
    @State private var sunEventLastFetchDate: Date? = nil
    @State private var sunEventFetchInProgress = false
    @State private var sunNextEventDate: Date? = nil
    @State private var sunNextEventLabel: String = ""

    let x: CGFloat?
    let y: CGFloat?

    @ViewBuilder var body: some View {
        Text(timeString)
            .font(appDelegate.showSunEventByIP ? .system(size: 32, weight: .bold, design: .rounded) : timeFont)
            .foregroundColor(.white)
            .frame(width: watchWidth, height: 100)
            .background(backgroundColor)
            .cornerRadius(10)
            .position(watchPosition)
            .onAppear {
                updateTime()
                handleTimerChange(isActive: timerIsActive)
                iPrint("watchPosition: \(x ?? 100), \(y ?? 100)")
                watchPosition = CGPoint(x: x ?? 100, y: y ?? 100)
            }
            .onChange(of: timerIsActive) { newValue in
                handleTimerChange(isActive: newValue)
            }
            .blur(radius: appDelegate.isVideoBlurred ? 20 : 0)
    }

    var watchWidth: CGFloat {
        if appDelegate.showWeatherByIP {
            return 300
        }
        if appDelegate.showSunEventByIP {
            return 305
        }
        if appDelegate.showCpu {
            return (currentCpuLoad ?? 0) < 100 ? 330 : 360
        }
        return 250
    }

    func handleTimerChange(isActive: Bool) {
        if isActive {
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    updateTime()
                }
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        switch true {
            case appDelegate.showWatchOrCpu:
                currentCpuLoad = nil
                timeString = formatter.string(from: Date())
            case appDelegate.showCpu: 
//                timeString = getCpuUsage() ?? ""
//                // Note: getCpuUsage() and iPrint() weren't defined in the provided code, so they are commented out
//                print("CPU Usage: \(String(describing: getCpuUsage()))%")
//                if let usage = monitor.update() {
//                    print(String(format: "CPU Usage monitor: %.2f%%", usage))
//                }
//                let loadInfo = hostCPULoadInfo()
//                print("CPU Usage loadInfo: \(String(describing: loadInfo))")
                let cpuLoad = calculateCPULoad()
                if let cpuLoad = cpuLoad {
                    currentCpuLoad = cpuLoad
                    print("CPU Load: \(cpuLoad)%")
                    timeString = String(format: "%.2f%%", cpuLoad)
                }
            case appDelegate.showWeatherByIP:
                currentCpuLoad = nil
                timeString = weatherTemperatureText
                refreshWeatherIfNeeded()
            case appDelegate.showSunEventByIP:
                currentCpuLoad = nil
                updateSunEventCountdown()
                refreshSunEventIfNeeded()
            default: break
        }
    }

    private func formatDuration(from now: Date, to eventDate: Date) -> String {
        let totalSeconds = max(Int(eventDate.timeIntervalSince(now)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func updateSunEventCountdown() {
        guard let sunNextEventDate,
              !sunNextEventLabel.isEmpty else {
            timeString = sunEventDisplayText
            return
        }
        let durationText = formatDuration(from: Date(), to: sunNextEventDate)
        timeString = "\(sunNextEventLabel) in \(durationText)"
    }

    private func refreshSunEventIfNeeded(force: Bool = false) {
        if sunEventFetchInProgress {
            return
        }
        if !force,
           let sunEventLastFetchDate,
           Date().timeIntervalSince(sunEventLastFetchDate) < 3600 {
            return
        }

        sunEventFetchInProgress = true
        fetchSunEventFromIP { result in
            DispatchQueue.main.async {
                defer { sunEventFetchInProgress = false }
                switch result {
                    case .success(let nextEvent):
                        sunNextEventLabel = nextEvent.label
                        sunNextEventDate = nextEvent.date
                        let durationText = formatDuration(from: Date(), to: nextEvent.date)
                        sunEventDisplayText = "\(nextEvent.label) in \(durationText)"
                        sunEventLastFetchDate = Date()
                        if appDelegate.showSunEventByIP {
                            timeString = sunEventDisplayText
                        }
                    case .failure:
                        sunEventDisplayText = "N/A"
                        sunNextEventLabel = ""
                        sunNextEventDate = nil
                        sunEventLastFetchDate = Date()
                        if appDelegate.showSunEventByIP {
                            timeString = sunEventDisplayText
                        }
                }
            }
        }
    }

    private func refreshWeatherIfNeeded(force: Bool = false) {
        if weatherFetchInProgress {
            return
        }
        if !force,
           let weatherLastFetchDate,
           Date().timeIntervalSince(weatherLastFetchDate) < 600 {
            return
        }

        weatherFetchInProgress = true
        fetchWeatherFromIP { result in
            DispatchQueue.main.async {
                defer { weatherFetchInProgress = false }
                switch result {
                    case .success(let temperature):
                        weatherTemperatureText = String(format: "%.1f°C", temperature)
                        weatherLastFetchDate = Date()
                        if appDelegate.showWeatherByIP {
                            timeString = weatherTemperatureText
                        }
                    case .failure:
                        weatherTemperatureText = "N/A"
                        weatherLastFetchDate = Date()
                        if appDelegate.showWeatherByIP {
                            timeString = weatherTemperatureText
                        }
                }
            }
        }
    }

    private func fetchWeatherFromIP(completion: @escaping (Result<Double, Error>) -> Void) {
        struct GeoLookupError: LocalizedError {
            let message: String
            var errorDescription: String? { message }
        }

        func parseDouble(_ value: Any?) -> Double? {
            if let number = value as? NSNumber {
                return number.doubleValue
            }
            if let string = value as? String {
                return Double(string)
            }
            return nil
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        let session = URLSession(configuration: configuration)

        guard let geoURL = URL(string: "https://ipapi.co/json/") else {
            completion(.failure(GeoLookupError(message: "Invalid IP geo URL")))
            return
        }

        session.dataTask(with: geoURL) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(GeoLookupError(message: "Missing IP geo response data")))
                return
            }
            guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(GeoLookupError(message: "Invalid IP geo JSON")))
                return
            }

            guard let latitude = parseDouble(raw["latitude"]),
                  let longitude = parseDouble(raw["longitude"]) else {
                completion(.failure(GeoLookupError(message: "Missing latitude/longitude in IP geo response")))
                return
            }

            let weatherURLString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m"
            guard let weatherURL = URL(string: weatherURLString) else {
                completion(.failure(GeoLookupError(message: "Invalid weather URL")))
                return
            }

            session.dataTask(with: weatherURL) { weatherData, _, weatherError in
                if let weatherError {
                    completion(.failure(weatherError))
                    return
                }
                guard let weatherData else {
                    completion(.failure(GeoLookupError(message: "Missing weather response data")))
                    return
                }
                guard let weatherRaw = try? JSONSerialization.jsonObject(with: weatherData) as? [String: Any],
                      let current = weatherRaw["current"] as? [String: Any],
                      let temperature = parseDouble(current["temperature_2m"]) else {
                    completion(.failure(GeoLookupError(message: "Missing temperature in weather response")))
                    return
                }
                completion(.success(temperature))
            }.resume()
        }.resume()
    }

    private func fetchSunEventFromIP(completion: @escaping (Result<(label: String, date: Date), Error>) -> Void) {
        struct GeoLookupError: LocalizedError {
            let message: String
            var errorDescription: String? { message }
        }

        func parseDouble(_ value: Any?) -> Double? {
            if let number = value as? NSNumber {
                return number.doubleValue
            }
            if let string = value as? String {
                return Double(string)
            }
            return nil
        }

        func parseEpochArray(_ value: Any?) -> [TimeInterval] {
            if let numbers = value as? [NSNumber] {
                return numbers.map { $0.doubleValue }
            }
            if let numbers = value as? [Double] {
                return numbers
            }
            if let numbers = value as? [Int] {
                return numbers.map(Double.init)
            }
            if let strings = value as? [String] {
                return strings.compactMap(Double.init)
            }
            return []
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        let session = URLSession(configuration: configuration)

        guard let geoURL = URL(string: "https://ipapi.co/json/") else {
            completion(.failure(GeoLookupError(message: "Invalid IP geo URL")))
            return
        }

        session.dataTask(with: geoURL) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(GeoLookupError(message: "Missing IP geo response data")))
                return
            }
            guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let latitude = parseDouble(raw["latitude"]),
                  let longitude = parseDouble(raw["longitude"]) else {
                completion(.failure(GeoLookupError(message: "Invalid IP geo JSON")))
                return
            }

            let weatherURLString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&daily=sunrise,sunset&forecast_days=2&timezone=auto&timeformat=unixtime"
            guard let weatherURL = URL(string: weatherURLString) else {
                completion(.failure(GeoLookupError(message: "Invalid sun event URL")))
                return
            }

            session.dataTask(with: weatherURL) { weatherData, _, weatherError in
                if let weatherError {
                    completion(.failure(weatherError))
                    return
                }
                guard let weatherData else {
                    completion(.failure(GeoLookupError(message: "Missing sun event response data")))
                    return
                }
                guard let weatherRaw = try? JSONSerialization.jsonObject(with: weatherData) as? [String: Any],
                      let daily = weatherRaw["daily"] as? [String: Any] else {
                    completion(.failure(GeoLookupError(message: "Missing sunrise/sunset in weather response")))
                    return
                }

                let sunriseEpochs = parseEpochArray(daily["sunrise"])
                let sunsetEpochs = parseEpochArray(daily["sunset"])
                var events: [(label: String, date: Date)] = []
                for sunriseEpoch in sunriseEpochs {
                    events.append(("Sunrise", Date(timeIntervalSince1970: sunriseEpoch)))
                }
                for sunsetEpoch in sunsetEpochs {
                    events.append(("Sunset", Date(timeIntervalSince1970: sunsetEpoch)))
                }
                let now = Date()
                let nextEvent = events
                    .filter { $0.date > now }
                    .min { $0.date < $1.date }

                guard let nextEvent else {
                    completion(.failure(GeoLookupError(message: "No upcoming sunrise/sunset event found")))
                    return
                }

                completion(.success((label: nextEvent.label, date: nextEvent.date)))
            }.resume()
        }.resume()
    }
}
