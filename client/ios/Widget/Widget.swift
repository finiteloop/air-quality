// Copyright 2020 Bret Taylor

import AQI
import Contacts
import WidgetKit
import MapKit
import SwiftUI

private let readingSize: CGFloat = 28

@main
struct AirBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        MapWidget()
    }
}

struct MapProvider : IntentTimelineProvider {
    typealias Entry = MapEntry
    typealias Intent = LocationSelectionIntent

    func placeholder(in context: Context) -> MapEntry {
        return MapEntry(date: Date(), mapImage: UIImage(named: "MapPlaceholder")!, placeholderReadings: false)
    }

    func getSnapshot(for intent: LocationSelectionIntent, in context: Context, completion: @escaping (MapEntry) -> Void) {
        var location = self._location(for: intent)
        if location == nil {
            let locationManager = CLLocationManager()
            locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
            if (CLLocationManager.locationServicesEnabled()) {
                locationManager.requestAlwaysAuthorization()
            }
            location = locationManager.location
            
            // CLLocationManager is really unreliable in a widget, not properly calling delegates. To stabilize the widget, we save the last location we read to prevent it from regressing to `defaultLocation` when reading it fails
            let cacheKey = "lastWidgetLocation"
            if let activeLocation = location {
                UserDefaults.standard.set([
                    "latitude": activeLocation.coordinate.latitude,
                    "longitude": activeLocation.coordinate.longitude,
                ], forKey: cacheKey)
            } else if let cachedLocation = UserDefaults.standard.object(forKey: cacheKey) as? [String: CLLocationDegrees] {
                if let latitude = cachedLocation["latitude"],
                   let longitude = cachedLocation["longitude"] {
                    location = CLLocation(latitude: latitude, longitude: longitude)
                }
            }
        }
        self._mapImage(location: location, size: context.displaySize) { (mapImage) in
            completion(MapEntry(date: Date(), mapImage: mapImage ?? UIImage(named: "MapPlaceholder")!))
        }
    }
    
    func getTimeline(for intent: LocationSelectionIntent, in context: Context, completion: @escaping (Timeline<MapEntry>) -> Void) {
        self.getSnapshot(for: intent, in: context) { (entry) in
            let refreshTime = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(refreshTime))
            completion(timeline)
        }
    }
    
    private func _location(for intent: LocationSelectionIntent) -> CLLocation? {
        return intent.location?.location
    }
    
    private func _mapImage(location: CLLocation?, size: CGSize, callback: @escaping (UIImage?) -> Void) {
        let coordinate: CLLocationCoordinate2D
        if let location = location {
            coordinate = location.coordinate
        } else {
            coordinate = defaultLocation().coordinate
        }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 4046, longitudinalMeters: 4046)
        options.size = size
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { (snapshot, error) in
            guard let snapshot = snapshot else {
                callback(nil)
                return
            }
            AQI.downloadReadings { (percentage) in
            } onResponse: { (readings, error) in
                if let readings = readings {
                    var region = options.region
                    if size.width > size.height {
                        region.span.longitudeDelta *= 3
                    }
                    AQI.calculateRenderOperation(readings: readings, region: region, currentAnnotations: [], maximumAnnotationsToDisplay: 100) { (addAnnotations, removeAnnotations, updatedAnnotations) in
                        let image = UIGraphicsImageRenderer(size: options.size).image { context in
                            snapshot.image.draw(at: .zero)
                            for reading in addAnnotations {
                                let point = snapshot.point(for: reading.coordinate)
                                let rect = CGRect(x: point.x - readingSize / 2, y: point.y - readingSize / 2, width: readingSize, height: readingSize)
                                context.cgContext.setFillColor(cgColor(AQI.color(aqi: reading.aqi)))
                                context.cgContext.fillEllipse(in: rect)
                                
                                let aqi = String(reading.aqi)
                                let style = NSMutableParagraphStyle()
                                style.alignment = .center
                                let attributes: [NSAttributedString.Key : Any] = [
                                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                                    NSAttributedString.Key.paragraphStyle: style,
                                    NSAttributedString.Key.foregroundColor: uiColor(AQI.textColor(aqi: reading.aqi), 0.8),
                                ]
                                let textRect = aqi.boundingRect(with: rect.size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
                                String(reading.aqi).draw(in: CGRect(x: rect.minX, y: rect.minY + textRect.size.height / 2, width: rect.width, height: textRect.size.height), withAttributes: attributes)
                            }
                        }
                        callback(image)
                    }
                } else {
                    callback(snapshot.image)
                }
            }
        }
    }
}

struct MapEntry: TimelineEntry {
    public let date: Date
    public let mapImage: UIImage
    public var placeholderReadings: Bool = false
}

struct MapWidgetEntryView: View {
    var entry: MapProvider.Entry

    var body: some View {
        ZStack {
            Image(uiImage: entry.mapImage)
            if entry.placeholderReadings {
                placeholderReading(aqi: 5, x: -100, y: -90)
                placeholderReading(aqi: 10, x: -50, y: -95)
                placeholderReading(aqi: 7, x: -40, y: -60)
                placeholderReading(aqi: 15, x: 10, y: -35)
                placeholderReading(aqi: 75, x: 20, y: 20)
                placeholderReading(aqi: 110, x: 80, y: -20)
                placeholderReading(aqi: 175, x: 110, y: -40)
                placeholderReading(aqi: 100, x: 40, y: 60)
                placeholderReading(aqi: 90, x: 90, y: 40)
            }
        }
    }
}

struct MapWidget: Widget {
    private let kind: String = "MapWidget"

    public var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: LocationSelectionIntent.self, provider: MapProvider()) { entry in
            MapWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(NSLocalizedString("Air Quality Map", comment: "Title of air quality map widget"))
        .description(NSLocalizedString("A map of air quality readings around your location", comment: "Description of air quality map widget"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private func defaultLocation() -> CLLocation {
    // Apple Headquarters
    return CLLocation(latitude: 37.33468, longitude: -122.00898)
}

private func placeholderReading(aqi: UInt32, x: CGFloat, y: CGFloat) -> some View {
    return Text(String(aqi))
        .font(Font.system(size: 12))
        .foregroundColor(swiftColor(AQI.textColor(aqi: aqi))).opacity(/*@START_MENU_TOKEN@*/0.8/*@END_MENU_TOKEN@*/)
        .frame(width: readingSize, height: readingSize)
        .background(swiftColor(AQI.color(aqi: aqi)))
        .cornerRadius(readingSize / 2)
        .position(x: 208 + x, y: 208 + y)
}

private func cgColor(_ color: AQI.Color, _ alpha: CGFloat = 1.0) -> CGColor {
    return CGColor(red: CGFloat(color.r / 255.0), green: CGFloat(color.g / 255.0), blue: CGFloat(color.b / 255.0), alpha: alpha)
}

private func uiColor(_ color: AQI.Color, _ alpha: CGFloat = 1.0) -> UIColor {
    return UIColor(red: CGFloat(color.r / 255.0), green: CGFloat(color.g / 255.0), blue: CGFloat(color.b / 255.0), alpha: alpha)
}

private func swiftColor(_ color: AQI.Color) -> SwiftUI.Color {
    return SwiftUI.Color(red: Double(color.r / 255.0), green: Double(color.g / 255.0), blue: Double(color.b / 255.0))
}

struct MapWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MapWidgetEntryView(entry: MapEntry(date: Date(), mapImage: UIImage(named: "MapPlaceholder")!, placeholderReadings: true)).previewContext(WidgetPreviewContext(family: .systemSmall))
            MapWidgetEntryView(entry: MapEntry(date: Date(), mapImage: UIImage(named: "MapPlaceholder")!, placeholderReadings: true)).previewContext(WidgetPreviewContext(family: .systemMedium))
            MapWidgetEntryView(entry: MapEntry(date: Date(), mapImage: UIImage(named: "MapPlaceholder")!, placeholderReadings: true)).previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}

