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
public enum KBReadPolicy: Int {
    case cache, network
}

/**
 Request Write Policy

 - none: Don't save anything to storage
 - memory: Persit item in memory, lost on storage dealloc
 - disk: Write to disk, fetched on next alloc
 */
public enum KBWritePolicy: Int {
    case none, memory, disk
}

/// Specify how data should be fetched and saved
public class KBParameters: NSObject {
    /// The date after which the cached data is considered invalid
    public var expiryDate: Date?

    /// The data read type
    public var readPolicy: KBReadPolicy = .cache

    // The data write type
    public var writePolicy: KBWritePolicy = .memory
}
