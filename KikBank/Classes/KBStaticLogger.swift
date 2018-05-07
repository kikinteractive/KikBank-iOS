//
//  KBStaticLogger.swift
//  KikBank
//
//  Created by James Harquail on 2018-05-07.
//

import Foundation

public class KBStaticLogger: KBStaticLoggerType {

    public static func log(verbose description: String) {
        print(description)
    }

    public static func log(error description: String) {
        print(description)
    }
}
