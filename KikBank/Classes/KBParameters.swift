//
//  KBParameters.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-09.
//

import Foundation

/**
 Request Read Policy

 - cache: Check storage for a copy before making a new request
 - network: Ignore local storage forcing a network request
 */
@objc public enum KBReadPolicy: Int {
    case cache, network
}

/**
 Request Write Policy

 - none: Don't save anything to storage
 - memory: Persit item in memory, lost on storage dealloc
 - disk: Write to disk, fetched on next alloc
 */
@objc public enum KBWritePolicy: Int {
    case none, memory, disk
}

/// Specify how data should be fetched and saved
@objc public class KBParameters: NSObject {
    /// The interval which the cached data is considered valid
    @objc public var expiryDate: Date?

    /// The data read type
    @objc public var readPolicy: KBReadPolicy = .cache

    // The data write type
    @objc public var writePolicy: KBWritePolicy = .memory
}
