import CoreLocation
import Foundation

struct WeatherSnapshot: Equatable {
    let summary: String
    let fetchedAt: Date
}

final class WeatherService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let session = URLSession(configuration: .ephemeral)
    private let cacheTTL: TimeInterval = 30 * 60

    private var completions: [(WeatherSnapshot?) -> Void] = []
    private var cachedSnapshot: WeatherSnapshot?
    private var pendingLocationRequest = false

    override init() {
        super.init()
        manager.delegate = self
    }

    var hasLocationPermission: Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    func ensureAuthorization() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func fetchSummary(completion: @escaping (WeatherSnapshot?) -> Void) {
        if let cachedSnapshot, Date().timeIntervalSince(cachedSnapshot.fetchedAt) < cacheTTL {
            completion(cachedSnapshot)
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            completions.append(completion)
            ensureAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            completions.append(completion)
            requestLocationIfNeeded()
        default:
            completion(nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if hasLocationPermission {
            requestLocationIfNeeded()
            return
        }

        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            flush(with: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        pendingLocationRequest = false
        guard let location = locations.last else {
            flush(with: nil)
            return
        }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            let city = placemarks?.first?.locality ?? placemarks?.first?.administrativeArea ?? "当前位置"
            self.fetchWeather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, city: city)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        pendingLocationRequest = false
        flush(with: nil)
    }

    private func requestLocationIfNeeded() {
        guard !pendingLocationRequest else { return }
        pendingLocationRequest = true
        manager.requestLocation()
    }

    private func fetchWeather(latitude: Double, longitude: Double, city: String) {
        let urlString = "https://wttr.in/\(latitude),\(longitude)?format=j1"
        guard let url = URL(string: urlString) else {
            flush(with: nil)
            return
        }

        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data else {
                DispatchQueue.main.async {
                    self?.flush(with: nil)
                }
                return
            }

            let snapshot = self.parseSnapshot(from: data, city: city)
            DispatchQueue.main.async {
                self.flush(with: snapshot)
            }
        }.resume()
    }

    private func parseSnapshot(from data: Data, city: String) -> WeatherSnapshot? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let current = (object["current_condition"] as? [[String: Any]])?.first
        else {
            return nil
        }

        let temp = current["temp_C"] as? String ?? ""
        let desc = ((current["weatherDesc"] as? [[String: Any]])?.first?["value"] as? String) ?? ""
        let pieces = [city, temp.isEmpty ? nil : "\(temp)°C", desc.isEmpty ? nil : desc].compactMap { $0 }
        guard !pieces.isEmpty else { return nil }

        return WeatherSnapshot(summary: pieces.joined(separator: "，"), fetchedAt: Date())
    }

    private func flush(with snapshot: WeatherSnapshot?) {
        if let snapshot {
            cachedSnapshot = snapshot
        }
        let pending = completions
        completions.removeAll()
        pending.forEach { $0(snapshot) }
    }
}
