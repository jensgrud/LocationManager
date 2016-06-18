//
//  LocationManager.swift
//
//  Created by Jens Grud on 26/05/16.
//  Copyright © 2016 Heaps. All rights reserved.
//

import CoreLocation
import AddressBook

public enum LocationUpdateStatus :String {
    case OK         = "OK"
    case ERROR      = "ERROR"
    case DISTANCE   = "Change in distance too little"
    case TIME       = "Time since last too little"
}

public enum ReverseGeoCodingType {
    case GOOGLE
    case APPLE
}

public typealias LocationCompletionHandler = (latitude:Double, longitude:Double, status:LocationUpdateStatus, error:NSError?) -> Void
public typealias ReverseGeocodeCompletionHandler = (country :String?, state :String?, city :String?, reverseGecodeInfo:AnyObject?, placemark:CLPlacemark?, error:NSError?) -> Void

public typealias LocationCollected = (location :CLLocation, error :NSError?) -> Void

public class LocationManager: NSObject, CLLocationManagerDelegate {
    
    enum GoogleAPIStatus :String {
        case OK             = "OK"
        case ZeroResults    = "ZERO_RESULTS"
        case APILimit       = "OVER_QUERY_LIMIT"
        case RequestDenied  = "REQUEST_DENIED"
        case InvalidRequest = "INVALID_REQUEST"
    }
    
    private var locationCompletionHandlers :[LocationCompletionHandler?] = []
    private var reverseGeocodingCompletionHandler:ReverseGeocodeCompletionHandler?
    
    private var locationManager: CLLocationManager!
    
    private var updateDistanceThreshold :Double!
    private var updateTimeintervalThreshold :Double!
    private var initWithLastKnownLocation = true
    
    private var googleAPIKey :String?
    private var googleAPIResultType :String?

    // Initialize longitude and latitude with last know location
    public lazy var latitude:Double = {
        guard self.initWithLastKnownLocation else {
            return 0.0
        }
        return NSUserDefaults.standardUserDefaults().doubleForKey(self.kLastLocationLatitude)
    }()
    public lazy var longitude:Double = {
        guard self.initWithLastKnownLocation else {
            return 0.0
        }
        return NSUserDefaults.standardUserDefaults().doubleForKey(self.kLastLocationLongitude)
    }()
    
    // Initialize country, state and city with last know location
    public lazy var country:String? = {
        guard self.initWithLastKnownLocation else {
            return nil
        }
        return NSUserDefaults.standardUserDefaults().valueForKey(self.kLastLocationCountry) as? String
    }()
    public lazy var state:String? = {
        guard self.initWithLastKnownLocation else {
            return nil
        }
        return NSUserDefaults.standardUserDefaults().valueForKey(self.kLastLocationState) as? String
    }()
    public lazy var city:String? = {
        guard self.initWithLastKnownLocation else {
            return nil
        }
        return NSUserDefaults.standardUserDefaults().valueForKey(self.kLastLocationCity) as? String
    }()
    
    lazy var googleAPI :String = {
        
        var url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true"
        
        if let resultType = self.googleAPIResultType {
            url = url + "&result_type=\(self.googleAPIResultType)"
        }
        if let apiKey = self.googleAPIKey {
            url = url + "&key=\(self.googleAPIKey)"
        }
        
        return url
    }()
    
    private let kDomain = "com.location-manager"
    
    private let kLastLocationUpdate = "com.location-manager.kLastLocationUpdate"
    private let kLocationUpdated = "com.location-manager.location-updated"
    
    private let kLastLocationLongitude = "com.location-manager.kLastLatitude"
    private let kLastLocationLatitude = "com.location-manager.kLastLongitude"
    private let kLastLocationCity = "com.location-manager.kLastCity"
    private let kLastLocationCountry = "com.location-manager.kLastCountry"
    private let kLastLocationState = "com.location-manager.kLastState"
    
    public static let sharedInstance = LocationManager()
    
    init(locationAccuracy :CLLocationAccuracy = kCLLocationAccuracyBest, updateDistanceThreshold :Double = 0.0, updateTimeintervalThreshold :Double = 0.0, initWithLastKnownLocation :Bool = true, googleAPIKey :String? = nil, googleAPIResultType :String? = nil) {
        
        super.init()
        
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = locationAccuracy
        
        self.googleAPIKey = googleAPIKey
        self.googleAPIResultType = googleAPIResultType
        self.updateDistanceThreshold = updateDistanceThreshold
        self.updateTimeintervalThreshold = updateTimeintervalThreshold
        self.initWithLastKnownLocation = initWithLastKnownLocation
    }
    
    // MARK: - 
    
    public func updateLocation(completionHandler :LocationCompletionHandler) {
        
        self.locationCompletionHandlers.append(completionHandler)
        self.handleLocationStatus(CLLocationManager.authorizationStatus())
    }
    
    public func reverseGeocodeLocation(type :ReverseGeoCodingType = .APPLE, completionHandler :ReverseGeocodeCompletionHandler) {
        
        self.reverseGeocodingCompletionHandler = completionHandler
            
        self.updateLocation({ (latitude, longitude, status, error) in
            
            guard error == nil else {
                return completionHandler(country: "", state: "", city: "", reverseGecodeInfo:nil, placemark:nil, error:error)
            }
            
            switch type {
            case .APPLE:
                self.reverseGeocodeApple()
            case .GOOGLE:
                self.reverseGeocodeGoogle()
            }
        })
    }
    
    private func reverseGeocodeApple() {
        
        let geocoder: CLGeocoder = CLGeocoder()
        let location = CLLocation(latitude: self.latitude, longitude: self.longitude)
        
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            
            guard let completionHandler = self.reverseGeocodingCompletionHandler else {
                return
            }
            
            guard error == nil else {
                return completionHandler(country: "", state: "", city: "", reverseGecodeInfo:nil, placemark:nil, error:error)
            }
            
            guard let placemark = placemarks?.first else {
                
                let error = NSError(domain: "", code: 0, userInfo: nil)
                return completionHandler(country: "", state: "", city: "", reverseGecodeInfo:nil, placemark:nil, error:error)
            }
            
            self.country = placemark.addressDictionary![kABPersonAddressCountryCodeKey] as? String
            self.state = placemark.addressDictionary![kABPersonAddressStateKey] as? String
            self.city = placemark.addressDictionary![kABPersonAddressCityKey] as? String
            
            completionHandler(country: self.country, state: self.state, city: self.city, reverseGecodeInfo:nil, placemark:placemark, error:nil)
        }
    }
 
    private func reverseGeocodeGoogle() {
 
        let url = String(format: googleAPI, arguments: [latitude, longitude])
 
        let request = NSURLRequest(URL: NSURL(string: url)!)
 
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) in
 
            let response = response as? NSHTTPURLResponse
 
            guard let statusCode = response?.statusCode where statusCode == 200 else {
                return
            }
            
            guard let result = try! NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions()) as? [String:AnyObject], status = result["status"] as? String else {
                return
            }
            
            let googleAPIStatus = GoogleAPIStatus(rawValue: status.uppercaseString)!
            
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
                
                NSUserDefaults.standardUserDefaults().setValue(country, forKey: self.kLastLocationCountry)
                NSUserDefaults.standardUserDefaults().setValue(state, forKey: self.kLastLocationState)
                NSUserDefaults.standardUserDefaults().setValue(city, forKey: self.kLastLocationCity)
                
                guard let completionHandler = self.reverseGeocodingCompletionHandler else {
                    return
                }
                
                completionHandler(country: self.country, state: self.state, city: self.city, reverseGecodeInfo:results, placemark:nil, error:nil)
                
            default:
                
                guard let completionHandler = self.reverseGeocodingCompletionHandler else {
                    return
                }
                
                let error = NSError(domain: "", code: 0, userInfo: nil)
                
                completionHandler(country: "", state: "", city: "", reverseGecodeInfo:nil, placemark:nil, error:error)
            }
        }
        
        task.resume()
    }
 
    // MARK: - Location Manager Delegate
 
    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
 
        let location = locations.last
        let timeSinceLastUpdate = location?.timestamp.timeIntervalSinceNow
 
        // Check for cached location and invalid measurement
        guard fabs(timeSinceLastUpdate!) < 5.0 && location?.horizontalAccuracy > 0.0 else {
            return
        }
        
        manager.stopUpdatingLocation()
        
        let currentLocation = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let lastUpdate = NSUserDefaults.standardUserDefaults().objectForKey(kLastLocationUpdate) as? NSDate
        
        guard locationCompletionHandlers.count > 0 else {
            return
        }
        
        while let completionHandler = locationCompletionHandlers.removeFirst() {
            
            let longitude = location?.coordinate.longitude, latitude = location?.coordinate.latitude
            
            // Check for distance since last measurement
            guard currentLocation.distanceFromLocation(location!) > updateDistanceThreshold else {
                return completionHandler(latitude: latitude!, longitude: longitude!, status: .DISTANCE, error: nil)
            }
            
            // Check for time since last measurement
            guard lastUpdate == nil || fabs((lastUpdate?.timeIntervalSinceNow)!) > updateTimeintervalThreshold else {
                return completionHandler(latitude: latitude!, longitude: longitude!, status: .TIME, error: nil)
            }
            
            NSNotificationCenter.defaultCenter().postNotificationName(kLocationUpdated, object: nil)
            
            self.longitude = longitude!
            self.latitude = latitude!
            
            NSUserDefaults.standardUserDefaults().setObject(NSDate(), forKey: kLastLocationUpdate)
            NSUserDefaults.standardUserDefaults().setDouble(self.latitude, forKey: kLastLocationLatitude)
            NSUserDefaults.standardUserDefaults().setDouble(self.longitude, forKey: kLastLocationLongitude)
            
            completionHandler(latitude: self.latitude, longitude: self.longitude, status: .OK, error: nil)
        }
    }
 
    public func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        
        manager.stopUpdatingLocation()
        
        guard locationCompletionHandlers.count > 0 else {
            return
        }
        
        while let completionHandler = locationCompletionHandlers.removeFirst() {
            completionHandler(latitude: latitude, longitude: longitude, status: .ERROR, error: error)
        }
    }
    
    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        self.handleLocationStatus(status)
    }
    
    // MARK: - Utils
    
    private func handleLocationStatus(status :CLAuthorizationStatus) {
        
        switch status {
        case .AuthorizedWhenInUse, .AuthorizedAlways:
            self.locationManager.startUpdatingLocation()
        case .Denied:
            // TODO: Handle denied
            break;
        case .NotDetermined, .Restricted:
            self.locationManager.requestWhenInUseAuthorization()
        }
    }

}
