// Copyright 2020 Bret Taylor

import Foundation
import GameKit
import MapKit

/// Determines which of the readings in `readings` to render in the given `region`, taking into account the currently rendered readings in `currentAnnotations`. `render` is called with the list of readings that should be added and removed from the `MKMapView`.
///
/// Because `MKMapView` cannot render thousands of annotations, if we exceed our the limit specified by `maximumAnnotationsToDisplay`, we choose a random sample to display. To avoid our sampling resulting in exceessive movement on the map, we (slightly) prefer keeping existing annotations on the map when redrawing.
///
/// - Parameters:
///   - readings: The R-tree of AQI readings
///   - region: The current `MKMapView` region
///   - currentAnnotations: The return value from `MKMapView.annotations`
///   - maximumAnnotationsToDisplay: The maximum number of readings we should display on the map at one time (e.g., `750`)
///   - render: The callback that renders the readings to the `MKMapView`
@available(iOS 10.0, *)
@available(macOS 10.12, *)
public func calculateRenderOperation(readings: GKRTree<Reading>, region: MKCoordinateRegion, currentAnnotations: [MKAnnotation], maximumAnnotationsToDisplay: Int, render: @escaping (_ addAnnotations: [AQI.Reading], _ removeAnnotations: [AQI.Reading], _ updatedAnnotations: [AQI.Reading: AQI.Reading]) -> Void) {
    DispatchQueue.global(qos: .background).async {
        var existingReadings = Set<AQI.Reading>()
        for annotation in currentAnnotations {
            if let sensor = annotation as? AQI.Reading {
                existingReadings.insert(sensor)
            }
        }

        // TODO: This breaks around the international date line, but 🤷
        let minLatitude = region.center.latitude - region.span.latitudeDelta / 2
        let maxLatitude = region.center.latitude + region.span.latitudeDelta / 2
        let minLongitude = region.center.longitude - region.span.longitudeDelta / 2
        let maxLongitude = region.center.longitude + region.span.longitudeDelta / 2
        var visibleReadings = readings.elements(inBoundingRectMin: vector_float2(Float(minLatitude), Float(minLongitude)), rectMax: vector_float2(Float(maxLatitude), Float(maxLongitude)))

        let drawSensors: ArraySlice<AQI.Reading>
        if visibleReadings.count > maximumAnnotationsToDisplay {
            // Choose a sample if we have too many sensors. Slightly prefer sensors already on the map if they are still in the target region to make panning more stable.
            var remainingSensors = Set<AQI.Reading>()
            for existing in existingReadings {
                if existing.coordinate.latitude >= minLatitude && existing.coordinate.latitude <= maxLatitude && existing.coordinate.longitude >= minLongitude && existing.coordinate.longitude <= maxLongitude {
                    remainingSensors.insert(existing)
                }
            }
            visibleReadings.shuffle()
            for sensor in visibleReadings[..<maximumAnnotationsToDisplay] {
                remainingSensors.insert(sensor)
            }
            drawSensors = Array<AQI.Reading>(remainingSensors)[..<maximumAnnotationsToDisplay]
        } else {
            drawSensors = visibleReadings[..<visibleReadings.count]
        }

        var addReadings = Set<AQI.Reading>()
        var updatedAnnotations: [AQI.Reading: AQI.Reading] = [:]
        for sensor in drawSensors {
            if existingReadings.contains(sensor) {
                if let existing = existingReadings.remove(sensor) {
                    if existing.aqi != sensor.aqi {
                        updatedAnnotations[existing] = sensor
                    }
                }
            } else {
                addReadings.insert(sensor)
            }
        }
        let addAnnotations = Array<AQI.Reading>(addReadings)
        let removeAnnotations = Array<AQI.Reading>(existingReadings)

        DispatchQueue.main.async {
            render(addAnnotations, removeAnnotations, updatedAnnotations)
        }
    }
}
