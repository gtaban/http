//
//  TLSParams.swift
//  HTTPTests
//
//  Created by Gelareh Taban on 10/13/17.
//

import Foundation
import ServerSecurity

public struct TLSParams {
    public private(set) var config: TLSConfiguration
    public private(set) var selfsigned: Bool
    
    // Max size of TLS record in Bytes
    static let maxTLSRecordLength: Int = 16384
    
    /// Creates an HTTP version.
    public init(config: TLSConfiguration, selfsigned: Bool) {
        self.config = config
        self.selfsigned = selfsigned
    }
}
