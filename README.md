> Location updating and reverse geo coding with completion handlers made easy

## Install
Download manually or install via CocoaPods:
```bash
pod 'LocationManager', :git => 'https://github.com/jensgrud/LocationManager.git'
```

### Setup and usage
Create instance with custom parameters or use the shared
- Google API key
- Update distance threshold
- Update time threshold

```swift
// updation location
locationManager.updateLocation { (latitude, longitude, status, error) in

}

// reverse geo coding using Apple API's
locationManager.reverseGeocodeLocation(completionHandler: { (country, state, city, reverseGecodeInfo, placemark, error) in

}

// reverse geo coding using Google API's
locationManager.reverseGeocodeLocation(.GOOGLE, completionHandler: { (country, state, city, reverseGecodeInfo, placemark, error) in

}
```
