> CLLocationManager wrapper in Swift for easy location update, reverse geocoding and region monitoring with closure and delegate support

## Swift 3 compatible
Download manually or install via CocoaPods:
```bash
pod 'LocationManagerSwift', '~> 1.1'
```

### Usage

```swift
// updation location
LocationManagerSwift.shared.updateLocation { (latitude, longitude, status, error) in
                
}

// reverse geo coding using Apple or Google API's
LocationManagerSwift.shared.reverseGeocodeLocation(.APPLE) { (country, state, city, reverseGecodeInfo, placemark, error) in
                
}

// region monitoring
LocationManagerSwift.shared.monitorRegion(latitude: latitude, longitude: longitude, radius: 100.0, notifyOnExit: true, notifyOnEntry: true) { (region, status, error) in

}
```

### Looking for Swift 2.3?

```bash
pod 'LocationManagerSwift', '~> 1.0.4'
```

```swift
// updation location
LocationManagerSwift.sharedInstance.updateLocation { (latitude, longitude, status, error) in
                
}

// reverse geo coding using Apple or Google API's
LocationManagerSwift.sharedInstance.reverseGeocodeLocation(.APPLE) { (country, state, city, reverseGecodeInfo, placemark, error) in
                
}

// region monitoring
LocationManagerSwift.sharedInstance.monitorRegion(lat, longitude: lon, radius: radius, notifyOnExit: true, notifyOnEntry: false) { (region, status, error) in

}
```
