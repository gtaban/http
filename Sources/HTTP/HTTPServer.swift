// This source file is part of the Swift.org Server APIs open source project
//
// Copyright (c) 2017 Swift Server API project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
//

import ServerSecurity

/// Definition of an HTTP server.
public protocol HTTPServing : class {

    /// Start the HTTP server
    func start() throws

    /// Stop the server
    func stop()

    /// The port the server is listening on
    var port: Int { get }

    /// The number of current connections
    var connectionCount: Int { get }
}

/// A basic HTTP server. Currently this is implemented using the PoCSocket
/// abstraction, but the intention is to remove this dependency and reimplement
/// the class using transport APIs provided by the Server APIs working group.
public class HTTPServer: HTTPServing {

    /// A subclass for HTTP Options
    /// HTTP on the given `port`, using `handler` to process incoming requests
    public class Options {
        public let port: Int
        public let handler: HTTPRequestHandler
        public let tls: TLSConfiguration?

        ///  Create an instance of HTTPServerOptions
        public init(onPort: Int = 0, withTLS: TLSConfiguration? = nil, withHandler: @escaping HTTPRequestHandler) {
            port = onPort
            handler = withHandler
            tls = withTLS
        }
        
    }
    
    private let server = PoCSocketSimpleServer()
    public let options: Options

    /// Create an instance of the server. This needs to be followed with a call to `start(port:handler:)`
    public init(with newOptions: Options) {
        options = newOptions
    }

    /// Start the HTTP server on the given `port`, using `handler` to process incoming requests
//    public func start(port: Int = 0, tls: TLSConfiguration? = nil, handler: @escaping HTTPRequestHandler) throws {
    public func start() throws {
        try server.start(port: options.port, tlsConfig: options.tls, handler: options.handler)
    }

    /// Stop the server
    public func stop() {
        server.stop()
    }

    /// The port number the server is listening on
    public var port: Int {
        return server.port
    }

    /// The number of current connections
    public var connectionCount: Int {
        return server.connectionCount
    }
}
