> CLLocationManager wrapper in Swift for easy location update, reverse geocoding and region monitoring with closure and delegate support

## Install
Download manually or install via CocoaPods:
```bash
pod 'LocationManagerSwift', '~> 1.0.1'
```

### Setup and usage

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
