//
//  KBLogger.swift
//  KikBank
//
//  Created by James Harquail on 2018-05-07.
//

import Foundation

public class KBLogger: KBLoggerType {

    public func log(verbose description: String) {
        print(description)
    }

    public func log(error description: String) {
        print(description)
    }
}
