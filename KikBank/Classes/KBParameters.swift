//
//  KBParameters.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-09.
//

import Foundation

/**
 Request Read Policy

 - disk: Only returns content from disk storage
 - memory: Only returns content in memory
 - network: Ignore stored assets and make a new network fetch for each request
 - cache: Only returns locally stored content, will never make a new request
 - any: Check memory and then disk before making a network request
 */
public struct KBReadOptions: OptionSet {
    public let rawValue: Int

    public static let disk =    KBReadOptions(rawValue: 1 << 0)
    public static let memory =  KBReadOptions(rawValue: 1 << 1)
    public static let network = KBReadOptions(rawValue: 1 << 2)

    public static let cache: KBReadOptions = [.disk, .memory]
    public static let any: KBReadOptions = [.disk, .memory, .network]

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

    /// The data read type
    public var readOptions: KBReadOptions = .any

    // The data write type
    public var writeOptions: KBWriteOtions = .memory
}
