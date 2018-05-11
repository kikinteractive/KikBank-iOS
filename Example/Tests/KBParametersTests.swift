//
//  KBParametersTests.swift
//  KikBank_Example
//
//  Created by James Harquail on 2018-05-11.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import XCTest

@testable import KikBank
class KBParametersTests: XCTestCase {

    // Cache read option should include only disk and memory
    func testCacheReadOption() {
        let readOption = KBReadOptions.cache

        XCTAssertTrue(readOption.contains(.cache))
        XCTAssertTrue(readOption.contains(.memory))
        XCTAssertTrue(readOption.contains(.disk))
        XCTAssertFalse(readOption.contains(.network))
    }

    func testAnyReadOption() {
        let readOption = KBReadOptions.any

        XCTAssertTrue(readOption.contains(.any))
        XCTAssertTrue(readOption.contains(.memory))
        XCTAssertTrue(readOption.contains(.disk))
        XCTAssertTrue(readOption.contains(.network))
    }

    func testAllWriteOption() {
        let writeOption = KBWriteOtions.all

        XCTAssertTrue(writeOption.contains(.all))
        XCTAssertTrue(writeOption.contains(.memory))
        XCTAssertTrue(writeOption.contains(.disk))
    }
}
