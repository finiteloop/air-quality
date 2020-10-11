// Copyright 2020 Bret Taylor

import Foundation
import MapKit

/// An AQI reading from a PurpleAir sensor.
public class Reading: NSObject, MKAnnotation, Comparable {
    private let _sensor: Sensor

    init(_ sensor: Sensor) {
        self._sensor = sensor
    }
    
    public lazy var coordinate: CLLocationCoordinate2D = {
        return CLLocationCoordinate2D(latitude: Double(self._sensor.latitude), longitude: Double(self._sensor.longitude))
    }()
    
    public lazy var title: String? = {
        return String(self._sensor.reading)
    }()

    public var id: UInt32 {
        return self._sensor.id
    }

    public var aqi: UInt32 {
        return self._sensor.reading
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
