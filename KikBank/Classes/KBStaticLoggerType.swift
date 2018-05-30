//
//  KBStaticLoggerType.swift
//  KikBank
//
//  Created by James Harquail on 2018-05-07.
//

import Foundation

@objc public protocol KBStaticLoggerType {
    static func log(verbose description: String) -> Void
    static func log(error description: String) -> Void
}
