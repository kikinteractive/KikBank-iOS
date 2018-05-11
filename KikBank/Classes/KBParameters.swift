//
//  KBParameters.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-09.
//

import Foundation

/**
 Request Read Policy

 - diskOnly: Only returns content from disk storage
 - memoryOnly: Only returns content in memory
 - networkOnly: Make a new network fetch for each request
 - any: Check memory and then disk before making a network request
 */
public struct KBReadOtions: OptionSet {
    public let rawValue: Int

    public static let diskOnly =       KBReadOtions(rawValue: 1 << 0)
    public static let memoryOnly =     KBReadOtions(rawValue: 1 << 1)
    public static let networkOnly =    KBReadOtions(rawValue: 1 << 2)

    public static let cacheOnly: KBReadOtions = [.diskOnly, .memoryOnly]
    public static let any: KBReadOtions = [.diskOnly, .memoryOnly, .networkOnly]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/**
 Request Write Policy

 - memory: Write item to memory, lost on storage dealloc
 - disk: Write item to disk, saved between sessions
 - all: Write item to memory and to disk storage
 */
public struct KBWriteOtions: OptionSet {
    public let rawValue: Int

    public static let memory = KBWriteOtions(rawValue: 1 << 0)
    public static let disk =   KBWriteOtions(rawValue: 1 << 1)

    public static let all: KBWriteOtions = [.memory, .disk]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/// Specify how data should be fetched and saved
public class KBParameters: NSObject {
    /// The date after which the cached data is considered invalid
    public var expiryDate: Date?

    /// The data read type
    public var readOptions: KBReadOtions = .any

    // The data write type
    public var writeOptions: KBWriteOtions = .memory
}
