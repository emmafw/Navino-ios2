//
//  ViewController.swift
//  Navino
//
//  Created by Emma Findlay-Walters on 7/10/18.
//
//
//  https://github.com/balitax/Google-Maps-Direction

import UIKit
import GoogleMaps
import GooglePlaces
import SwiftyJSON
import Alamofire
import CoreLocation
import AVFoundation
import Firebase
import GoogleSignIn

class ViewController: UIViewController , GMSMapViewDelegate ,  CLLocationManagerDelegate, GIDSignInUIDelegate{
    
    var locationManager = CLLocationManager()
    
    var inKnownArea = false
    var isMoving = false
    var latCheck = false
    var lngCheck = false
    var overMile = true
    var oneMile = true
    var halfMile = true
    var tenthMile = true
    var distInMeters = 0.0
    
    var currentLocation = CLLocation()
    var endLocation = CLLocation()
    
    var markerHolder = GMSMarker()
    
    var locationStart = CLLocation()
    var locationEnd = CLLocation()
    
    var polyline = GMSPolyline()
    @IBOutlet weak var googleMaps: GMSMapView!
    
    @IBOutlet weak var signInButton: GIDSignInButton!
    
    lazy var drawingPanel:DrawingPanel = {
        var overlayView = DrawingPanel(frame: self.googleMaps.frame)
        overlayView.isUserInteractionEnabled = true
        overlayView.delegate = self
        return overlayView
    }()
    
    var coordinates = [CLLocationCoordinate2D]()
    var latLngs = [CLLocationCoordinate2D]()
    var distanceBetween = [Double]()
    var savedBounds = [GMSCoordinateBounds]()
    var endStepLatLngs = [CLLocationCoordinate2D]()
    var lat1: Double = 0.0
    var lat2: Double = 0.0
    var lng1: Double = 0.0
    var lng2: Double = 0.0
    var endLat: Double = 0.0
    var endLng: Double = 0.0
    
    var regex = try! NSRegularExpression(pattern:"<[^>]+>")
    
    var directions: [String] = []
    
    var synth = AVSpeechSynthesizer()
    
    var i = 1
    
    var ref: DatabaseReference!
    
    var bounds = GMSCoordinateBounds()

    @IBOutlet weak var destinationLocation: UITextField!
    @IBOutlet weak var destinationLocationButton: UIButton!
    @IBOutlet weak var directionsText: UITextView!
    @IBOutlet weak var addKnownAreaButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!
    @IBAction func onSignInButtonClick(_ sender: Any) {
        GIDSignIn.sharedInstance().signIn()
    }
    @IBAction func onAddKnownAreaClick(_ sender: Any) {
        if (addKnownAreaButton.currentTitle == "Add Known Area"){
            drawingPanel  = {
                let overlayView = DrawingPanel(frame: self.googleMaps.frame)
                overlayView.isUserInteractionEnabled = true
                overlayView.delegate = self
                return overlayView
            }()
            self.view.addSubview(drawingPanel)
            addKnownAreaButton.setTitle("Clear", for: .normal)
            signOutButton.setTitle("Save", for: .normal)
        }
        else if (addKnownAreaButton.currentTitle == "Clear"){
            self.googleMaps.clear()
            if (destinationLocation.text != "" && signOutButton.currentTitle != "Go" ){
                markerHolder.map = googleMaps
                signOutButton.setTitle("Find Directions", for: .normal)
            }
            else{
                signOutButton.setTitle("Sign Out", for: .normal)
                destinationLocation.text = ""
            }
            addKnownAreaButton.setTitle("Add Known Area", for: .normal)
            destinationLocationButton.isHidden = false
            destinationLocation.isHidden = false
            directionsText.isHidden = true
            destinationLocation.placeholder = "Search Destination"
            if (signOutButton.isHidden){
                signOutButton.isHidden = false
            }
            directions.removeAll()
            latLngs.removeAll()
            distanceBetween.removeAll()
            endStepLatLngs.removeAll()
            isMoving = false
            i = 1
        }
    }
    
    @IBAction func onSignOutButtonClick(_ sender: Any) {
        if (signOutButton.currentTitle == "Sign Out"){
            do {
            try! Auth.auth().signOut()
            signInButton.isHidden = false
            addKnownAreaButton.isEnabled = false
            destinationLocation.isEnabled = false
            destinationLocationButton.isEnabled = false
            googleMaps.isUserInteractionEnabled = false
            } catch{
                print("Error signing out!")
            }
        }
        else if (signOutButton.currentTitle == "Find Directions"){
            currentLocation = (locationManager.location)!
            endLocation = CLLocation.init(latitude: markerHolder.position.latitude, longitude: markerHolder.position.longitude)
            drawPath(startLocation: currentLocation, endLocation: endLocation)
            signOutButton.setTitle("Go", for: .normal)
            addKnownAreaButton.setTitle("Clear", for:.normal)
            getKnownAreas()
        }
        else if (signOutButton.currentTitle == "Go") {
            currentLocation = locationManager.location!
            for j in 0..<savedBounds.count {
                let coor = savedBounds[j]
                if (coor.contains(currentLocation.coordinate)){
                    inKnownArea = true
                }
                else{
                    inKnownArea = false
                }
            }
            let utterance = AVSpeechUtterance(string: "Starting Directions")
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.5
            synth.speak(utterance)
            let dir = directions[0]
            directionsText.text = dir
            if (inKnownArea) {
                let utterance = AVSpeechUtterance(string: "Muting directions until out of known area")
                utterance.rate = 0.5
                synth.speak(utterance)
            }
            else {
                let dir1 = AVSpeechUtterance(string: dir)
                dir1.voice = AVSpeechSynthesisVoice(language: "en-US")
                dir1.rate = 0.5
                synth.speak(dir1)
            }
            
            signOutButton.isHidden = true
            destinationLocation.isHidden = true
            destinationLocationButton.isHidden = true
            directionsText.isHidden = false
            var topCorrect = (directionsText.bounds.size.height * directionsText.zoomScale) / 3
            topCorrect = topCorrect < 0.0 ? 0.0 : topCorrect
            directionsText.contentInset.top = topCorrect
            directionsText.font = UIFont(name: (directionsText.font?.fontName)!, size: 18)
            directionsText.textAlignment = NSTextAlignment.center
            addKnownAreaButton.frame.size = CGSize(width: addKnownAreaButton.frame.width * 2.2, height: addKnownAreaButton.frame.height)
            isMoving = true
            locationManager.startMonitoringSignificantLocationChanges()
        }
        else if (signOutButton.currentTitle == "Save"){
            
            let knownArea = [
                "nLat": bounds.northEast.latitude,
                "nLon": bounds.northEast.longitude,
                "sLat": bounds.southWest.latitude,
                "sLon": bounds.southWest.longitude
            ]
            self.ref.child((Auth.auth().currentUser?.uid)!).childByAutoId().setValue(knownArea)
            googleMaps.clear()
            if(destinationLocation.text != ""){
                markerHolder.map = googleMaps
                addKnownAreaButton.setTitle("Add Known Area", for: .normal)
                signOutButton.setTitle("Find Directions", for: .normal)
            }
            else{
                addKnownAreaButton.setTitle("Add Known Area", for: .normal)
                signOutButton.setTitle("Sign Out", for: .normal)
            }
        }
    }
   
    override func viewDidLoad() {
        super.viewDidLoad()
        GIDSignIn.sharedInstance().uiDelegate = self
        ref = Database.database().reference()
        if(Auth.auth().currentUser == nil){
            signInButton.isHidden = false
            GIDSignIn.sharedInstance().signIn()
        }
        else{
            signInButton.isHidden = true
        }
        directionsText.isHidden = true
        
        self.locationManager.requestAlwaysAuthorization()
        
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
        self.googleMaps.delegate = self
        self.googleMaps.isMyLocationEnabled = true
        self.googleMaps.settings.myLocationButton = true
        let paddingValues = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 50.00, right: 0.0)
        self.googleMaps.padding = paddingValues
        self.googleMaps.settings.compassButton = true
        self.googleMaps.settings.zoomGestures = true
        let camera = GMSCameraPosition(target: (locationManager.location?.coordinate)!, zoom: 15, bearing: 0, viewingAngle: 0)
        self.googleMaps.animate(to: camera)
        
    }
    
    func getKnownAreas(){
        let userID = Auth.auth().currentUser?.uid
        ref.child(userID!).observeSingleEvent(of: .value, with: {(snapshot) in
            let results = snapshot.value as? NSDictionary
            let enumerator = snapshot.children
            while let rest = enumerator.nextObject() as? DataSnapshot {
                let child = rest.value as? NSDictionary
                let nLat = child!["nLat"] as! Double
                let nLon = child!["nLon"] as! Double
                let sLat = child!["sLat"] as! Double
                let sLon = child!["sLon"] as! Double
                self.savedBounds.append(GMSCoordinateBounds(coordinate: CLLocationCoordinate2D(latitude: nLat, longitude: nLon), coordinate: CLLocationCoordinate2D(latitude: sLat, longitude: sLon)))
            }
        }) {(error) in
            print(error.localizedDescription)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if(Auth.auth().currentUser != nil && !signInButton.isHidden){
            signInButton.isHidden = true
        }
        if(isMoving && i<latLngs.count){
            currentLocation = locationManager.location!
            let camera = GMSCameraPosition(target: (currentLocation.coordinate), zoom: 18, bearing: 0, viewingAngle: 0)
            self.googleMaps.animate(to: camera)
            for j in 0..<savedBounds.count {
                let coor = savedBounds[j]
                if (coor.contains(currentLocation.coordinate)){
                    inKnownArea = true
                }
                else{
                    inKnownArea = false
                }
            }
            latCheck = false
            lngCheck = false
            let nextLoc = latLngs[i]
            if (distanceBetween[i]<=400){
                lat1 = nextLoc.latitude - 0.09
                lat2 = nextLoc.latitude + 0.09
                lng1 = nextLoc.longitude - 0.09
                lng2 = nextLoc.longitude + 0.09
            }
            else{
                lat1 = nextLoc.latitude - 0.001
                lat2 = nextLoc.latitude + 0.001
                lng1 = nextLoc.longitude - 0.001
                lng2 = nextLoc.longitude + 0.001
            }
            var dir = directions[i]
            if (dir.contains("Destination")){
                var dist = 0.0
                if(distanceBetween[i]<=400){
                    dist = (distanceBetween[i] * 3.28)
                    dir = dir.replacingOccurrences(of: "Destination", with: " In "+String(format:"%.0f", dist)+" ft destination")
                }
                else{
                    let dist = (distanceBetween[i] / 1609)
                    dir = dir.replacingOccurrences(of: "Destination", with: " In "+String(format:"%.1f", dist)+" miles destination")
                }
            }
            if (distanceBetween[i-1] > 0){
                let currentDistance = [currentLocation .distance(from: CLLocation(latitude: endStepLatLngs[i-1].latitude, longitude: endStepLatLngs[i-1].longitude))]
                let curDist = Double(round(currentDistance.first!/1609*10)/10)
                var x = ""
                if (curDist >= 0.2){
                    x = "In " + String(curDist) + " miles, " + dir
                }
                else {
                    x = dir
                }
                if (x != directionsText.text){
                    directionsText.text = x
                }
                if (curDist >= 1.1 && overMile){
                    let string = AVSpeechUtterance(string: x)
                    string.voice = AVSpeechSynthesisVoice(language: "en-US")
                    string.rate = 0.5
                    if(!inKnownArea){
                        synth.speak(string)
                    }
                    overMile = false
                }
                if (curDist == 1.0 && oneMile){
                    let string = AVSpeechUtterance(string: x)
                    string.voice = AVSpeechSynthesisVoice(language: "en-US")
                    string.rate = 0.5
                    if(!inKnownArea){
                        synth.speak(string)
                    }
                    oneMile = false
                }
                if (curDist == 0.5 && halfMile){
                    let string = AVSpeechUtterance(string: x)
                    string.voice = AVSpeechSynthesisVoice(language: "en-US")
                    string.rate = 0.5
                    if(!inKnownArea){
                        synth.speak(string)
                    }
                    halfMile = false
                }
            }
            if (currentLocation.coordinate.latitude >= lat1 && currentLocation.coordinate.latitude <= lat2){
                latCheck = true
            }
            if (currentLocation.coordinate.longitude >= lng1 && currentLocation.coordinate.longitude <= lng2){
                lngCheck = true
            }
            if (latCheck && lngCheck){
                let directionString = AVSpeechUtterance(string: dir)
                directionString.voice = AVSpeechSynthesisVoice(language: "en-US")
                directionString.rate = 0.5
                if(!inKnownArea){
                    synth.speak(directionString)
                }
                i = i + 1
                overMile = true
                oneMile = true
                halfMile = true
                tenthMile = true
            }
            if (i == latLngs.count){
                currentLocation = locationManager.location!
                let camera = GMSCameraPosition(target: (currentLocation.coordinate), zoom: 18, bearing: 0, viewingAngle: 0)
                self.googleMaps.animate(to: camera)
                var endLatCheck = false
                var endLngCheck = false
                let endLatLow = endLat - 0.001
                let endLatHigh = endLat + 0.001
                let endLngLow = endLng - 0.001
                let endLngHigh = endLng + 0.001
                
                if(endLatLow<=currentLocation.coordinate.latitude && currentLocation.coordinate.latitude<=endLatHigh){
                    endLatCheck = true
                }
                if(endLngLow<=currentLocation.coordinate.longitude && currentLocation.coordinate.longitude<=endLngHigh){
                    endLngCheck = true
                }
                if(endLatCheck && endLngCheck){
                    let endString = AVSpeechUtterance(string: "Arrived at destination")
                    endString.voice = AVSpeechSynthesisVoice(language: "en-US")
                    endString.rate = 0.5
                    synth.speak(endString)
                    googleMaps.clear()
                    directionsText.isHidden = true
                    destinationLocationButton.isHidden = false
                    destinationLocation.isHidden = false
                    destinationLocation.text = ""
                    addKnownAreaButton.frame.size = CGSize(width: addKnownAreaButton.frame.width / 2.2, height: addKnownAreaButton.frame.height)
                    addKnownAreaButton.setTitle("Add Known Area", for: .normal)
                    signOutButton.isHidden = false
                    signOutButton.setTitle("Sign Out", for: .normal)
                    isMoving = false
                    i = 1
                    directions.removeAll()
                    latLngs.removeAll()
                    endStepLatLngs.removeAll()
                }
            }
        }
    }
    
    @IBAction func openDestinationLocation(_ sender: UIButton) {
        
        let autoCompleteController = GMSAutocompleteViewController()
        autoCompleteController.delegate = self
        
        self.present(autoCompleteController, animated: true, completion: nil)
    }
    
}

extension ViewController: GMSAutocompleteViewControllerDelegate {
    
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        print("Error \(error)")
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        
        let camera = GMSCameraPosition.camera(withLatitude: place.coordinate.latitude, longitude: place.coordinate.longitude, zoom: 16.0)

        googleMaps.clear()
        locationEnd = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude))
        marker.map = googleMaps
        markerHolder = marker
        signOutButton.setTitle("Find Directions", for: .normal)
        destinationLocation.text = place.name
        
        self.googleMaps.camera = camera
        self.dismiss(animated: true, completion: nil)
        
    }
    
    func drawPath(startLocation: CLLocation, endLocation: CLLocation)
    {
        let origin = "\(startLocation.coordinate.latitude),\(startLocation.coordinate.longitude)"
        let destination = "\(endLocation.coordinate.latitude),\(endLocation.coordinate.longitude)"
        let cameraPos = GMSCameraPosition(target: startLocation.coordinate, zoom: 15, bearing: 0, viewingAngle: 0)
        self.googleMaps.animate(to: cameraPos)
    
    
        let url = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin)&destination=\(destination)&mode=driving"
    
        Alamofire.request(url).responseData { response -> Void in
            let json = try? JSON(data: response.data!)
            let routes = json!["routes"].arrayValue
            
            for route in routes{
                let routePolyline = route["overview_polyline"].dictionary
                let points = routePolyline?["points"]?.stringValue
                let path = GMSPath.init(fromEncodedPath: points!)
                self.polyline = GMSPolyline.init(path: path)
                self.polyline.strokeWidth = 4
                self.polyline.strokeColor = UIColor.blue
                self.polyline.map = self.googleMaps
                let Legs = route["legs"].arrayValue
                for leg in Legs{
                    let endLoc = leg["end_location"]
                    self.endLat = endLoc["lat"].doubleValue
                    self.endLng = endLoc["lng"].doubleValue
                    let Steps = leg["steps"].arrayValue
                    for step in Steps{
                        
                        let startLocation = step["start_location"]
                        let lat = startLocation["lat"].doubleValue
                        let lng = startLocation["lng"].doubleValue
                        let end_location = step["end_location"]
                        let endStepLat = end_location["lat"].doubleValue
                        let endStepLng = end_location["lng"].doubleValue
                        let distance = step["distance"]
                        var dist = distance["text"].stringValue
                        if dist.contains("mi"){
                            dist = dist.replacingOccurrences(of: "mi", with: "")
                            dist = dist.replacingOccurrences(of: " ", with: "")
                            self.distInMeters = Double(dist)! * 1609
                        }
                        else if dist.contains("ft"){
                            dist = dist.replacingOccurrences(of: "ft", with: "")
                            dist = dist.replacingOccurrences(of: " ", with: "")
                            self.distInMeters = (Double(dist)! * 0.3048)
                        }
                        var direct = step["html_instructions"].stringValue
                        let range = NSMakeRange(0, direct.count)
                        direct = self.regex.stringByReplacingMatches(in: direct, options: [], range: range, withTemplate: "")
                        self.directions.append(direct)
                        self.latLngs.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                        self.endStepLatLngs.append(CLLocationCoordinate2D(latitude: endStepLat, longitude: endStepLng))
                        self.distanceBetween.append(self.distInMeters)
                    }
                }
            }
        }
    }
    
   
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
    func createPolygon(){
        let numPoints = self.coordinates.count
        if numPoints>2{
            addPolygon(drawableLoc: coordinates)
        }
        coordinates=[]
        self.drawingPanel.image = nil
        self.drawingPanel.removeFromSuperview()
    }
    
    func addPolygon(drawableLoc: [CLLocationCoordinate2D]){
        let path = GMSMutablePath()
        for loc in drawableLoc{
            path.add(loc)
            bounds = bounds.includingCoordinate(loc)
        }
        let newPoly = GMSPolygon(path: path)
        newPoly.strokeWidth = 3
        newPoly.strokeColor = UIColor.blue
        newPoly.map = googleMaps
    }
    
}

extension ViewController:NotifyTouchEvents{
    func touchBegan(touch:UITouch) {
        let location = touch.location(in: self.googleMaps)
        let coordinate = self.googleMaps.projection.coordinate(for: location)
        self.coordinates.append(coordinate)
    }
    
    func touchMoved(touch:UITouch) {
        let location = touch.location(in: self.googleMaps)
        let coordinate = self.googleMaps.projection.coordinate(for: location)
        self.coordinates.append(coordinate)
    }
    
    func touchEnded(touch:UITouch){
        let location = touch.location(in: self.googleMaps)
        let coordinate = self.googleMaps.projection.coordinate(for: location)
        self.coordinates.append(coordinate)
        createPolygon()
    }
}


