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
public struct KBReadOption: OptionSet {
    public let rawValue: Int

    // Read Options
    public static let disk =    KBReadOption(rawValue: 1 << 0)
    public static let memory =  KBReadOption(rawValue: 1 << 1)
    public static let network = KBReadOption(rawValue: 1 << 2)

    // Convenience Options
    public static let cache: KBReadOption = [.disk, .memory]
    public static let any: KBReadOption = [.disk, .memory, .network]
    public static let none: KBReadOption = []

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/**
 Request Write Policy

 - memory: Write item to memory, lost on storage dealloc
 - disk: Write item to disk, saved between sessions
 - optional: Check for existing equal item before performing a write operation
        NOTE: .optional is a modifier write option
              If only .optional is provided nothing will be saved
 - cache: memory and disk
 - none: No write required
 */
public struct KBWriteOption: OptionSet {
    public let rawValue: Int

    // Write Options
    public static let memory = KBWriteOption(rawValue: 1 << 0)
    public static let disk =   KBWriteOption(rawValue: 1 << 1)

    // Modifier
    public static let optional = KBWriteOption(rawValue: 1 << 2)

    // Convenience Options
    public static let cache: KBWriteOption = [.memory, .disk, .optional]
    public static let none: KBWriteOption = []

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/// Specify how data should be fetched and saved
public class KBParameters: NSObject {

    /// The data read type
    public var readOption: KBReadOption = .any

    // The data write type
    public var writeOption: KBWriteOption = [.memory, .optional]
}
