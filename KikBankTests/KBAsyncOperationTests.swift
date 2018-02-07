//
//  KBAsyncOperationTests.swift
//  KikBankTests
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import XCTest

@testable import KikBank
class KBAsyncOperationTests: XCTestCase {

    func testSingleOperation() {
        let operation = TestAsyncOperation()
        let queue = OperationQueue()

        let expection = expectation(description: "test")
        operation.completionBlock = {
            print("completion")
            expection.fulfill()
        }

        queue.addOperation(operation)
        waitForExpectations(timeout: 2, handler: nil)
    }

    func testSequentialOperations() {
        let operation1 = TestAsyncOperation(sleepMS: 1000)
        let operation2 = TestAsyncOperation(sleepMS: 500)

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let expectation1 = expectation(description: "first")
        let expectation2 = expectation(description: "second")

        operation1.completionBlock = {
            print("One done")
            XCTAssertFalse(operation2.isFinished)
            expectation1.fulfill()
        }
        operation2.completionBlock = {
            print("Two done")
            expectation2.fulfill()
        }

        queue.addOperations([operation1, operation2], waitUntilFinished: false)
        waitForExpectations(timeout: 2, handler: nil)
    }
}

fileprivate class TestAsyncOperation: KBAsyncOperation {

    private let MS: UInt32 = 1000
    public let sleepMS: UInt32

    init(sleepMS: UInt32 = 1000) {
        self.sleepMS = sleepMS
        super.init()
    }

    override func main() {
        guard !isCancelled else {
            _finished = true
            return
        }

        _executing = true

        print("Starting")

        usleep(sleepMS * MS)

        print("Done")

        _executing = false
        _finished = true
    }
}
