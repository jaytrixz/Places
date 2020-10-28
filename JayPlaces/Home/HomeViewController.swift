//
//  HomeViewController.swift
//  JayPlaces
//
//  Created by John Joseph M. Santos on 10/26/20.
//

import UIKit
import MapKit
import CoreLocation
import CoreData

class HomeViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var segmentedControl: UISegmentedControl!

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    @IBOutlet weak var searchTextField: UITextField!

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var listView: UITableView!

    private var locationManager: CLLocationManager!
    private var userLocation: CLLocation!
    private var loadedLocation: CLLocationCoordinate2D?

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var context: NSManagedObjectContext!

    var presenter: HomePresenter!

    private var placesList: [Place]!

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeCoreData()
        initializeView()
    }

    // MARK: - Private methods

    private func initializeView() {
        activityIndicator.stopAnimating()

        initializeMap()
        initializeTap()
    }

    private func locateUser() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestAlwaysAuthorization()
            locationManager.requestWhenInUseAuthorization()
        }

        // Zoom to user location
        if let userLocation = locationManager.location?.coordinate {
            mapView.centerToLocation(userLocation)
            mapView.showsUserLocation = true
        }

        DispatchQueue.main.async {
            self.locationManager.startUpdatingLocation()
        }
    }

    private func initializeMap() {
        // Loads when the current user location is not yet determined by the app and an initial location
        // will be loaded from core data
        if userLocation == nil {
            guard loadedLocation != nil else { return }

            mapView.centerToLocation(loadedLocation!)
            mapView.showsUserLocation = true

            let annotation = MKPointAnnotation()
            annotation.title = "Initial location"
            annotation.coordinate = CLLocationCoordinate2D(latitude: Double(loadedLocation!.latitude),
                                                            longitude: Double(loadedLocation!.longitude))
            self.mapView.addAnnotation(annotation)

        // Loads when the current user location has been saved already to core data
        } else if userLocation.coordinate.latitude == loadedLocation!.latitude {
            mapView.centerToLocation(userLocation.coordinate)
            mapView.showsUserLocation = true

            let annotation = MKPointAnnotation()
            annotation.title = "User location"
            annotation.coordinate = CLLocationCoordinate2D(latitude: Double(userLocation.coordinate.latitude),
                                                            longitude: Double(userLocation.coordinate.longitude))
            self.mapView.addAnnotation(annotation)

        // Loads when the current user location is not yet saved to core data and the previously saved
        // location will be loaded in the map
        } else {
            mapView.centerToLocation(loadedLocation!)
            mapView.showsUserLocation = true

            let annotation = MKPointAnnotation()
            annotation.title = "User location"
            annotation.coordinate = CLLocationCoordinate2D(latitude: Double(loadedLocation!.latitude),
                                                            longitude: Double(loadedLocation!.longitude))
            self.mapView.addAnnotation(annotation)
        }
    }

    private func initializeTap() {
        let tap = UITapGestureRecognizer(target: view,
                                         action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)
    }

    private func initializeTableView() {
        listView.backgroundColor = .lightGray
    }

    private func hideKeyboard() {
        searchTextField.resignFirstResponder()
    }

    private func clearMapAnnotations() {
        mapView.removeAnnotations(mapView.annotations)
    }

    private func convertToKilometers(meters: Int) -> String {
        if meters == 1 {
            return "\(String(describing: meters)) meter"
        }

        if meters >= 1000 && meters < 2000 {
            return "\(String(describing: meters/1000)) kilometer"
        }

        if meters >= 2000 {
            return "\(String(describing: meters/1000)) kilometers"
        }

        return "\(String(describing: meters)) meters"
    }

    private func stopUpdatingLocation() {
        guard locationManager != nil else { return }

        DispatchQueue.main.async {
            self.locationManager.stopUpdatingLocation()
        }
    }

    private func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error: \(error)")
    }

    // MARK: - Core data methods

    private func initializeCoreData() {
        context = appDelegate.persistentContainer.viewContext

        fetchFromCoreData(keys: ["latitude", "longitude"])

        // Checks if a previously saved location is in core data. If none, initiate the default location
        if loadedLocation == nil {
            let initialValues = ["14.586716", "121.062449"]
            let initialKeys = ["latitude", "longitude"]

            let entity = NSEntityDescription.entity(forEntityName: "UserLocation",
                                                    in: context)
            let newUserLocation = NSManagedObject(entity: entity!,
                                                  insertInto: context)
            saveToCoreData(object: newUserLocation,
                           values: initialValues,
                           keys: initialKeys)

            self.loadedLocation = CLLocationCoordinate2D(latitude: Double(initialValues.first ?? "0.0")!,
                                                         longitude: Double(initialValues.last ?? "0.0")!)
        }
    }

    private func fetchFromCoreData(keys: [String]) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "UserLocation")
        request.returnsObjectsAsFaults = false
        do {
            let result = try context.fetch(request)
            for data in result as! [NSManagedObject] {
                let firstValue = data.value(forKey: keys.first!) as! String
                let lastValue = data.value(forKey: keys.last!) as! String
                print("Fetched from core data values\nLatitude: "+firstValue+" | Longitude: "+lastValue)
                self.loadedLocation = CLLocationCoordinate2D(latitude: Double(firstValue)!,
                                                             longitude: Double(lastValue)!)
            }
        } catch {
            print("Failed to fetch data")
        }
    }

    private func saveToCoreData(object: NSManagedObject,
                                    values: [String],
                                    keys: [String]) {
        object.setValue(values.first!, forKey: keys.first!)
        object.setValue(values.last!, forKey: keys.last!)

        do {
            try context.save()
            print("Saved successfully to core data")
        } catch {
            print("Failed to save data")
        }
    }

    // MARK: - IBAction methods

    @IBAction func searchButtonTapped() {
        activityIndicator.startAnimating()
        hideKeyboard()
        clearMapAnnotations()
        stopUpdatingLocation()
        if placesList != nil {
            placesList.removeAll()
        }

        let network = NetworkHelper()
        var location: Location?

        if loadedLocation != nil {
            location = Location(longitude: String(describing: loadedLocation!.longitude),
                                    latitude: String(describing: loadedLocation!.latitude))
        } else {
            location = Location(longitude: String(describing: userLocation.coordinate.longitude),
                                    latitude: String(describing: userLocation.coordinate.latitude))
        }

        network.searchPlace(withLocation: location!, query: searchTextField.text ?? "") { (places) in
            let firstTenPlaces = places!.prefix(10)
            self.placesList = [Place]()

            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()

                for place in firstTenPlaces {
                    let listPlace = Place(location: place.location!,
                                          distance: place.distance!,
                                          title: place.title)

                    let annotations = MKPointAnnotation()
                    annotations.title = place.title.removeHTMLTags
                    annotations.subtitle = self.convertToKilometers(meters: place.distance!)
                    annotations.coordinate = CLLocationCoordinate2D(latitude: Double(place.location!.latitude)!,
                                                                    longitude: Double(place.location!.longitude)!)
                    self.mapView.addAnnotation(annotations)
                    self.placesList.append(listPlace)
                }

                self.placesList.sort {
                    $0.distance < $1.distance
                }

                self.listView.reloadData()
            }
        }
    }

    @IBAction func locateButtonTapped() {
        locateUser()
    }

    @IBAction func loadSavedLocationButtonTapped() {
        loadedLocation = nil

        fetchFromCoreData(keys: ["latitude", "longitude"])
        initializeMap()

        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Successfully loaded previous location from core data",
                                          message: "",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK",
                                          style: .default,
                                          handler: nil))
            self.present(alert,
                         animated: true)
        }
    }

    @IBAction func saveCurrentLocationButtonTapped() {
        let newKeys = ["latitude", "longitude"]
        var newValues = [String]()

        if userLocation != nil {
            newValues = ["\(userLocation.coordinate.latitude)", "\(userLocation.coordinate.longitude)"]
        } else {
            newValues = ["\(loadedLocation!.latitude)", "\(loadedLocation!.longitude)"]
        }

        let entity = NSEntityDescription.entity(forEntityName: "UserLocation",
                                                in: context)
        let newUserLocation = NSManagedObject(entity: entity!,
                                              insertInto: context)
        saveToCoreData(object: newUserLocation,
                       values: newValues,
                       keys: newKeys)

        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Successfully saved current location to core data",
                                          message: "",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK",
                                          style: .default,
                                          handler: nil))
            self.present(alert,
                         animated: true)
        }
    }

    @IBAction func segmentedControlSwitched() {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            UIView.transition(from: listView,
                              to: mapView,
                              duration: 0.5,
                              options: [.transitionFlipFromRight, .showHideTransitionViews])
            mapView.isHidden = false
            listView.isHidden = true
        default:
            UIView.transition(from: mapView,
                              to: listView,
                              duration: 0.5,
                              options: [.transitionFlipFromLeft, .showHideTransitionViews])
            listView.isHidden = false
            mapView.isHidden = true
        }
    }

    // MARK: - UITextField delegate methods

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchTextField.resignFirstResponder()

        return true
    }

    // MARK: - UITableView delegate methods

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "Cell")
        if placesList != nil {
            cell.textLabel!.text = placesList[indexPath.row].title.removeHTMLTags
            cell.textLabel?.textColor = .black

            cell.detailTextLabel!.text = self.convertToKilometers(meters: placesList[indexPath.row].distance!)
            cell.detailTextLabel?.textColor = .darkGray
        }

        return cell
    }

    // MARK: - UITableView datasource methods

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }

    // MARK: - CLLocationManagerDelegate methods

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last! as CLLocation

        let center = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude,
                                            longitude: userLocation.coordinate.longitude)
        let region = MKCoordinateRegion(center: center,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))

        self.mapView.setRegion(region,
                               animated: true)
    }
}

private extension MKMapView {
    func centerToLocation(_ location: CLLocationCoordinate2D, regionRadius: CLLocationDistance = 5000) {
        let coordinateRegion = MKCoordinateRegion(center: location,
                                                  latitudinalMeters: regionRadius,
                                                  longitudinalMeters: regionRadius)
        setRegion(coordinateRegion, animated: true)
    }
}

private extension String {
    var removeHTMLTags: String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil).replacingOccurrences(of: "&[^;]+;", with:
    "", options:.regularExpression, range: nil)
    }
}
