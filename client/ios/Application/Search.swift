// Copyright 2020 Bret Taylor

import Contacts
import MapKit
import UIKit

protocol MapSearchControllerDelegate: AnyObject {
    func mapSearchController(_ controller: MapSearchController, selectedItem: MKMapItem)
}

class MapSearchController: UISearchController, MapSearchResultsControllerDelegate {
    weak var mapSearchControllerDelegate: MapSearchControllerDelegate?

    init(mapView: MKMapView) {
        let results = MapSearchResultsController(mapView: mapView)
        super.init(searchResultsController: results)
        self.searchResultsUpdater = results
        results.mapSearchResultsControllerDelegate = self
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func mapSearchResultsController(_ controller: MapSearchResultsController, selectedItem: MKMapItem) {
        self.mapSearchControllerDelegate?.mapSearchController(self, selectedItem: selectedItem)
        self.searchBar.text = ""
        self.searchResultsController?.dismiss(animated: true, completion: nil)
    }
}

private protocol MapSearchResultsControllerDelegate: AnyObject {
    func mapSearchResultsController(_ controller: MapSearchResultsController, selectedItem: MKMapItem)
}

private class MapSearchResultsController: UITableViewController, UISearchResultsUpdating {
    weak var mapSearchResultsControllerDelegate: MapSearchResultsControllerDelegate?

    private weak var _mapView: MKMapView?
    private var _results: [MKMapItem] = []

    init(mapView: MKMapView) {
        self._mapView = mapView
        super.init(style: .plain)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(MapSearchResultCell.self, forCellReuseIdentifier: NSStringFromClass(MapSearchResultCell.self))
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text else {
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region = self._mapView?.region {
            request.region = region
        }
        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            if let response = response {
                self._results = response.mapItems
                self.tableView.reloadData()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _results.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NSStringFromClass(MapSearchResultCell.self), for: indexPath) as! MapSearchResultCell
        cell.mapItem = self._results[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.mapSearchResultsControllerDelegate?.mapSearchResultsController(self, selectedItem: self._results[indexPath.row])
    }
}

private class MapSearchResultCell: UITableViewCell {
    var mapItem: MKMapItem? {
        didSet {
            self._redraw()
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.textLabel?.text = ""
        self.detailTextLabel?.text = ""
    }
    
    private func _redraw() {
        guard let mapItem = self.mapItem else {
            return
        }
        self.textLabel?.text = mapItem.name
        let formatter = CNPostalAddressFormatter()
        if let address = mapItem.placemark.postalAddress {
            let formatted = formatter.string(from: address)
            self.detailTextLabel?.text = formatted.replacingOccurrences(of: "\n", with: ", ")
        }
    }
}
