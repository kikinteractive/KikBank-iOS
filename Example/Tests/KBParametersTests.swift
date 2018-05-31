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

    // Read

    // Disk read should only include disk
    func testDiskReadOptions() {
        let readOption = KBReadOptions.disk

        XCTAssertEqual(readOption, KBReadOptions.disk)
        XCTAssertTrue(readOption.contains(.disk))

        XCTAssertFalse(readOption.contains(.memory))
        XCTAssertFalse(readOption.contains(.network))
    }

    // Cache read should include only disk and memory
    func testCacheReadOption() {
        let readOption = KBReadOptions.cache

        XCTAssertTrue(readOption.contains(.cache))
        XCTAssertTrue(readOption.contains(.memory))
        XCTAssertTrue(readOption.contains(.disk))

        XCTAssertFalse(readOption.contains(.network))
    }

    // Any read should include all options
    func testAnyReadOption() {
        let readOption = KBReadOptions.any

        XCTAssertTrue(readOption.contains(.any))
        XCTAssertTrue(readOption.contains(.memory))
        XCTAssertTrue(readOption.contains(.disk))
        XCTAssertTrue(readOption.contains(.network))
    }

    // Write

    // All write should include all options
    func testAllWriteOption() {
        let writeOption = KBWriteOptions.all

        XCTAssertTrue(writeOption.contains(.all))
        XCTAssertTrue(writeOption.contains(.memory))
        XCTAssertTrue(writeOption.contains(.disk))
    }
}
