//
//  MobileConfigServer.swift
//  Telegraph Examples
//
//  Created by Yvo van Beek on 5/17/17.
//  Copyright © 2017 Building42. All rights reserved.
//

import Telegraph

public class MobileConfigServer: NSObject {
    var identity: CertificateIdentity?
    var caCertificate: Certificate?
    var tlsPolicy: TLSPolicy?
    
    var server: Server?
    
    static let shared = MobileConfigServer()
    
    private override init() {}
}

public extension MobileConfigServer {
    func start(data: Data) {
        loadCertificates()
        setupMobileConfigServer(data: data)
    }
    
    func dismiss() {
        server?.stop()
    }
}

extension MobileConfigServer {
    private func loadCertificates() {
        if let identityURL = Bundle.main.url(forResource: "localhost", withExtension: "p12") {
            identity = CertificateIdentity(p12URL: identityURL, passphrase: "test")
        }
        
        if let caCertificateURL = Bundle.main.url(forResource: "ca", withExtension: "der") {
            caCertificate = Certificate(derURL: caCertificateURL)
        }
        
        if let caCertificate = caCertificate {
            tlsPolicy = TLSPolicy(commonName: "localhost", certificates: [caCertificate])
        }
    }
    
    private func setupMobileConfigServer(data: Data) {
        if server?.isRunning == true {
            server!.stop()
        }
        
        if let identity = identity, let caCertificate = caCertificate {
            server = Server(identity: identity, caCertificates: [caCertificate])
        } else {
            server = Server()
        }
        
        server!.delegate = self
        
        server!.route(.GET, "download") { _ in
            let response = HTTPResponse(.ok)
            response.headers.contentType = "application/x-apple-aspen-config"
            response.headers.contentDisposition = "attachment; filename=icons.mobileconfig"
            response.body = data
            return response
        }
        server!.serveDirectory(Bundle.main.url(forResource: "mobileconfig", withExtension: "html")!, "/mobileconfig")
        
        server!.serveBundle(.main, "/")
        
        server!.concurrency = 4
        
        do {
            try server!.start(port: 9000, interface: "localhost")
            print("[SERVER]", "服务启动")
        } catch {
            print("[SERVER]", "服务启动失败:", error.localizedDescription)
        }
    }
}


extension MobileConfigServer: ServerDelegate {
    public func serverDidStop(_ server: Server, error: Error?) {
        print("[SERVER]", "服务终止:", error?.localizedDescription ?? "no details")
    }
}

extension MobileConfigServer: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = tlsPolicy!.evaluateSession(trust: challenge.protectionSpace.serverTrust)
        completionHandler(credential == nil ? .cancelAuthenticationChallenge : .useCredential, credential)
    }
}
