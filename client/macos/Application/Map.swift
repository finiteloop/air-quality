// Copyright 2020 Bret Taylor

import AQI
import Cocoa
import GameKit
import MapKit
import os.log

class MapController: NSViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    private var _readings = GKRTree<AQI.Reading>(maxNumberOfChildren: 2)
    private var _redrawing = false
    private var _needsRedraw = false
    private var _downloading = false
    private var _downloadStartTime: CFAbsoluteTime = 0
    private let _maximumAnnoationsToDisplay = 750
    private var _locationLoadTime: CFAbsoluteTime = 0

    private lazy var _mapView: MKMapView = {
        let mapView = MKMapView(frame: self.view.bounds)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.register(ReadingView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(AQI.Reading.self))
        mapView.showsUserLocation = true
        mapView.showsZoomControls = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsBuildings = true
        mapView.isZoomEnabled = true
        return mapView
    }()
    
    private lazy var _locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        if (CLLocationManager.locationServicesEnabled()) {
            locationManager.requestAlwaysAuthorization()
        }
        locationManager.startUpdatingLocation()
        return locationManager
    }()

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        self.view.autoresizingMask = [.width, .height]
        self.view.addSubview(self._mapView)
        if let region = self._preferredZoomRegion() {
            self._mapView.region = region
        } else {
            self._locationLoadTime = CFAbsoluteTimeGetCurrent()
        }
    
        NSLayoutConstraint.activate([
            self.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 500),
            self.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            self._mapView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self._mapView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self._mapView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self._mapView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
        ])
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.refreshStaleSensorData()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if let region = self._preferredZoomRegion() {
            self._mapView.setRegion(region, animated: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // If not available in loadView(), we have to handle setting it asynchronously here
        if self._locationLoadTime > 0 {
            let time = CFAbsoluteTimeGetCurrent() - self._locationLoadTime
            if time < 10 {
                if let region = self._preferredZoomRegion() {
                    self._mapView.setRegion(region, animated: time > 0.5)
                }
            }
            self._locationLoadTime = 0
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is AQI.Reading else { return nil }
        return mapView.dequeueReusableAnnotationView(withIdentifier: NSStringFromClass(AQI.Reading.self), for: annotation)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        _redrawAnnotations()
    }
    
    /// Centers the map on the user's location. If `interactive` is true and we cannot read the location, we show an error message to the end user.
    func centerMapOnCurrentLocation(interactive: Bool) {
        if let region = self._preferredZoomRegion() {
            self._mapView.setRegion(region, animated: true)
        }
    }

    /// If sensor data is stale (older than 15 minutes), re-download it from the server.
    func refreshStaleSensorData() {
        let dataAge = CFAbsoluteTimeGetCurrent() - self._downloadStartTime
        if dataAge > 900 {
            self.downloadSensorData()
        }
    }

    /// Downloads new sensor data from the server.
    func downloadSensorData(interactive: Bool = false) {
        if self._downloading {
            return
        }
        self._downloading = true
        self._downloadStartTime = CFAbsoluteTimeGetCurrent()
        AQI.downloadReadings { (percentage) in
            // TODO
        } onResponse: { (readings, error) in
            let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "map")
            if let error = error {
                os_log("🔴 Failed to update readings: %{public}s", log: log, type: .info, error.localizedDescription)
            } else if let readings = readings {
                os_log("🟢 Updated readings from server (%.3fs)", log: log, type: .info, CFAbsoluteTimeGetCurrent() - self._downloadStartTime)
                self._readings = readings
                self._redrawAnnotations()
            }
            self._downloading = false
        }
    }
    
    private func _preferredZoomRegion() -> MKCoordinateRegion? {
        if let location = self._locationManager.location {
            return MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 8046, longitudinalMeters: 8046)
        } else {
            return nil
        }
    }

    private func _redrawAnnotations() {
        if _redrawing {
            _needsRedraw = true
            return
        }
        AQI.calculateRenderOperation(readings: self._readings, region: self._mapView.region, currentAnnotations: self._mapView.annotations, maximumAnnotationsToDisplay: self._maximumAnnoationsToDisplay) { (addAnnotations, removeAnnotations, updateAnnotations) in
            self._mapView.removeAnnotations(removeAnnotations)
            self._mapView.addAnnotations(addAnnotations)
            self._redrawing = false
            if self._needsRedraw {
                self._needsRedraw = false
                self._redrawAnnotations()
            }
        }
    }
}

fileprivate class ReadingView: MKAnnotationView {
    private let _size: CGFloat = 30

    private lazy var _field: NSTextField = {
        let field = NSTextField()
        field.isBezeled = false
        field.isEditable = false
        field.isSelectable = false
        field.usesSingleLineMode = true
        field.alphaValue = 0.8
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byTruncatingTail
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        field.backgroundColor = .clear
        field.wantsLayer = true
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    private lazy var _circle: ReadingCircle = {
        let circle = ReadingCircle()
        circle.translatesAutoresizingMaskIntoConstraints = false
        return circle
    }()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.addSubview(self._circle)
        self.addSubview(self._field)
        NSLayoutConstraint.activate([
            self._circle.widthAnchor.constraint(equalToConstant: _size),
            self._circle.heightAnchor.constraint(equalToConstant: _size),
            self._circle.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self._circle.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self._field.widthAnchor.constraint(equalToConstant: _size),
            self._field.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self._field.centerYAnchor.constraint(equalTo: self.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        if let reading = self.annotation as? AQI.Reading {
            self._field.stringValue = reading.title!
            self._circle.setColor(color: AQI.color(aqi: reading.aqi))
            self._field.textColor = nsColor(AQI.textColor(aqi: reading.aqi))
        }
    }
}

fileprivate class ReadingCircle: NSView {
    private var _color: CGColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

    func setColor(color: AQI.Color) {
        self._color = nsColor(color).cgColor
        self.setNeedsDisplay(self.bounds)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState()
        context.setFillColor(self._color)
        context.fillEllipse(in: dirtyRect)
        context.restoreGState()
    }
}

fileprivate func nsColor(_ color: AQI.Color) -> NSColor {
    return NSColor(deviceRed: CGFloat(color.r / 255.0), green: CGFloat(color.g / 255.0), blue: CGFloat(color.b / 255.0), alpha: 1)
}
