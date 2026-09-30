import Flutter
import Foundation
import MapKit
import UIKit

/// Static Apple Maps images for the day card and the Tagesbilanz
/// (lib/platform/map_snapshot.dart). Channel: de.torchtechnology.slopetrack/map_snapshot
///
/// `snapshot({lat, lon, latSpan, lonSpan, width, height, scale, style, route, routeColor, routeWidth})`
/// answers PNG bytes (FlutterStandardTypedData) or nil. Satellite imagery falls
/// back to the muted standard map; any failure (offline, bad arguments, timeout)
/// is nil — nothing is ever thrown across the channel.
final class MapSnapshot {
  static let shared = MapSnapshot()

  /// Snapshotters stay alive until their completion fires.
  private var active: [UUID: MKMapSnapshotter] = [:]
  private let lock = NSLock()
  private let timeout: TimeInterval = 15

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "de.torchtechnology.slopetrack/map_snapshot", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "snapshot" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self, let args = call.arguments as? [String: Any], let request = Request(args) else {
        result(nil)
        return
      }
      self.render(request, style: request.style) { data in
        DispatchQueue.main.async {
          result(data.map { FlutterStandardTypedData(bytes: $0) })
        }
      }
    }
  }

  // MARK: - Request

  struct Request {
    let region: MKCoordinateRegion
    let size: CGSize
    let scale: CGFloat
    let style: String
    let route: [CLLocationCoordinate2D]
    let routeColor: UIColor
    let routeWidth: CGFloat

    init?(_ a: [String: Any]) {
      guard let lat = Request.double(a["lat"]), let lon = Request.double(a["lon"]),
            let latSpan = Request.double(a["latSpan"]), let lonSpan = Request.double(a["lonSpan"]),
            let width = Request.double(a["width"]), let height = Request.double(a["height"]),
            latSpan > 0, lonSpan > 0, width >= 1, height >= 1, width <= 4096, height <= 4096,
            abs(lat) <= 85, abs(lon) <= 180
      else { return nil }
      region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
        span: MKCoordinateSpan(latitudeDelta: min(latSpan, 170), longitudeDelta: min(lonSpan, 360))
      )
      size = CGSize(width: width, height: height)
      scale = CGFloat(min(max(Request.double(a["scale"]) ?? 2, 1), 3))
      style = (a["style"] as? String) ?? "satellite"
      var pts: [CLLocationCoordinate2D] = []
      if let raw = a["route"] as? [Any] {
        pts.reserveCapacity(raw.count)
        for item in raw {
          guard let pair = item as? [Any], pair.count >= 2,
                let la = Request.double(pair[0]), let lo = Request.double(pair[1]) else { continue }
          pts.append(CLLocationCoordinate2D(latitude: la, longitude: lo))
        }
      }
      route = pts
      let argb = (a["routeColor"] as? NSNumber)?.uint32Value ?? 0xFFE3_C88C
      routeColor = UIColor(
        red: CGFloat((argb >> 16) & 0xFF) / 255,
        green: CGFloat((argb >> 8) & 0xFF) / 255,
        blue: CGFloat(argb & 0xFF) / 255,
        alpha: CGFloat((argb >> 24) & 0xFF) / 255
      )
      routeWidth = CGFloat(Request.double(a["routeWidth"]) ?? 2.5)
    }

    static func double(_ v: Any?) -> Double? {
      if let n = v as? NSNumber { return n.doubleValue }
      if let d = v as? Double { return d }
      return nil
    }
  }

  // MARK: - Rendering

  private func options(for request: Request, style: String) -> MKMapSnapshotter.Options {
    let o = MKMapSnapshotter.Options()
    o.region = request.region
    o.size = request.size
    o.showsBuildings = false
    o.pointOfInterestFilter = .excludingAll
    o.traitCollection = UITraitCollection(traitsFrom: [
      UITraitCollection(displayScale: request.scale),
      UITraitCollection(userInterfaceStyle: .dark),
    ])
    if #available(iOS 17.0, *) {
      switch style {
      case "hybrid":
        o.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .flat)
      case "muted":
        o.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
      default:
        o.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat)
      }
    } else {
      switch style {
      case "hybrid": o.mapType = .hybrid
      case "muted": o.mapType = .mutedStandard
      default: o.mapType = .satellite
      }
    }
    return o
  }

  private func render(_ request: Request, style: String, completion: @escaping (Data?) -> Void) {
    let snapshotter = MKMapSnapshotter(options: options(for: request, style: style))
    let id = UUID()
    lock.lock()
    active[id] = snapshotter
    lock.unlock()

    // Exactly one answer per call: the completion or the timeout, whichever is first.
    var done = false
    let once = NSLock()
    func finish(_ snapshot: MKMapSnapshotter.Snapshot?) {
      once.lock()
      let first = !done
      done = true
      once.unlock()
      guard first else { return }
      lock.lock()
      active[id] = nil
      lock.unlock()
      if let snapshot, let png = draw(snapshot, request) {
        completion(png)
      } else if style == "satellite" || style == "hybrid" {
        render(request, style: "muted", completion: completion)
      } else {
        completion(nil)
      }
    }

    snapshotter.start(with: DispatchQueue.global(qos: .utility)) { snapshot, error in
      finish(error == nil ? snapshot : nil)
    }
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
      once.lock()
      let pending = !done
      once.unlock()
      guard pending else { return }
      snapshotter.cancel()
      // A timed-out satellite request does not retry: the network is the problem.
      once.lock()
      done = true
      once.unlock()
      self.lock.lock()
      self.active[id] = nil
      self.lock.unlock()
      completion(nil)
    }
  }

  /// The snapshot image with the route on top: a dark casing under a
  /// round-capped stroke so the line reads on snow and on forest alike.
  private func draw(_ snapshot: MKMapSnapshotter.Snapshot, _ request: Request) -> Data? {
    let image = snapshot.image
    let format = UIGraphicsImageRendererFormat()
    format.scale = image.scale
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
    let composed = renderer.image { ctx in
      image.draw(at: .zero)
      guard request.route.count >= 2 else { return }
      let path = UIBezierPath()
      for (i, c) in request.route.enumerated() {
        let p = snapshot.point(for: c)
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
      }
      path.lineCapStyle = .round
      path.lineJoinStyle = .round
      let cg = ctx.cgContext
      cg.saveGState()
      UIColor.black.withAlphaComponent(0.35).setStroke()
      path.lineWidth = request.routeWidth + 2
      path.stroke()
      request.routeColor.setStroke()
      path.lineWidth = request.routeWidth
      path.stroke()
      // Start dot.
      let start = snapshot.point(for: request.route[0])
      let r = request.routeWidth * 1.3
      request.routeColor.setFill()
      UIBezierPath(ovalIn: CGRect(x: start.x - r, y: start.y - r, width: 2 * r, height: 2 * r)).fill()
      cg.restoreGState()
    }
    return composed.pngData()
  }
}
