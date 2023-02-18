# ServerlessPushService


### Load local Certificate from Bundle and setup Service
```
static let sandboxCertificate = ServerlessPushService.Certificate(name: "app_test", password: "secret_password", host: .sandbox)
    
let pushService = ServerlessPushService(certificate: sandboxCertificate)
```

### Error Logging
```
pushService.logError = { error in
    print("APNS Error: \(error)")
}
    
```

### Send Push
```
let payload = ServerlessPushService.Payload(title: "This is push", body: "Body Msg", priority: .immediate, targetToken: "{token}", targetBundleID: "com.company,app")
pushService.push(notification: payload) { error in
    let msg: String
    if let error = error {
        msg = "Push failed: \(error)"
    } else {
        msg = "Push sent successfully"
    }
    
    // Show alert with status
    let alert = UIAlertController(title: "APNS", message: msg, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    self.present(alert, animated: true)
}
```
