// Copyright 2020 Bret Taylor

import Foundation
import MapKit

/// An AQI reading from a PurpleAir sensor.
public class Reading: NSObject, MKAnnotation, Comparable {
    private var _sensor: Sensor

    init(_ sensor: Sensor) {
        self._sensor = sensor
    }
    
    public lazy var coordinate: CLLocationCoordinate2D = {
        return CLLocationCoordinate2D(latitude: Double(self._sensor.latitude), longitude: Double(self._sensor.longitude))
    }()
    
    public let title: String? = NSLocalizedString("PurpleAir Sensor", comment: "Title of sensor reading callout")
    
    public func update(_ updated: Reading) {
        self._sensor = updated._sensor
    }

    public var id: UInt32 {
        return self._sensor.id
    }
    
    public var aqiString: String {
        return String(self._sensor.aqi10M)
    }
    
    public var aqi: UInt32 {
        return self._sensor.aqi10M
    }
    
    public var aqi10M: UInt32 {
        return self._sensor.aqi10M
    }
    
    public var aqi30M: UInt32 {
        return self._sensor.aqi30M
    }
    
    public var aqi1H: UInt32 {
        return self._sensor.aqi1H
    }
    
    public var aqi6H: UInt32 {
        return self._sensor.aqi6H
    }
    
    public var aqi24H: UInt32 {
        return self._sensor.aqi24H
    }
    
    public var lastUpdated: Date {
        return Date(timeIntervalSince1970: Double(self._sensor.lastUpdated))
    }

    public var subtitle: String? {
        return nil
    }

    public override var hash: Int {
        return Int(self.id)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let rhs = object as? Reading {
            return self._sensor.id == rhs._sensor.id
        } else {
            return false
        }
    }

    public static func <(lhs: Reading, rhs: Reading) -> Bool {
        return lhs._sensor.id < rhs._sensor.id
    }

    public static func ==(lhs: Reading, rhs: Reading) -> Bool {
        return lhs._sensor.id == rhs._sensor.id
    }
}
