import CoreLocation
import Flutter
import Foundation

/// Significant-location-change monitor. With "Always" authorization iOS relaunches
/// the app in the background after a kill once the user moves ~500 m; the Dart side
/// (main.dart) then resumes the active day. Channel: de.torchtechnology.slopetrack/watchdog
final class TrackingWatchdog: NSObject, CLLocationManagerDelegate {
  static let shared = TrackingWatchdog()
  private let manager = CLLocationManager()
  var launchedFromLocation = false

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "de.torchtechnology.slopetrack/watchdog", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(false); return }
      switch call.method {
      case "start":
        self.manager.delegate = self
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
          self.manager.startMonitoringSignificantLocationChanges()
          result(true)
        } else {
          result(false)
        }
      case "stop":
        self.manager.stopMonitoringSignificantLocationChanges()
        result(true)
      case "didLaunchFromLocation":
        result(self.launchedFromLocation)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // Nothing to do: the relaunch itself is the point. The Flutter engine starts,
    // RecoveryService sees the active day and resubscribes the full-accuracy stream.
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
