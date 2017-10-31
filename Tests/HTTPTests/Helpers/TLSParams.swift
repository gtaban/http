// This source file is part of the Swift.org Server APIs open source project
//
// Copyright (c) 2017 Swift Server API project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
//

import Foundation
import ServerSecurity

public struct TLSParams {
    public private(set) var config: TLSConfiguration
    public private(set) var selfsigned: Bool
    
    /// Creates an HTTP version.
    public init(config: TLSConfiguration, selfsigned: Bool) {
        self.config = config
        self.selfsigned = selfsigned
    }
}
