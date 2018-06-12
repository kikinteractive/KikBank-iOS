//
//  KBLoggerType.swift
//  KikBank
//
//  Created by James Harquail on 2018-05-07.
//

import Foundation

public protocol KBLoggerType {
    func log(verbose description: String) -> Void
    func log(error description: String) -> Void
}
