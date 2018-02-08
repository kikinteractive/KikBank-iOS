//
//  KBAssetTests.swift
//  KikBank_Example
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import XCTest

@testable import KikBank
class KBAssetTests: XCTestCase {

    func testExpiryNoDate() {
        let asset = KBAsset(uuid: "1", data: Data())
        XCTAssertTrue(asset.isValid())
    }

    func testExpiryHistoricDate() {
        let asset = KBAsset(uuid: "1", data: Data())
        let historicDate = Date(timeIntervalSinceNow: -3600)
        asset.expiryDate = historicDate
        XCTAssertLessThan(historicDate.timeIntervalSince1970, Date().timeIntervalSince1970)
        XCTAssertFalse(asset.isValid())
    }

    func testExpiryFutureDate() {
        let asset = KBAsset(uuid: "1", data: Data())
        let futureDate = Date(timeIntervalSinceNow: 3600)
        asset.expiryDate = futureDate
        XCTAssertGreaterThan(futureDate.timeIntervalSince1970, Date().timeIntervalSince1970)
        XCTAssertTrue(asset.isValid())
    }
}
