// This source file is part of the Swift.org Server APIs open source project
//
// Copyright (c) 2017 Swift Server API project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
//

import XCTest
import Dispatch
import ServerSecurity

@testable import HTTP

class ServerTests: XCTestCase {

    func testResponseOK() {
        let request = HTTPRequest(method: .get, target: "/echo", httpVersion: HTTPVersion(major: 1, minor: 1), headers: ["X-foo": "bar"])
        let resolver = TestResponseResolver(request: request, requestBody: Data())
        resolver.resolveHandler(EchoHandler().handle)
        XCTAssertNotNil(resolver.response)
        XCTAssertNotNil(resolver.responseBody)
        XCTAssertEqual(HTTPResponseStatus.ok.code, resolver.response?.status.code ?? 0)
    }

    func testEcho() {
        let testString = "This is a test"
        let request = HTTPRequest(method: .post, target: "/echo", httpVersion: HTTPVersion(major: 1, minor: 1), headers: ["X-foo": "bar"])
        let resolver = TestResponseResolver(request: request, requestBody: testString.data(using: .utf8)!)
        resolver.resolveHandler(EchoHandler().handle)
        XCTAssertNotNil(resolver.response)
        XCTAssertNotNil(resolver.responseBody)
        XCTAssertEqual(HTTPResponseStatus.ok.code, resolver.response?.status.code ?? 0)
        XCTAssertEqual(testString, resolver.responseBody?.withUnsafeBytes { String(bytes: $0, encoding: .utf8) } ?? "Nil")
    }

    func testHello() {
        let request = HTTPRequest(method: .get, target: "/helloworld", httpVersion: HTTPVersion(major: 1, minor: 1), headers: ["X-foo": "bar"])
        let resolver = TestResponseResolver(request: request, requestBody: Data())
        resolver.resolveHandler(HelloWorldHandler().handle)
        XCTAssertNotNil(resolver.response)
        XCTAssertNotNil(resolver.responseBody)
        XCTAssertEqual(HTTPResponseStatus.ok.code, resolver.response?.status.code ?? 0)
        XCTAssertEqual("Hello, World!", resolver.responseBody?.withUnsafeBytes { String(bytes: $0, encoding: .utf8) } ?? "Nil")
    }

    func testSimpleHello() {
        let request = HTTPRequest(method: .get, target: "/helloworld", httpVersion: HTTPVersion(major: 1, minor: 1), headers: ["X-foo": "bar"])
        let resolver = TestResponseResolver(request: request, requestBody: Data())
        let simpleHelloWebApp = SimpleResponseCreator { (_, body) -> SimpleResponseCreator.Response in
            return SimpleResponseCreator.Response(
                status: .ok,
                headers: ["X-foo": "bar"],
                body: "Hello, World!".data(using: .utf8)!
            )
        }
        resolver.resolveHandler(simpleHelloWebApp.handle)
        XCTAssertNotNil(resolver.response)
        XCTAssertNotNil(resolver.responseBody)
        XCTAssertEqual(HTTPResponseStatus.ok.code, resolver.response?.status.code ?? 0)
        XCTAssertEqual("Hello, World!", resolver.responseBody?.withUnsafeBytes { String(bytes: $0, encoding: .utf8) } ?? "Nil")
    }

    func testOkEndToEndCASecure() {
        let config = createCASignedTLSConfig()
        testOkEndToEndInternal(tlsParams: TLSParams(config: config, selfsigned: false))
    }

    func testOkEndToEndSelfSignedSecure() {
        let config = createSelfSignedTLSConfig()
        testOkEndToEndInternal(tlsParams: TLSParams(config: config, selfsigned: true))
    }

    func testOkEndToEnd() {
        testOkEndToEndInternal()
    }

    func testOkEndToEndInternal(tlsParams: TLSParams? = nil) {
        let receivedExpectation = self.expectation(description: "Received web response \(#function)")
        let httpStr: String
        let urlStr: String
        let session: URLSession
        
        let server = HTTPServer()
        do {
            if let tlsParams = tlsParams {
                try server.start(port: 0, tls: tlsParams.config, handler: OkHandler().handle)
                httpStr = "https"
                
                if tlsParams.selfsigned {
                    #if os(OSX)
                        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue:OperationQueue.main) // needed for self-signed
                    #else
                        // delegate in URLSession in Linux is not implemented. Using this to compile but it will fail if run on Linux.
                        session = URLSession(configuration: URLSessionConfiguration.default)
                    #endif
                    urlStr = "localhost"
                    
                } else {
                    session = URLSession(configuration: URLSessionConfiguration.default)
                    urlStr = "ssl.gelareh.xyz"
                }
            } else {
                try server.start(port: 0, handler: OkHandler().handle)
                session = URLSession(configuration: URLSessionConfiguration.default)
                httpStr = "http"
                urlStr = "localhost"
            }
            let url = URL(string: "\(httpStr)://\(urlStr):\(server.port)/")!
            print("Test \(#function) on port \(server.port)")
            print("url = \(url.absoluteString) ")
            let dataTask = session.dataTask(with: url) { (responseBody, rawResponse, error) in
                let response = rawResponse as? HTTPURLResponse
                XCTAssertNil(error, "\(error!.localizedDescription)")
                XCTAssertNotNil(response)
                XCTAssertNotNil(responseBody)
                XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response?.statusCode ?? 0)
                receivedExpectation.fulfill()
            }
            dataTask.resume()
            self.waitForExpectations(timeout: 10) { (error) in
                if let error = error {
                    XCTFail("\(error)")
                }
            }
            server.stop()
        } catch {
            XCTFail("Error listening on port \(0): \(error). Use server.failed(callback:) to handle")
        }
    }

    func testHelloEndToEndCASecure() {
        let config = createCASignedTLSConfig()
        testHelloEndToEndInternal(tlsParams: TLSParams(config: config, selfsigned: false))
    }

    func testHelloEndToEndSelfSignedSecure() {
        let config = createSelfSignedTLSConfig()
        testHelloEndToEndInternal(tlsParams: TLSParams(config: config, selfsigned: true))
    }

    func testHelloEndToEnd() {
        testHelloEndToEndInternal()
    }
    
    func testHelloEndToEndInternal(tlsParams: TLSParams? = nil) {

        let receivedExpectation = self.expectation(description: "Received web response \(#function)")
        let httpStr: String
        let urlStr: String
        let session: URLSession

        let server = HTTPServer()
        do {
            if let tlsParams = tlsParams {
                try server.start(port: 0, tls: tlsParams.config, handler: HelloWorldHandler().handle)
                httpStr = "https"
                
                if tlsParams.selfsigned {
                    #if os(OSX)
                        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue:OperationQueue.main) // needed for self-signed
                    #else
                        // delegate in URLSession in Linux is not implemented. Using this to compile but it will fail if run on Linux.
                        session = URLSession(configuration: URLSessionConfiguration.default)
                    #endif
                    urlStr = "localhost"
                    
                } else {
                    session = URLSession(configuration: URLSessionConfiguration.default)
                    urlStr = "ssl.gelareh.xyz"
                }
            } else {
                try server.start(port: 0, handler: HelloWorldHandler().handle)
                session = URLSession(configuration: URLSessionConfiguration.default)
                httpStr = "http"
                urlStr = "localhost"
            }
            
            let url = URL(string: "\(httpStr)://\(urlStr):\(server.port)/helloworld")!
            print("Test \(#function) on port \(server.port)")
            let dataTask = session.dataTask(with: url) { (responseBody, rawResponse, error) in
                let response = rawResponse as? HTTPURLResponse
                XCTAssertNil(error, "\(error!.localizedDescription)")
                XCTAssertNotNil(response)
                XCTAssertNotNil(responseBody)
                XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response?.statusCode ?? 0)
                XCTAssertEqual("Hello, World!", String(data: responseBody ?? Data(), encoding: .utf8) ?? "Nil")
                receivedExpectation.fulfill()
            }
            dataTask.resume()
            self.waitForExpectations(timeout: 10) { (error) in
                if let error = error {
                    XCTFail("\(error)")
                }
            }
            server.stop()
        } catch {
            XCTFail("Error listening on port \(0): \(error). Use server.failed(callback:) to handle")
        }
    }

    func testSimpleHelloEndToEndCASecure() {
        let config = createCASignedTLSConfig()
        testSimpleHelloEndToEndInternal(tlsParams: TLSParams(config: config, selfsigned: false))
    }
    
    func testSimpleHelloEndToEnd() {
        testSimpleHelloEndToEndInternal()
    }
    
    func testSimpleHelloEndToEndInternal(tlsParams: TLSParams? = nil) {
        
        let receivedExpectation = self.expectation(description: "Received web response \(#function)")
        let httpStr: String
        let urlStr: String
        let session: URLSession

        let simpleHelloWebApp = SimpleResponseCreator { (_, body) -> SimpleResponseCreator.Response in
            return SimpleResponseCreator.Response(
                status: .ok,
                headers: ["X-foo": "bar"],
                body: "Hello, World!".data(using: .utf8)!
            )
        }

        let server = HTTPServer()
        do {
            if let tlsParams = tlsParams {
                try server.start(port: 0, tls: tlsParams.config, handler: simpleHelloWebApp.handle)
                httpStr = "https"
                
                if tlsParams.selfsigned {
                    #if os(OSX)
                        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue:OperationQueue.main) // needed for self-signed
                    #else
                        // delegate in URLSession in Linux is not implemented. Using this to compile but it will fail if run on Linux.
                        session = URLSession(configuration: URLSessionConfiguration.default)
                    #endif
                    urlStr = "localhost"
                    
                } else {
                    session = URLSession(configuration: URLSessionConfiguration.default)
                    urlStr = "ssl.gelareh.xyz"
                }
            } else {
                try server.start(port: 0, handler: simpleHelloWebApp.handle)
                session = URLSession(configuration: URLSessionConfiguration.default)
                httpStr = "http"
                urlStr = "localhost"
            }
            
            let url = URL(string: "\(httpStr)://\(urlStr):\(server.port)/helloworld")!
            print("Test \(#function) on port \(server.port)")
            let dataTask = session.dataTask(with: url) { (responseBody, rawResponse, error) in
                print("\(#function) dataTask returned")
                let response = rawResponse as? HTTPURLResponse
                XCTAssertNil(error, "\(error!.localizedDescription)")
                XCTAssertNotNil(response)
                XCTAssertNotNil(responseBody)
                XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response?.statusCode ?? 0)
                let responseString = String(data: responseBody ?? Data(), encoding: .utf8) ?? "Nil"
                XCTAssertEqual("Hello, World!", responseString)
                print("\(#function) fulfilling expectation")
                receivedExpectation.fulfill()
            }
            dataTask.resume()
            self.waitForExpectations(timeout: 10) { (error) in
                if let error = error {
                    XCTFail("\(error)")
                }
            }
            server.stop()
        } catch {
            XCTFail("Error listening on port \(0): \(error). Use server.failed(callback:) to handle")
        }
    }

    func testRequestEchoEndToEndCASecure() {
        let config = createCASignedTLSConfig()
        testRequestEchoEndToEndInternal(tlsParams: TLSParams(config: config, selfsigned: false))
    }
    
    func testRequestEchoEndToEnd() {
        testRequestEchoEndToEndInternal()
    }
    
    func testRequestEchoEndToEndInternal(tlsParams: TLSParams? = nil) {
        
        let receivedExpectation = self.expectation(description: "Received web response \(#function)")
        let httpStr: String
        let urlStr: String
        let session: URLSession
        let testString="This is a test"

        let server = HTTPServer()
        do {
            if let tlsParams = tlsParams {
                try server.start(port: 0, tls: tlsParams.config, handler: EchoHandler().handle)
                httpStr = "https"
                
                if tlsParams.selfsigned {
                    #if os(OSX)
                        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue:OperationQueue.main) // needed for self-signed
                    #else
                        // delegate in URLSession in Linux is not implemented. Using this to compile but it will fail if run on Linux.
                        session = URLSession(configuration: URLSessionConfiguration.default)
                    #endif
                    urlStr = "localhost"
                    
                } else {
                    session = URLSession(configuration: URLSessionConfiguration.default)
                    urlStr = "ssl.gelareh.xyz"
                }
            } else {
                try server.start(port: 0, handler: EchoHandler().handle)
                session = URLSession(configuration: URLSessionConfiguration.default)
                httpStr = "http"
                urlStr = "localhost"
            }

            let url = URL(string: "\(httpStr)://\(urlStr):\(server.port)/echo")!
            print("Test \(#function) on port \(server.port)")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = testString.data(using: .utf8)
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")

            let dataTask = session.dataTask(with: request) { (responseBody, rawResponse, error) in
                let response = rawResponse as? HTTPURLResponse
                XCTAssertNil(error, "\(error!.localizedDescription)")
                XCTAssertNotNil(response)
                XCTAssertNotNil(responseBody)
                XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response?.statusCode ?? 0)
                XCTAssertEqual(testString, String(data: responseBody ?? Data(), encoding: .utf8) ?? "Nil")
                receivedExpectation.fulfill()
            }
            dataTask.resume()
            self.waitForExpectations(timeout: 10) { (error) in
                if let error = error {
                    XCTFail("\(error)")
                }
            }
            server.stop()
        } catch {
            XCTFail("Error listening on port \(0): \(error). Use server.failed(callback:) to handle")
        }
    }

    func testRequestKeepAliveEchoEndToEndCASecure() {
        let config = createCASignedTLSConfig()
        testRequestKeepAliveEchoEndToEndInternal(tlsParams: TLSParams(config: config, selfsigned: false))
    }
    
    func testRequestKeepAliveEchoEndToEnd() {
        testRequestKeepAliveEchoEndToEndInternal()
    }
    
    func testRequestKeepAliveEchoEndToEndInternal(tlsParams: TLSParams? = nil) {
        
        let receivedExpectation1 = self.expectation(description: "Received web response 1: \(#function)")
        let receivedExpectation2 = self.expectation(description: "Received web response 2: \(#function)")
        let receivedExpectation3 = self.expectation(description: "Received web response 3: \(#function)")
        let testString1="This is a test"
        let testString2="This is a test, too"
        let testString3="This is also a test"
        let httpStr: String
        let urlStr: String
        let session: URLSession

        let server = HTTPServer()
        do {
            if let tlsParams = tlsParams {
                try server.start(port: 0, tls: tlsParams.config, handler: EchoHandler().handle)
                httpStr = "https"
                
                if tlsParams.selfsigned {
                    #if os(OSX)
                        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue:OperationQueue.main) // needed for self-signed
                    #else
                        // delegate in URLSession in Linux is not implemented. Using this to compile but it will fail if run on Linux.
                        session = URLSession(configuration: URLSessionConfiguration.default)
                    #endif
                    urlStr = "localhost"
                    
                } else {
                    session = URLSession(configuration: URLSessionConfiguration.default)
                    urlStr = "ssl.gelareh.xyz"
                }
            } else {
                try server.start(port: 0, handler: EchoHandler().handle)
                session = URLSession(configuration: URLSessionConfiguration.default)
                httpStr = "http"
                urlStr = "localhost"
            }
            
            let url = URL(string: "\(httpStr)://\(urlStr):\(server.port)/echo")!
            print("Test \(#function) on port \(server.port)")
            var request1 = URLRequest(url: url)
            request1.httpMethod = "POST"
            request1.httpBody = testString1.data(using: .utf8)
            request1.setValue("text/plain", forHTTPHeaderField: "Content-Type")

            let dataTask1 = session.dataTask(with: request1) { (responseBody, rawResponse, error) in
                let response = rawResponse as? HTTPURLResponse
                XCTAssertNil(error, "\(error!.localizedDescription)")
                XCTAssertNotNil(response)
                let headers = response?.allHeaderFields ?? ["": ""]
                let connectionHeader: String = headers["Connection"] as? String ?? ""
                XCTAssertEqual(connectionHeader, "Keep-Alive", "No Keep-Alive Connection")
                XCTAssertNotNil(responseBody, "No Response Body")
                XCTAssertEqual(server.connectionCount, 1)
                XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response?.statusCode ?? 0)
                XCTAssertEqual(testString1, String(data: responseBody ?? Data(), encoding: .utf8) ?? "Nil")
                var request2 = URLRequest(url: url)
                request2.httpMethod = "POST"
                request2.httpBody = testString2.data(using: .utf8)
                request2.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                let dataTask2 = session.dataTask(with: request2) { (responseBody2, rawResponse2, error2) in
                    let response2 = rawResponse2 as? HTTPURLResponse
                    XCTAssertNil(error2, "\(error2!.localizedDescription)")
                    XCTAssertNotNil(response2)
                    let headers = response2?.allHeaderFields ?? ["": ""]
                    let connectionHeader: String = headers["Connection"] as? String ?? ""
                    XCTAssertEqual(connectionHeader, "Keep-Alive", "No Keep-Alive Connection")
                    XCTAssertEqual(server.connectionCount, 1)
                    XCTAssertNotNil(responseBody2)
                    XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response2?.statusCode ?? 0)
                    XCTAssertEqual(testString2, String(data: responseBody2 ?? Data(), encoding: .utf8) ?? "Nil")
                    var request3 = URLRequest(url: url)
                    request3.httpMethod = "POST"
                    request3.httpBody = testString3.data(using: .utf8)
                    request3.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                    let dataTask3 = session.dataTask(with: request3) { (responseBody, rawResponse, error) in
                        let response = rawResponse as? HTTPURLResponse
                        XCTAssertNil(error, "\(error!.localizedDescription)")
                        XCTAssertNotNil(response)
                        let headers = response?.allHeaderFields ?? ["": ""]
                        let connectionHeader: String = headers["Connection"] as? String ?? ""
                        XCTAssertEqual(connectionHeader, "Keep-Alive", "No Keep-Alive Connection")
                        XCTAssertEqual(server.connectionCount, 1)
                        XCTAssertNotNil(responseBody)
                        XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response?.statusCode ?? 0)
                        XCTAssertEqual(testString3, String(data: responseBody ?? Data(), encoding: .utf8) ?? "Nil")
                        receivedExpectation3.fulfill()
                    }
                    dataTask3.resume()
                    receivedExpectation2.fulfill()
                }
                dataTask2.resume()
                receivedExpectation1.fulfill()
            }
            dataTask1.resume()

            self.waitForExpectations(timeout: 10) { (error) in
                if let error = error {
                    XCTFail("\(error)")
                }
            }
            server.stop()
        } catch {
            XCTFail("Error listening on port \(0): \(error). Use server.failed(callback:) to handle")
        }
    }
    
    func testMultipleRequestWithoutKeepAliveEchoEndToEndSelfSignedSecure() {
        let config = createSelfSignedTLSConfig()
        testMultipleRequestWithoutKeepAliveEchoEndToEndInternal(tlsParams: TLSParams(config: config, selfsigned: true))
    }

    func testMultipleRequestWithoutKeepAliveEchoEndToEndCASecure() {
        let config = createCASignedTLSConfig()
        testMultipleRequestWithoutKeepAliveEchoEndToEndInternal(tlsParams: TLSParams(config: config, selfsigned: false))
    }

    func testMultipleRequestWithoutKeepAliveEchoEndToEnd() {
        testMultipleRequestWithoutKeepAliveEchoEndToEndInternal()
    }
    
    func testMultipleRequestWithoutKeepAliveEchoEndToEndInternal(tlsParams: TLSParams? = nil) {
        let receivedExpectation1 = self.expectation(description: "Received web response 1: \(#function)")
        let receivedExpectation2 = self.expectation(description: "Received web response 2: \(#function)")
        let receivedExpectation3 = self.expectation(description: "Received web response 3: \(#function)")
        let testString1="This is a test"
        let testString2="This is a test, too"
        let testString3="This is also a test"
        let httpStr: String
        let urlStr1: String, urlStr2: String, urlStr3: String
        let session: URLSession

        let server = HTTPServer()
        do {
            if let tlsParams = tlsParams {
                try server.start(port: 0, tls: tlsParams.config, handler: EchoHandler().handle)
                httpStr = "https"
                
                if tlsParams.selfsigned {
                    #if os(OSX)
                        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue:OperationQueue.main) // needed for self-signed
                    #else
                        // delegate in URLSession in Linux is not implemented. Using this to compile but it will fail if run on Linux.
                        session = URLSession(configuration: URLSessionConfiguration.default)
                    #endif
                    urlStr1 = "localhost"
                    urlStr2 = "127.0.0.1"
                    urlStr3 = "0.0.0.0"
                } else {
                    session = URLSession(configuration: URLSessionConfiguration.default)
                    urlStr1 = "ssl.gelareh.xyz"
                    urlStr2 = "ssl1.gelareh.xyz"
                    urlStr3 = "ssl2.gelareh.xyz"
                }
            } else {
                try server.start(port: 0, handler: EchoHandler().handle)
                session = URLSession(configuration: URLSessionConfiguration.default)
                httpStr = "http"
                urlStr1 = "localhost"
                urlStr2 = "127.0.0.1"
                urlStr3 = "0.0.0.0"
            }
            
            let url1 = URL(string: "\(httpStr)://\(urlStr1):\(server.port)/echo")!
            print("Test \(#function) on port \(server.port)")
            var request1 = URLRequest(url: url1)
            request1.httpMethod = "POST"
            request1.httpBody = testString1.data(using: .utf8)
            request1.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            request1.setValue("Keep-Alive", forHTTPHeaderField: "Connection")

            let dataTask1 = session.dataTask(with: request1) { (responseBody, rawResponse, error) in
                let response = rawResponse as? HTTPURLResponse
                XCTAssertNil(error, "\(error!.localizedDescription)")
                XCTAssertNotNil(response)
                let headers = response?.allHeaderFields ?? ["": ""]
                let connectionHeader: String = headers["Connection"] as? String ?? ""
                let keepAliveHeader = headers["Connection"]
                XCTAssertEqual(connectionHeader, "Keep-Alive", "No Keep-Alive Connection")
                XCTAssertNotNil(keepAliveHeader)
                XCTAssertNotNil(responseBody, "No Keep-Alive Header")
                XCTAssertEqual(server.connectionCount, 1)
                XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response?.statusCode ?? 0)
                XCTAssertEqual(testString1, String(data: responseBody ?? Data(), encoding: .utf8) ?? "Nil")
                let url2 = URL(string: "\(httpStr)://\(urlStr2):\(server.port)/echo")!
                var request2 = URLRequest(url: url2)
                request2.httpMethod = "POST"
                request2.httpBody = testString2.data(using: .utf8)
                request2.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                request2.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
                let dataTask2 = session.dataTask(with: request2) { (responseBody2, rawResponse2, error2) in
                    let response2 = rawResponse2 as? HTTPURLResponse
                    XCTAssertNil(error2, "\(error2!.localizedDescription)")
                    XCTAssertNotNil(response2)
                    let headers = response2?.allHeaderFields ?? ["": ""]
                    let connectionHeader: String = headers["Connection"] as? String ?? ""
                    let keepAliveHeader = headers["Connection"]
                    XCTAssertEqual(connectionHeader, "Keep-Alive", "No Keep-Alive Connection")
                    XCTAssertNotNil(keepAliveHeader, "No Keep-Alive Header")
                    XCTAssertEqual(server.connectionCount, 2)
                    XCTAssertNotNil(responseBody2)
                    XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response2?.statusCode ?? 0)
                    XCTAssertEqual(testString2, String(data: responseBody2 ?? Data(), encoding: .utf8) ?? "Nil")
                    let url3 = URL(string: "\(httpStr)://\(urlStr3):\(server.port)/echo")!
                    var request3 = URLRequest(url: url3)
                    request3.httpMethod = "POST"
                    request3.httpBody = testString3.data(using: .utf8)
                    request3.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                    request3.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
                    let dataTask3 = session.dataTask(with: request3) { (responseBody, rawResponse, error) in
                        let response = rawResponse as? HTTPURLResponse
                        XCTAssertNil(error, "\(error!.localizedDescription)")
                        XCTAssertNotNil(response)
                        let headers = response?.allHeaderFields ?? ["": ""]
                        let connectionHeader: String = headers["Connection"] as? String ?? ""
                        let keepAliveHeader = headers["Connection"]
                        XCTAssertEqual(connectionHeader, "Keep-Alive", "No Keep-Alive Connection")
                        XCTAssertNotNil(keepAliveHeader, "No Keep-Alive Header")
                        XCTAssertEqual(server.connectionCount, 3)
                        XCTAssertNotNil(responseBody)
                        XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response?.statusCode ?? 0)
                        XCTAssertEqual(testString3, String(data: responseBody ?? Data(), encoding: .utf8) ?? "Nil")
                        receivedExpectation3.fulfill()
                    }
                    dataTask3.resume()
                    receivedExpectation2.fulfill()
                }
                dataTask2.resume()
                receivedExpectation1.fulfill()
            }
            dataTask1.resume()
            
            self.waitForExpectations(timeout: 10) { (error) in
                if let error = error {
                    XCTFail("\(error)")
                }
            }
            server.stop()
        } catch {
            XCTFail("Error listening on port \(0): \(error). Use server.failed(callback:) to handle")
        }
    }

    func testRequestLargeEchoEndToEndCASecure() {
        let config = createCASignedTLSConfig()
        testRequestLargeEchoEndToEndInternal(tlsParams: TLSParams(config: config, selfsigned: false))
    }
    
    func testRequestLargeEchoEndToEnd() {
        testRequestLargeEchoEndToEndInternal()
    }
    
    func testRequestLargeEchoEndToEndInternal(tlsParams: TLSParams? = nil) {
        
        let receivedExpectation = self.expectation(description: "Received web response \(#function)")
        let httpStr: String
        let urlStr: String
        let session: URLSession

        //Use a small chunk size to make sure that we're testing multiple HTTPBodyHandler calls
        let chunkSize = 1024

        // Get a file we know exists
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let testExecutableData: Data

        do {
            testExecutableData = try Data(contentsOf: executableURL)
        } catch {
            XCTFail("Could not create Data from contents of \(executableURL)")
            return
        }

        var testDataLong = testExecutableData + testExecutableData + testExecutableData + testExecutableData
        let length = testDataLong.count
        let keep = 16385
        let remove = length - keep
        if remove > 0 {
            testDataLong.removeLast(remove)
        }

        let testData = Data(testDataLong)

        let server = PoCSocketSimpleServer()
        do {
            if let tlsParams = tlsParams {
                try server.start(port: 0, maxReadLength: chunkSize, tlsConfig: tlsParams.config, handler: EchoHandler().handle)
                httpStr = "https"
                
                if tlsParams.selfsigned {
                    #if os(OSX)
                        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue:OperationQueue.main) // needed for self-signed
                    #else
                        // delegate in URLSession in Linux is not implemented. Using this to compile but it will fail if run on Linux.
                        session = URLSession(configuration: URLSessionConfiguration.default)
                    #endif
                    urlStr = "localhost"
                    
                } else {
                    session = URLSession(configuration: URLSessionConfiguration.default)
                    urlStr = "ssl.gelareh.xyz"
                }
            } else {
                try server.start(port: 0, maxReadLength: chunkSize, handler: EchoHandler().handle)
                session = URLSession(configuration: URLSessionConfiguration.default)
                httpStr = "http"
                urlStr = "localhost"
            }

            let url = URL(string: "\(httpStr)://\(urlStr):\(server.port)/echo")!
            print("Test \(#function) on port \(server.port)")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = testData
            let dataTask = session.dataTask(with: request) { (responseBody, rawResponse, error) in
                let response = rawResponse as? HTTPURLResponse
                XCTAssertNil(error, "\(error!.localizedDescription)")
                XCTAssertNotNil(response)
                XCTAssertNotNil(responseBody)
                XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response?.statusCode ?? 0)
                XCTAssertEqual(testData, responseBody ?? Data())
                receivedExpectation.fulfill()
            }
            dataTask.resume()
            self.waitForExpectations(timeout: 10) { (error) in
                if let error = error {
                    XCTFail("\(error)")
                }
            }
            server.stop()
        } catch {
            XCTFail("Error listening on port \(0): \(error). Use server.failed(callback:) to handle")
        }
    }
    
    func testRequestLargePostHelloWorldCASecure() {
        let config = createCASignedTLSConfig()
        testRequestLargePostHelloWorldInternal(tlsParams: TLSParams(config: config, selfsigned: false))
    }
    
    func testRequestLargePostHelloWorld() {
        testRequestLargePostHelloWorldInternal()
    }
    
    func testRequestLargePostHelloWorldInternal(tlsParams: TLSParams? = nil) {
        
        let receivedExpectation = self.expectation(description: "Received web response \(#function)")
        let httpStr: String
        let urlStr: String
        let session: URLSession

        // Use a small chunk size to make sure that we stop after one HTTPBodyHandler call
        let chunkSize = 1024
        
        // Get a file we know exists
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let testExecutableData: Data
        
        do {
            testExecutableData = try Data(contentsOf: executableURL)
        } catch {
            XCTFail("Could not create Data from contents of \(executableURL)")
            return
        }
        
        //Make sure there's data there
        XCTAssertNotNil(testExecutableData)
        
        let executableLength = testExecutableData.count
                
        let server = PoCSocketSimpleServer()
        do {
            let testHandler = AbortAndSendHelloHandler()
            
            if let tlsParams = tlsParams {
                try server.start(port: 0, maxReadLength: chunkSize, tlsConfig: tlsParams.config, handler: testHandler.handle)
                httpStr = "https"
                
                if tlsParams.selfsigned {
                    #if os(OSX)
                        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue:OperationQueue.main) // needed for self-signed
                    #else
                        // delegate in URLSession in Linux is not implemented. Using this to compile but it will fail if run on Linux.
                        session = URLSession(configuration: URLSessionConfiguration.default)
                    #endif
                    urlStr = "localhost"
                    
                } else {
                    session = URLSession(configuration: URLSessionConfiguration.default)
                    urlStr = "ssl.gelareh.xyz"
                }
            } else {
                try server.start(port: 0, maxReadLength: chunkSize, handler: testHandler.handle)
                session = URLSession(configuration: URLSessionConfiguration.default)
                httpStr = "http"
                urlStr = "localhost"
            }
            print("Test \(#function) on port \(server.port)")
            
            let url = URL(string: "\(httpStr)://\(urlStr):\(server.port)/echo")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            let uploadTask = session.uploadTask(with: request, fromFile: executableURL) { (responseBody, rawResponse, error) in
                let response = rawResponse as? HTTPURLResponse
                XCTAssertNil(error, "\(error!.localizedDescription)")
                XCTAssertNotNil(response)
                XCTAssertNotNil(responseBody)
                XCTAssertEqual(Int(HTTPResponseStatus.ok.code), response?.statusCode ?? 0)
                XCTAssertEqual("Hello, World!", String(data: responseBody ?? Data(), encoding: .utf8) ?? "Nil")
                XCTAssertEqual(Int(testHandler.chunkCalledCount), 1)
                XCTAssertLessThan(testHandler.chunkLength, executableLength, "Should have written less than the length of the file")
                if ((tlsParams != nil) && (chunkSize < TLSConstants.maxTLSRecordLength)) {
                    XCTAssertLessThanOrEqual(Int(testHandler.chunkLength), TLSConstants.maxTLSRecordLength)
                } else {
                    XCTAssertLessThanOrEqual(Int(testHandler.chunkLength), chunkSize)
                }
                receivedExpectation.fulfill()
            }
            uploadTask.resume()
            self.waitForExpectations(timeout: 10) { (error) in
                if let error = error {
                    XCTFail("\(error)")
                }
            }
            server.stop()
        } catch {
            XCTFail("Error listening on port \(0): \(error). Use server.failed(callback:) to handle")
        }
    }


    func testExplicitCloseConnections() {
        let expectation = self.expectation(description: "0 Open Connection")
        let server = PoCSocketSimpleServer()
        let keepAliveTimeout = 0.1

        do {
            try server.start(port: 0, keepAliveTimeout: keepAliveTimeout, handler: OkHandler().handle)
            
            let session = URLSession(configuration: .default)
            let url1 = URL(string: "http://localhost:\(server.port)")!
            var request = URLRequest(url: url1)
            request.httpMethod = "POST"
            request.setValue("close", forHTTPHeaderField: "Connection")
            
            let dataTask1 = session.dataTask(with: request) { (responseBody, rawResponse, error) in
                XCTAssertNil(error, "\(error!.localizedDescription)")
                #if os(Linux)
                    XCTAssertEqual(server.connectionCount, 0)
                    expectation.fulfill()
                
                    // Darwin's URLSession replaces the `Connection: close` header with `Connection: keep-alive`, so allow it to expire
                #else
                    DispatchQueue.main.asyncAfter(deadline: .now() + keepAliveTimeout) {
                        XCTAssertEqual(server.connectionCount, 0)
                        expectation.fulfill()
                    }
                #endif
            }
            dataTask1.resume()
            
            self.waitForExpectations(timeout: 30) { (error) in
                if let error = error {
                    XCTFail("\(error)")
                }
            }
            server.stop()
        } catch {
            XCTFail("Error listening on port \(0): \(error). Use server.failed(callback:) to handle")
        }
    }

    private func createSelfSignedTLSConfig() -> TLSConfiguration {
        #if os(Linux)
            let myCAPath = URL(fileURLWithPath: #file).appendingPathComponent("../../Certs/Self-Signed/chain.pem").standardized
            let myCertPath = URL(fileURLWithPath: #file).appendingPathComponent("../../Certs/Self-Signed/cert.pem").standardized
            let myKeyPath = URL(fileURLWithPath: #file).appendingPathComponent("../../Certs/Self-Signed/key.pem").standardized
            let config = TLSConfiguration(withCACertificateFilePath: myCAPath.path, usingCertificateFile: myCertPath.path, withKeyFile: myKeyPath.path, usingSelfSignedCerts: true)
        #else
            let myP12 = URL(fileURLWithPath: #file).appendingPathComponent("../../../Certs/Self-Signed/cert.pfx").standardized
            let myPassword = "sw!ft!sC00l"
            let config = TLSConfiguration(withChainFilePath: myP12.path, withPassword: myPassword, usingSelfSignedCerts: true)
        #endif
        
        return config
    }

    private func createCASignedTLSConfig() -> TLSConfiguration {
        #if os(Linux)

            let myCAPath = URL(fileURLWithPath: #file).appendingPathComponent("../../../Certs/letsEncryptCA/chain.pem").standardized
            let myCertPath = URL(fileURLWithPath: #file).appendingPathComponent("../../../Certs/letsEncryptCA/cert.pem").standardized
            let myKeyPath = URL(fileURLWithPath: #file).appendingPathComponent("../../../Certs/letsEncryptCA/key.pem").standardized
            let config = TLSConfiguration(withCACertificateFilePath: myCAPath.path, usingCertificateFile: myCertPath.path, withKeyFile: myKeyPath.path, usingSelfSignedCerts: false)
//            print("myCAPath is at: \(myCAPath.absoluteString) ")
//            print("myCertPath is at: \(myCertPath.absoluteString) ")
//            print("myKeyPath is at: \(myKeyPath.absoluteString) ")
            
        #else
            let myP12 = URL(fileURLWithPath: #file).appendingPathComponent("../../../Certs/letsEncryptCA/cert.pfx").standardized
            let myPassword = "password"
            let config = TLSConfiguration(withChainFilePath: myP12.path, withPassword: myPassword, usingSelfSignedCerts: false)
//            print("myCertPath is at: \(myP12.absoluteString) ")

        #endif
        
        return config
    }
    
    static var allTests = [
        ("testEcho", testEcho),
        ("testHello", testHello),
        ("testSimpleHello", testSimpleHello),
        ("testResponseOK", testResponseOK),
        ("testOkEndToEnd", testOkEndToEnd),
        ("testOkEndToEndCASecure", testOkEndToEndCASecure),
        ("testHelloEndToEnd", testHelloEndToEnd),
        ("testHelloEndToEndCASecure", testHelloEndToEndCASecure),
        ("testSimpleHelloEndToEnd", testSimpleHelloEndToEnd),
        ("testSimpleHelloEndToEndCASecure", testSimpleHelloEndToEndCASecure),
        ("testRequestEchoEndToEnd", testRequestEchoEndToEnd),
        ("testRequestEchoEndToEndCASecure", testRequestEchoEndToEndCASecure),
        ("testRequestKeepAliveEchoEndToEnd", testRequestKeepAliveEchoEndToEnd),
        ("testRequestKeepAliveEchoEndToEndCASecure", testRequestKeepAliveEchoEndToEndCASecure),
        ("testRequestLargeEchoEndToEnd", testRequestLargeEchoEndToEnd),
        ("testRequestLargeEchoEndToEndCASecure", testRequestLargeEchoEndToEndCASecure),
        ("testExplicitCloseConnections", testExplicitCloseConnections),
        ("testMultipleRequestWithoutKeepAliveEchoEndToEnd",testMultipleRequestWithoutKeepAliveEchoEndToEnd),
        ("testMultipleRequestWithoutKeepAliveEchoEndToEndCASecure", testMultipleRequestWithoutKeepAliveEchoEndToEndCASecure),
        ("testRequestLargePostHelloWorld", testRequestLargePostHelloWorld),
        ("testRequestLargePostHelloWorldCASecure", testRequestLargePostHelloWorldCASecure),
    ]
}

#if os(OSX)
extension ServerTests: URLSessionDelegate {
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!) )
    }
}
#endif


