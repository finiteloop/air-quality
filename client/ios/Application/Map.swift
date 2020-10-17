// Copyright 2020 Bret Taylor

import AQI
import GameKit
import MapKit
import UIKit
import os.log

class MapController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, MapSearchControllerDelegate {
    private var _readings = GKRTree<AQI.Reading>(maxNumberOfChildren: 2)
    private var _redrawing = false
    private var _needsRedraw = false
    private var _downloadStartTime: CFAbsoluteTime = 0
    private var _locationLoadTime: CFAbsoluteTime = 0
    private let _maximumAnnoationsToDisplay = 750
    private var _errorTimer: Timer?
    
    private lazy var _searchController: MapSearchController = {
        let searchController = MapSearchController(mapView: self._mapView)
        searchController.hidesNavigationBarDuringPresentation = false
        return searchController
    }()

    private lazy var _mapView: MKMapView = {
        let mapView = MKMapView(frame: self.view.bounds)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.register(ReadingView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(AQI.Reading.self))
        mapView.showsUserLocation = true
        return mapView
    }()

    private lazy var _progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0.5
        progressView.isHidden = true
        return progressView
    }()

    private lazy var _locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        if (CLLocationManager.locationServicesEnabled()) {
            locationManager.requestWhenInUseAuthorization()
        }
        if (CLLocationManager.significantLocationChangeMonitoringAvailable()) {
            locationManager.startMonitoringSignificantLocationChanges()
        } else {
            locationManager.startUpdatingLocation()
        }
        return locationManager
    }()

    private lazy var _errorBar: UITextView = {
        let errorBar = UITextView(frame: self.view.bounds)
        errorBar.backgroundColor = .systemRed
        errorBar.text = NSLocalizedString("Unable to download new air quality data", comment: "Error message when new map data cannot be downloaded")
        errorBar.textAlignment = .center
        errorBar.isScrollEnabled = false
        errorBar.isUserInteractionEnabled = false
        let font = UIFont.preferredFont(forTextStyle: .callout)
        errorBar.font = UIFont.systemFont(ofSize: font.pointSize, weight: .medium)
        errorBar.translatesAutoresizingMaskIntoConstraints = false
        errorBar.textColor = .white
        errorBar.alpha = 0
        errorBar.isHidden = true
        return errorBar
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("Air Quality Readings", comment: "Title of main map displaying AQI by location")
        let centerMap = UIBarButtonItem(image: UIImage(named: "Location"), style: .plain, target: self, action: #selector(self._centerMap))
        centerMap.accessibilityLabel = NSLocalizedString("Center Map on Location", comment: "Button to center the map on the current location")
        self.navigationItem.leftBarButtonItem = centerMap
        let download = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self._downloadSensorData))
        download.accessibilityLabel = NSLocalizedString("Refresh Data", comment: "Button to download new data from the server")
        self.navigationItem.rightBarButtonItem = download
        self.definesPresentationContext = true
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = UIView(frame: UIScreen.main.bounds)
        self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(self._mapView)
        self.view.addSubview(self._errorBar)
        self.view.addSubview(self._progressView)
        if let region = self._preferredZoomRegion() {
            self._mapView.region = region
        } else {
            self._locationLoadTime = CFAbsoluteTimeGetCurrent()
        }
        navigationItem.titleView = self._searchController.searchBar
        self._searchController.mapSearchControllerDelegate = self

        let safeArea = self.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            self._errorBar.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self._errorBar.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            self._errorBar.topAnchor.constraint(equalTo: safeArea.topAnchor),
            self._progressView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self._progressView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            self._progressView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            self._mapView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self._mapView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self._mapView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self._mapView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
        ])
    }

    /// If sensor data is stale (older than 15 minutes), re-download it from the server.
    func refreshStaleSensorData() {
        let dataAge = CFAbsoluteTimeGetCurrent() - self._downloadStartTime
        if dataAge > 900 {
            self._downloadSensorData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.refreshStaleSensorData()
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is AQI.Reading else { return nil }
        return mapView.dequeueReusableAnnotationView(withIdentifier: NSStringFromClass(AQI.Reading.self), for: annotation)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        _redrawAnnotations()
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

    func mapSearchController(_ controller: MapSearchController, selectedItem: MKMapItem) {
        if let region = selectedItem.placemark.region as? CLCircularRegion {
            self._mapView.setRegion(MKCoordinateRegion(center: region.center, latitudinalMeters: region.radius * 2, longitudinalMeters: region.radius * 2), animated: true)
        } else if let location = selectedItem.placemark.location {
            self._mapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 8046, longitudinalMeters: 8046), animated: true)
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
        AQI.calculateRenderOperation(readings: self._readings, region: self._mapView.region, currentAnnotations: self._mapView.annotations, maximumAnnotationsToDisplay: self._maximumAnnoationsToDisplay) { (addAnnotations, removeAnnotations, updatedAnnotations) in
            self._mapView.removeAnnotations(removeAnnotations)
            self._mapView.addAnnotations(addAnnotations)
            for (existing, updated) in updatedAnnotations {
                if let readingView = self._mapView.view(for: existing) as? ReadingView {
                    if let oldReading = readingView.annotation as? AQI.Reading {
                        oldReading.update(updated)
                    }
                    readingView.prepareForDisplay()
                }
            }
            self._redrawing = false
            if self._needsRedraw {
                self._needsRedraw = false
                self._redrawAnnotations()
            }
        }
    }

    @objc private func _centerMap() {
        if let region = self._preferredZoomRegion() {
            self._mapView.setRegion(region, animated: true)
        } else {
            let alert = UIAlertController(title: title, message: NSLocalizedString("The application does not currently have permission to access your location. You can give the application permission in Settings.", comment: "Error message when application cannot read location"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Close alert dialog"), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Open Settings", comment: "Dialog prompt to open location settings"), style: .default) { (UIAlertAction) in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil)
            })
            self.present(alert, animated: true, completion: nil)
        }
    }

    @objc private func _downloadSensorData() {
        if !self._progressView.isHidden {
            return
        }
        self._progressView.progress = 0
        self._progressView.isHidden = false
        self._downloadStartTime = CFAbsoluteTimeGetCurrent()
        AQI.downloadReadings { (percentage) in
            self._progressView.progress = percentage
        } onResponse: { (readings, error) in
            let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "map")
            if let error = error {
                os_log("🔴 Failed to update readings: %{public}s", log: log, type: .info, error.localizedDescription)
                self._showDownloadError()
            } else if let readings = readings {
                os_log("🟢 Updated readings from server (%.3fs)", log: log, type: .info, CFAbsoluteTimeGetCurrent() - self._downloadStartTime)
                self._readings = readings
                self._redrawAnnotations()
            }
            self._progressView.progress = 1
            UIView.animate(withDuration: 0.25) {
                self._progressView.alpha = 0
            } completion: { (finished) in
                self._progressView.isHidden = true
                self._progressView.alpha = 1
            }
        }
    }

    private func _showDownloadError() {
        if let timer = self._errorTimer {
            timer.invalidate()
        }
        self._errorBar.isHidden = false
        UIView.animate(withDuration: 0.25) {
            self._errorBar.alpha = 1
        }
        self._errorTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { (timer) in
            self._errorTimer = nil
            UIView.animate(withDuration: 0.5) {
                self._errorBar.alpha = 0
            } completion: { (finished) in
                self._errorBar.isHidden = true
            }
        }
    }
}

private class ReadingView: MKAnnotationView {
    private let _textAlpha: CGFloat = 0.8
    private let _size: CGFloat = 28
    private var _detailCalloutAccessoryView: SensorDetailView?

    private lazy var _label: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.layer.cornerRadius = _size / 2
        label.layer.masksToBounds = true
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.canShowCallout = true
        self.calloutOffset = CGPoint(x: 0, y: _size / 4)
        self.addSubview(self._label)
        self.bounds = CGRect(x: 0, y: 0, width: _size, height: _size)
        NSLayoutConstraint.activate([
            self._label.widthAnchor.constraint(equalToConstant: _size),
            self._label.heightAnchor.constraint(equalToConstant: _size),
            self._label.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self._label.centerYAnchor.constraint(equalTo: self.centerYAnchor),
        ])
    }
    
    override var detailCalloutAccessoryView: UIView? {
        get {
            if self._detailCalloutAccessoryView == nil {
                self._detailCalloutAccessoryView = SensorDetailView()
                self._detailCalloutAccessoryView?.reading = self.annotation as? AQI.Reading
            }
            return self._detailCalloutAccessoryView
        }
        set {
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        let update: () -> Void = {
            if selected {
                self._label.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                self._label.textColor = self._label.textColor.withAlphaComponent(0)
            } else {
                self._label.transform = .identity
                self._label.textColor = self._label.textColor.withAlphaComponent(self._textAlpha)
            }
        }
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: [], animations: update, completion: nil)
        } else {
            update()
        }
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        if let reading = self.annotation as? AQI.Reading {
            self._label.text = reading.aqiString
            self._label.backgroundColor = uiColor(AQI.color(aqi: reading.aqi))
            self._label.textColor = uiColor(AQI.textColor(aqi: reading.aqi)).withAlphaComponent(self._textAlpha)
            self._detailCalloutAccessoryView?.reading = reading
        }
    }
}

func uiColor(_ color: AQI.Color) -> UIColor {
    return UIColor(red: CGFloat(color.r / 255.0), green: CGFloat(color.g / 255.0), blue: CGFloat(color.b / 255.0), alpha: 1)
}
