//
//  KBStorageManagerTests.swift
//  KikBank_Example
//
//  Created by James Harquail on 2018-05-10.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import XCTest
import RxSwift

@testable import KikBank
class KBStorageManagerTests: XCTestCase {

    var storageManager: KBStorageManager!
    var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()

        storageManager = KBStorageManager(pathExtension: "KBTestDir")
        disposeBag = DisposeBag()
    }
    
    override func tearDown() {
        super.tearDown()

        storageManager
            .clearMemoryStorage()
            .subscribe(onCompleted: {
                print("Cleared memory")
            }) { (error) in
                print("Error clearing memory - \(error)")
            }
            .disposed(by: disposeBag)

        storageManager
            .clearDiskStorage()
            .subscribe(onCompleted: {
                print("Cleared disk storage")
            }) { (error) in
                print("Error clearing disk storage - \(error)")
            }
            .disposed(by: disposeBag)
    }

    // Ability to write to memory
    func testMemoryWrite() {
        let someData = "text".data(using: .utf8)!
        let asset = KBAsset(uuid: "myData", data: someData)
        let options = KBParameters()
        options.writeOptions = .memory

        let expect = expectation(description: "testMemoryWrite")
        storageManager
            .store(asset, options: options)
            .subscribe(onCompleted: {
                expect.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    // Ability to write to disk
    func testDiskWrite() {
        let someData = "text".data(using: .utf8)!
        let asset = KBAsset(uuid: "myData", data: someData)
        let options = KBParameters()
        options.writeOptions = .disk

        let expect = expectation(description: "testDiskWrite")
        storageManager
            .store(asset, options: options)
            .subscribe(onCompleted: {
                expect.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    // Ability to write and read from memory
    func testMemoryRead() {
        let someData = "text".data(using: .utf8)!
        let asset = KBAsset(uuid: "myData", data: someData)
        let options = KBParameters()
        options.writeOptions = .memory

        let writeExpectation = expectation(description: "testMemoryWrite")
        storageManager
            .store(asset, options: options)
            .subscribe(onCompleted: {
                writeExpectation.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        let readExpectation = expectation(description: "testMemoryRead")
        storageManager
            .fetch("myData")
            .subscribe(onSuccess: { (asset) in
                XCTAssertEqual(asset.key, "myData")
                let dataString = String.init(data: asset.data, encoding: .utf8)
                XCTAssertEqual(dataString, "text")
                readExpectation.fulfill()
            }) { (error) in
                XCTFail(error.localizedDescription)
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    // Ability to write and read from disk
    func testDiskRead() {
        let someData = "text".data(using: .utf8)!
        let asset = KBAsset(uuid: "myData", data: someData)
        let options = KBParameters()
        options.writeOptions = .disk

        let writeExpectation = expectation(description: "testDiskWrite")
        storageManager
            .store(asset, options: options)
            .subscribe(onCompleted: {
                writeExpectation.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        let readExpectation = expectation(description: "testDiskRead")
        storageManager
            .fetch("myData")
            .subscribe(onSuccess: { (asset) in
                XCTAssertEqual(asset.key, "myData")
                let dataString = String.init(data: asset.data, encoding: .utf8)
                XCTAssertEqual(dataString, "text")
                readExpectation.fulfill()
            }) { (error) in
                XCTFail(error.localizedDescription)
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testClearMemory() {
        let someData = "text".data(using: .utf8)!
        let asset = KBAsset(uuid: "myData", data: someData)
        let options = KBParameters()
        options.writeOptions = .memory

        let writeExpectation = expectation(description: "testClearMemoryWrite")
        storageManager
            .store(asset, options: options)
            .subscribe(onCompleted: {
                writeExpectation.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        let readExpectation = expectation(description: "testClearMemoryRead")
        storageManager
            .fetch("myData")
            .subscribe(onSuccess: { (asset) in
                XCTAssertEqual(asset.key, "myData")
                readExpectation.fulfill()
            }) { (error) in
                XCTFail(error.localizedDescription)
            }
            .disposed(by: disposeBag)

        let clearMemoryExpection = expectation(description: "testClearMemoryDelete")
        storageManager
            .clearMemoryStorage()
            .subscribe(onCompleted: {
                clearMemoryExpection.fulfill()
            }) { (error) in
                XCTFail(error.localizedDescription)
            }
            .disposed(by: disposeBag)

        let errorExpectation = expectation(description: "testClearMemoryEmpty")
        storageManager
            .fetch("myData")
            .subscribe(onSuccess: { (asset) in
                XCTFail("Asset should be deleted")
            }) { (error) in
                XCTAssertEqual(error.localizedDescription, KBStorageError.notFound.localizedDescription)
                errorExpectation.fulfill()
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }
}
