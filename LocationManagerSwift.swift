//
//  LocationManager.swift
//
//  Created by Jens Grud on 26/05/16.
//  Copyright © 2016 Heaps. All rights reserved.
//

import CoreLocation
import Contacts

public enum ReverseGeoCodingType {
    case GOOGLE
    case APPLE
}

public typealias ReverseGeocodeCompletionHandler = (_ country :String?, _ state :String?, _ city :String?, _ reverseGecodeInfo :AnyObject?, _ placemark :CLPlacemark?, _ error :Error?) -> Void

public typealias LocationAuthorizationChanged = (_ manager :CLLocationManager, _ status :CLAuthorizationStatus) -> Void

public class LocationManagerSwift: NSObject {
    
    enum GoogleAPIStatus :String {
        case OK             = "OK"
        case ZeroResults    = "ZERO_RESULTS"
        case APILimit       = "OVER_QUERY_LIMIT"
        case RequestDenied  = "REQUEST_DENIED"
        case InvalidRequest = "INVALID_REQUEST"
    }
    
    private var reverseGeocodingCompletionHandler:ReverseGeocodeCompletionHandler?
    private var authorizationChangedCompletionHandler:LocationAuthorizationChanged?
    
    private lazy var locationManager = CLLocationManager()
    
    private var updateTimeintervalThreshold :Double!
    private var desiredLocationAccuracy :CLLocationAccuracy!
    private var initWithLastKnownLocation = true
    
    private var googleAPIKey :String?
    private var googleAPIResultType :String?
    
    private let operations = OperationQueue()

    // Initialize longitude and latitude with last know location
    public lazy var latitude :Double = {
        guard self.initWithLastKnownLocation else {
            return 0.0
        }
        return UserDefaults.standard.double(forKey: self.kLastLocationLatitude)
    }()
    public lazy var longitude :Double = {
        guard self.initWithLastKnownLocation else {
            return 0.0
        }
        return UserDefaults.standard.double(forKey: self.kLastLocationLongitude)
    }()
    
    // Initialize country, state and city with last know location
    public lazy var country :String? = {
        guard self.initWithLastKnownLocation else {
            return nil
        }
        return UserDefaults.standard.value(forKey: self.kLastLocationCountry) as? String
    }()
    public lazy var state :String? = {
        guard self.initWithLastKnownLocation else {
            return nil
        }
        return UserDefaults.standard.value(forKey: self.kLastLocationState) as? String
    }()
    public lazy var city :String? = {
        guard self.initWithLastKnownLocation else {
            return nil
        }
        return UserDefaults.standard.value(forKey: self.kLastLocationCity) as? String
    }()
    
    lazy var googleAPI :String = {
        
        var url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true"
        
        if let resultType = self.googleAPIResultType {
            url = url + "&result_type=\(String(describing: self.googleAPIResultType))"
        }
        if let apiKey = self.googleAPIKey {
            url = url + "&key=\(String(describing: self.googleAPIKey))"
        }
        
        return url
    }()
    
    private let kDomain = "com.location-manager"
    
    fileprivate let kLastLocationUpdate = "com.location-manager.kLastLocationUpdate"
    fileprivate let kLocationUpdated = "com.location-manager.location-updated"
    fileprivate let kLastLocationLongitude = "com.location-manager.kLastLatitude"
    fileprivate let kLastLocationLatitude = "com.location-manager.kLastLongitude"
    
    private let kLastLocationCity = "com.location-manager.kLastCity"
    private let kLastLocationCountry = "com.location-manager.kLastCountry"
    private let kLastLocationState = "com.location-manager.kLastState"
    
    public static let shared = LocationManagerSwift()
    
    public init(locationAccuracy :CLLocationAccuracy = kCLLocationAccuracyBest, updateTimeintervalThreshold :Double = 0.0, initWithLastKnownLocation :Bool = true, googleAPIKey :String? = nil, googleAPIResultType :String? = nil) {
        
        super.init()
        
        self.googleAPIKey = googleAPIKey
        self.googleAPIResultType = googleAPIResultType
        self.updateTimeintervalThreshold = updateTimeintervalThreshold
        self.desiredLocationAccuracy = locationAccuracy
        self.initWithLastKnownLocation = initWithLastKnownLocation
    }
    
    // MARK: - Location update
    
    public func updateLocation(completionHandler :@escaping LocationUpdateCompletionHandler) {
        
        let lastUpdate = UserDefaults.standard.object(forKey: kLastLocationUpdate) as? NSDate
        
        guard lastUpdate == nil || fabs((lastUpdate?.timeIntervalSinceNow)!) > updateTimeintervalThreshold else {
            return completionHandler(self.latitude, self.longitude, .TIME, nil)
        }
        
        let operation = LocationUpdateOperation()
        operation.delegate = self
        operation.locationCompletionHandler = completionHandler
        
        operations.addOperation(operation)
        operation.requestLocation(accuracy: self.desiredLocationAccuracy)
    }
    
    // MARK: - Region monitoring
    
    public func monitorRegion(latitude :CLLocationDegrees, longitude :CLLocationDegrees, radius :CLLocationDistance = 100.0, notifyOnExit :Bool = true, notifyOnEntry :Bool = false, completion :@escaping RegionMonitoringCompletionHandler) {
        
        let operation = RegionMonitoringOperation()
        operation.delegate = self
        operation.regionCompletionHandler = completion
        
        operations.addOperation(operation)
        operation.startRegionMonitoring(latitude: latitude, longitude: longitude, radius: radius, notifyOnExit: notifyOnExit, notifyOnEntry: notifyOnEntry)
    }
    
    // MARK: - Reverse geocoding
    
    public func reverseGeocodeLocation(type :ReverseGeoCodingType = .APPLE, completionHandler :@escaping ReverseGeocodeCompletionHandler) {
        
        self.reverseGeocodingCompletionHandler = completionHandler
            
        self.updateLocation { (latitude, longitude, status, error) in
            
            guard error == nil else {
                return completionHandler("", "", "", nil, nil, error)
            }
            
            switch type {
            case .APPLE:
                self.reverseGeocodeApple()
            case .GOOGLE:
                self.reverseGeocodeGoogle()
            }
        }
    }
    
    private func reverseGeocodeApple() {
        
        let geocoder: CLGeocoder = CLGeocoder()
        let location = CLLocation(latitude: self.latitude, longitude: self.longitude)
        
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            
            guard let completionHandler = self.reverseGeocodingCompletionHandler else {
                return
            }
            
            guard error == nil else {
                return completionHandler("", "", "", nil, nil, error)
            }
            
            guard let placemark = placemarks?.first, let addressDictionary = placemark.addressDictionary else {
                
                let error = NSError(domain: "", code: 0, userInfo: nil)
                return completionHandler("", "", "", nil, nil, error)
            }
            
            self.country = addressDictionary["CountryCode"] as? String
            self.state = addressDictionary["State"] as? String
            self.city = addressDictionary["City"] as? String
            
            completionHandler(self.country, self.state, self.city, nil, placemark, nil)
        }
    }
 
    private func reverseGeocodeGoogle() {
 
        let url = String(format: googleAPI, arguments: [latitude, longitude])
 
        let request = URLRequest(url: URL(string: url)!)
 
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
 
            let response = response as? HTTPURLResponse
 
            guard let statusCode = response?.statusCode, statusCode == 200 else {
                return
            }
            
            guard let result = try! JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as? [String:AnyObject], let status = result["status"] as? String else {
                return
            }
            
            guard let googleAPIStatus = GoogleAPIStatus(rawValue: status.uppercased()) else {
                return
            }
            
            switch googleAPIStatus {
            case .OK:
                
                guard let results = result["results"] as? [NSDictionary] else {
                    return
                }
                
                var city, state, country :String?
                
                for result in results {
                    
                    guard let components = result["address_components"] as? [NSDictionary] else {
                        break
                    }
                    
                    for component in components {
                        
                        // TODO: Check that info is set and break?
                        
                        guard let types = component["types"] as? [String] else {
                            continue
                        }
                        
                        let longName = component["long_name"] as? String
                        let shortName = component["short_name"] as? String
                        
                        if types.contains("country") {
                            country = shortName
                        }
                        else if types.contains("administrative_area_level_1") {
                            state = shortName
                        }
                        else if types.contains("administrative_area_level_2") {
                            city = longName
                        }
                        else if types.contains("locality") {
                            city = longName
                        }
                    }
                }
                
                self.country = country
                self.state = state
                self.city = city
                
                UserDefaults.standard.setValue(country, forKey: self.kLastLocationCountry)
                UserDefaults.standard.setValue(state, forKey: self.kLastLocationState)
                UserDefaults.standard.setValue(city, forKey: self.kLastLocationCity)
                
                guard let completionHandler = self.reverseGeocodingCompletionHandler else {
                    return
                }
                
                completionHandler(self.country, self.state, self.city, results as AnyObject?, nil, nil)
                
            default:
                
                guard let completionHandler = self.reverseGeocodingCompletionHandler else {
                    return
                }
                
                let error = NSError(domain: "", code: 0, userInfo: nil)
                
                completionHandler("", "", "", nil, nil, error)
            }
        }
        
        task.resume()
    }
    
    // MARK: - Utils
    
    public func getLocation() -> CLLocation {
        return CLLocation(latitude: self.latitude, longitude: self.longitude)
    }
    
    public func requestAuthorization(status :CLAuthorizationStatus, callback: LocationAuthorizationChanged? = nil) {
        
        self.authorizationChangedCompletionHandler = callback
        
        switch status {
        case .authorizedAlways:
            self.locationManager.requestAlwaysAuthorization()
        default:
            self.locationManager.requestWhenInUseAuthorization()
        }
    }
}

extension LocationManagerSwift : LocationOperationDelegate {
    
    func operationDidStart(operation :LocationOperation) {
        
    }
    
    func operationDidFinish(operation: LocationOperation, status: LocationOperationStatus, error: NSError?) {
        
    }
}

extension LocationManagerSwift : LocationUpdateDelegate {
    
    func operationDidUpdateLocation(operation :LocationOperation, location: CLLocation) {
        
        self.longitude = location.coordinate.longitude
        self.latitude = location.coordinate.latitude
        
        UserDefaults.standard.set(NSDate(), forKey: kLastLocationUpdate)
        UserDefaults.standard.set(self.latitude, forKey: kLastLocationLatitude)
        UserDefaults.standard.set(self.longitude, forKey: kLastLocationLongitude)
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kLocationUpdated), object: nil)
    }
}

extension LocationManagerSwift : RegionMonitoringDelegate {
    
    func operationDidEnterRegion(operation :LocationOperation, region: CLRegion) {
        
    }
    
    func operationDidExitRegion(operation :LocationOperation, region: CLRegion) {
        
    }
}

// MARK: Location operation

public enum LocationOperationStatus :String {
    case OK                         = "OK"
    case TIME                       = "TIME"
    case DISTANCE                   = "DISTANCE"
    case ERROR                      = "ERROR"
    case MISSING_AUTHORIZATION      = "MISSING AUTHORIZATION"
    case LOCATION_SERVICE_DISABLED  = "LOCATION SERVICE DISABLED"
}

public typealias LocationUpdateCompletionHandler = (_ latitude :Double, _ longitude :Double, _ status :LocationOperationStatus, _ error :NSError?) -> Void
public typealias RegionMonitoringCompletionHandler = (_ region :CLRegion?, _ status :LocationOperationStatus, _ error :NSError?) -> Void

class LocationOperation: Operation, CLLocationManagerDelegate
{
    lazy var locationManager = CLLocationManager()
    
    private var _executing : Bool = false
    private var _finished: Bool = false
    
    override var isExecuting : Bool {
        get { return _executing }
        set {
            guard _executing != newValue else { return }
            willChangeValue(forKey: "isExecuting")
            _executing = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override var isFinished: Bool {
        get { return _finished }
        set {
            guard _finished != newValue else { return }
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
}

protocol LocationOperationDelegate
{
    func operationDidStart(operation :LocationOperation)
    
    func operationDidFinish(operation :LocationOperation, status :LocationOperationStatus, error :NSError?)
}

protocol LocationUpdateDelegate : LocationOperationDelegate
{
    func operationDidUpdateLocation(operation :LocationOperation, location: CLLocation)
}

protocol RegionMonitoringDelegate : LocationOperationDelegate
{
    func operationDidEnterRegion(operation :LocationOperation, region: CLRegion)
    
    func operationDidExitRegion(operation :LocationOperation, region: CLRegion)
}

final class LocationUpdateOperation: LocationOperation
{
    var delegate: LocationUpdateDelegate?
    var locationCompletionHandler :LocationUpdateCompletionHandler?
    var currentLocation :CLLocation?
    
    fileprivate var updateDistanceThreshold :Double!
    
    func requestLocation(status :CLAuthorizationStatus = .authorizedWhenInUse, accuracy :CLLocationAccuracy = kCLLocationAccuracyBest, updateDistanceThreshold :Double = 10.0) {
        
        self.updateDistanceThreshold = updateDistanceThreshold
        
        guard CLLocationManager.locationServicesEnabled() else {
            stopUpdatingLocation(status: .LOCATION_SERVICE_DISABLED, error: NSError(domain: "", code: 501, userInfo: [NSLocalizedDescriptionKey:LocationOperationStatus.LOCATION_SERVICE_DISABLED.rawValue]))
            return
        }
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = accuracy
        
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdatingLocation()
        case .denied, .restricted:
            stopUpdatingLocation(status: .MISSING_AUTHORIZATION, error: NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey:LocationOperationStatus.MISSING_AUTHORIZATION.rawValue]))
        case .notDetermined:
            if status == .authorizedAlways {
                locationManager.requestAlwaysAuthorization()
            }
            else {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    func startUpdatingLocation() {
        
        locationManager.startUpdatingLocation()
        delegate?.operationDidStart(operation: self)
    }
    
    func stopUpdatingLocation(latitude: Double = 0.0, longitude: Double = 0.0, status :LocationOperationStatus, error :NSError? = nil) {
        
        locationManager.stopUpdatingLocation()
        
        if let locationCompletionHandler = locationCompletionHandler {
            locationCompletionHandler(latitude, longitude, status, error)
        }
        
        currentLocation = CLLocation(latitude: latitude, longitude: longitude)
        
        delegate?.operationDidFinish(operation: self, status: status, error: error)
        
        self.isExecuting = false
        self.isFinished = true
    }
}

extension LocationUpdateOperation
{
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdatingLocation()
        case .denied, .restricted:
            stopUpdatingLocation(status: .MISSING_AUTHORIZATION, error: NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey:LocationOperationStatus.MISSING_AUTHORIZATION.rawValue]))
        case .notDetermined:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        stopUpdatingLocation(status: .ERROR, error: error as NSError?)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let location = locations.last else {
            return
        }
        
        let timeSinceLastUpdate = location.timestamp.timeIntervalSinceNow
        
        // Check for cached location and invalid measurement
        guard fabs(timeSinceLastUpdate) < 5.0 && location.horizontalAccuracy > 0.0 else {
            return
        }

        // Check for significant location change
        if let currentLocation = currentLocation, location.distance(from: currentLocation) < updateDistanceThreshold {
            return
        }
        
        delegate?.operationDidUpdateLocation(operation: self, location: location)
        
        stopUpdatingLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, status: .OK, error: nil)
    }
}

// MARK: Region monitoring

final class RegionMonitoringOperation: LocationOperation
{
    var delegate: RegionMonitoringDelegate?
    var regionCompletionHandler :RegionMonitoringCompletionHandler?
    
    func startRegionMonitoring(latitude :CLLocationDegrees, longitude :CLLocationDegrees, radius :CLLocationDistance = 100.0, notifyOnExit :Bool = true, notifyOnEntry :Bool = false) {
        
        guard CLLocationManager.locationServicesEnabled() else {
            stopRegionMonitoring(status: .LOCATION_SERVICE_DISABLED, error: NSError(domain: "", code: 501, userInfo: [NSLocalizedDescriptionKey:LocationOperationStatus.LOCATION_SERVICE_DISABLED.rawValue]))
            return
        }
        
        guard CLLocationManager.authorizationStatus() == .authorizedAlways else {
            stopRegionMonitoring(status: .MISSING_AUTHORIZATION, error: NSError(domain: "", code: 501, userInfo: [NSLocalizedDescriptionKey:LocationOperationStatus.MISSING_AUTHORIZATION.rawValue]))
            return
        }
        
        guard radius < self.locationManager.maximumRegionMonitoringDistance else {
            stopRegionMonitoring(status: .DISTANCE, error: NSError(domain: "", code: 501, userInfo: [NSLocalizedDescriptionKey:LocationOperationStatus.DISTANCE.rawValue]))
            return
        }
        
        locationManager.delegate = self
        
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let identifier = "\(longitude)\(latitude)\(radius)"
        
        let region = CLCircularRegion(center: location, radius: radius, identifier: identifier)
        region.notifyOnExit = notifyOnExit
        region.notifyOnEntry = notifyOnEntry
        
        self.locationManager.startMonitoring(for: region)
    }
    
    func stopRegionMonitoring(region :CLRegion? = nil, status :LocationOperationStatus, error :NSError? = nil) {
        
        if let regionCompletionHandler = regionCompletionHandler {
            regionCompletionHandler(region, status, error)
        }
        
        delegate?.operationDidFinish(operation: self, status: status, error: error)
        
        self.isExecuting = false
        self.isFinished = true
        
        guard let region = region else {
            return
        }
        
        locationManager.stopMonitoring(for: region)
    }
}

extension RegionMonitoringOperation
{
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        stopRegionMonitoring(region: region, status: .OK)
        delegate?.operationDidEnterRegion(operation: self, region: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        stopRegionMonitoring(region: region, status: .OK)
        delegate?.operationDidExitRegion(operation: self, region: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        delegate?.operationDidStart(operation: self)
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        stopRegionMonitoring(region: region, status: .ERROR, error: error as NSError?)
    }
}
