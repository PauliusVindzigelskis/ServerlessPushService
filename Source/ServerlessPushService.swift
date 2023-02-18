//
//  ServerlessPushService.swift
//
//  Created by Paulius Vindzigelskis on 11/7/22.
//

import Foundation

public class ServerlessPushService: NSObject {
    
    public enum Priority: Int {
        case low = 1
        case medium = 5
        case immediate = 10
    }
    
    public struct Certificate {
        public let name: String
        public let password: String
        public let host: Host
        
        public init(name: String, password: String, host: Host) {
            self.name = name
            self.password = password
            self.host = host
        }
    }
    
    
    public enum Host {
        case sandbox
        case production
        
        var urlPath: String {
            switch (self) {
            case .sandbox: return "https://api.development.push.apple.com"
            case .production: return "https://api.push.apple.com"
            }
        }
    }
    

    public struct Payload {
        public var title: String
        public var subtitle: String?
        public var body: String
        public var badge: Int?
        public var priority: Priority
        
        public var targetToken: String
        public var targetBundleID: String
        
        public init(title: String, subtitle: String? = nil, body: String, badge: Int? = nil, priority: Priority, targetToken: String, targetBundleID: String) {
            self.title = title
            self.subtitle = subtitle
            self.body = body
            self.badge = badge
            self.priority = priority
            self.targetToken = targetToken
            self.targetBundleID = targetBundleID
        }
        
        public static func empty() -> Payload {
            return Payload(title: "", body: "", priority: .low, targetToken: "", targetBundleID: "")
        }
        
        public var json: [String: Any] {
            var alert: [String:Any] = [
                "title" : title,
                "body" : body
            ]
            if let subtitle = subtitle {
                alert["subtitle"] = subtitle
            }
            var aps: [String: Any] = [
                "alert" : alert
            ]
            if let badge = badge {
                aps["badge"] = badge
            }
            let payload: [String: Any] = [
                "aps" : aps
            ]
            
            return payload
        }
    }
    
    public private(set) var certificate: Certificate
    var background = OperationQueue()
    public private(set) var session: URLSession!
    public var logError: ( (_ msg: Error) -> () )?
    let kPushCertificatePrefixes =  ["Apple Sandbox Push Services: ",
                                     "Apple Development IOS Push Services: ",
                                     "Apple Production IOS Push Services: ",
                                     "Apple Development Mac Push Services: ",
                                     "Apple Production Mac Push Services: ",
                                     "Apple Push Services: "]
    
    public init(certificate cert: Certificate) {
        certificate = cert
        super.init()
        
        session = URLSession(configuration: .default, delegate: self, delegateQueue: background)
    }
    
    public typealias Completion = (Error?) -> ()
    
    public func push(notification: Payload, completion: Completion? = nil ) {
        let payload = notification.json
        
        let urlPath = "\(certificate.host.urlPath)/3/device/\(notification.targetToken)"
        let url = URL(string: urlPath)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        request.addValue("\(notification.priority.rawValue)", forHTTPHeaderField: "apns-priority")
        request.addValue(notification.targetBundleID, forHTTPHeaderField: "apns-topic")
        request.addValue("alert", forHTTPHeaderField: "apns-push-type")
        
        session.dataTask(with: request) { data, response, error in
            OperationQueue.main.addOperation { [weak self] in
                if let error = error {
                    self?.logError?(error)
                    completion?(error)
                    return
                }
                
                if let data = data,
                   let body = String(data: data, encoding: .utf8),
                   !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let error = NSError(domain: "APNS-Response", code: 0, userInfo: [NSLocalizedDescriptionKey: body])
                    self?.logError?(error)
                    completion?(error)
                } else {
                    completion?(nil)
                }
            }
            
        }.resume()
    }
    
    func isPushCertificate(certificate: SecCertificate) -> Bool {
        guard let descriptionCF = SecCertificateCopySubjectSummary(certificate) else {
            return false
        }
        
        let description = descriptionCF as String
        
        for prefix in kPushCertificatePrefixes {
            if description.hasPrefix(prefix) {
                return true
            }
        }
        return false
    }
    
    func identities(certificate: Certificate) -> [AnyObject] {
        guard let url = Bundle.main.url(forResource: certificate.name, withExtension: "p12"),
              let certData = try? Data(contentsOf: url) as NSData
        else { return [] }
        
        let options: NSDictionary = [kSecImportExportPassphrase as NSString: certificate.password]
        var items : CFArray?
        
        let securityError: OSStatus = SecPKCS12Import(certData, options, &items)
        
        if let theArray = items,
           securityError == noErr && CFArrayGetCount(theArray) > 0 {
            let newArray = theArray as NSArray
            return newArray as [AnyObject]
        }
        
        return []
    }
    
    func certificatesWithIdentity(identity: SecIdentity) -> SecCertificate? {
        var certificateRef: SecCertificate? = nil
        let securityError = SecIdentityCopyCertificate(identity , &certificateRef)
        if securityError != noErr {
            certificateRef = nil
        }
        
        return certificateRef
    }
    
    func signature() -> (idenity: SecIdentity, certificate: SecCertificate)? {
        
        let identities = identities(certificate: certificate)
        for dict in identities {
            if let temp = dict[kSecImportItemIdentity] {
                let identity = temp as! SecIdentity
                let cert: SecCertificate! = certificatesWithIdentity(identity: identity)
                if cert == nil {
                    return nil
                }
                
                if !isPushCertificate(certificate: cert) {
                    return nil
                }
                
                return (identity, cert)
            }
        }
        
        return nil
    }
    
    
}

extension ServerlessPushService: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard let signature = signature() else {
            let error = NSError(domain: "ServerlessPushService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to setup signature from Push Certification (p12) file"])
            logError?(error)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let cred = URLCredential(identity: signature.idenity, certificates: [signature.certificate], persistence: .forSession)
        completionHandler(.useCredential, cred)
    }
}
