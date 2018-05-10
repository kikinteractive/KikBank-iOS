//
//  KBParameters.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-09.
//

import Foundation

/**
 Request Read Policy

 - cacheOnly: Only return locally stored content
 - networkOnly: Make a new network fetch for each request
 - any: Check cache before making a new request
 */
public enum KBReadPolicy: Int {
    case cacheOnly, networkOnly, any
}

/**
 Request Write Policy

 - none: Don't save anything to storage
 - memory: Write item to memory, lost on storage dealloc
 - disk: Write to disk **and** to memory, fetched on next alloc
 */
public enum KBWritePolicy: Int {
    case none, memory, disk
}

/// Specify how data should be fetched and saved
public class KBParameters: NSObject {
    /// The date after which the cached data is considered invalid
    public var expiryDate: Date?

    /// The data read type
    public var readPolicy: KBReadPolicy = .any

    // The data write type
    public var writePolicy: KBWritePolicy = .memory
}
