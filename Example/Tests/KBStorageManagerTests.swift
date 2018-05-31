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
                print("tearDown - Cleared memory")
            }) { (error) in
                print("tearDown - Error clearing memory - \(error)")
            }
            .disposed(by: disposeBag)

        storageManager
            .clearDiskStorage()
            .subscribe(onCompleted: {
                print("tearDown - Cleared disk storage")
            }) { (error) in
                print("tearDown - Error clearing disk storage - \(error)")
            }
            .disposed(by: disposeBag)
    }

    // Ability to write to memory
    func testMemoryWrite() {
        let someData = "text".data(using: .utf8)!
        let asset = KBDataAsset(identifier: "testMemoryWrite".hashValue, data: someData)

        let expect = expectation(description: "testMemoryWrite")
        storageManager
            .store(asset, writeOption: .memory)
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
        let asset = KBDataAsset(identifier: "testDiskWrite".hashValue, data: someData)

        let expect = expectation(description: "testDiskWrite")
        storageManager
            .store(asset, writeOption: .disk)
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
        let identifier = "testMemoryRead".hashValue
        let asset = KBDataAsset(identifier: identifier, data: someData)

        let writeExpectation = expectation(description: "testMemoryWrite")
        storageManager
            .store(asset, writeOption: .memory)
            .subscribe(onCompleted: {
                writeExpectation.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        let readExpectation = expectation(description: "testMemoryRead")
        storageManager
            .fetch(identifier, readOption: .memory)
            .subscribe(onSuccess: { (asset) in
                XCTAssertEqual(asset.identifier, identifier)
                let dataString = String.init(data: (asset as! KBDataAssetType).data, encoding: .utf8)
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
        let identifier = "testDiskRead".hashValue
        let asset = KBDataAsset(identifier: identifier, data: someData)

        let writeExpectation = expectation(description: "testDiskWrite")
        storageManager
            .store(asset, writeOption: .disk)
            .subscribe(onCompleted: {
                writeExpectation.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        let readExpectation = expectation(description: "testDiskRead")
        storageManager
            .fetch(identifier, readOption: .disk)
            .subscribe(onSuccess: { (asset) in
                XCTAssertEqual(asset.identifier, identifier)
                let dataString = String.init(data: (asset as! KBDataAssetType).data, encoding: .utf8)
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
        let identifier = "testClearMemory".hashValue
        let asset = KBDataAsset(identifier: identifier, data: someData)

        let writeExpectation = expectation(description: "testClearMemoryWrite")
        storageManager
            .store(asset, writeOption: .memory)
            .subscribe(onCompleted: {
                writeExpectation.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        let readExpectation = expectation(description: "testClearMemoryRead")
        storageManager
            .fetch(identifier, readOption: .memory)
            .subscribe(onSuccess: { (asset) in
                XCTAssertEqual(asset.identifier, identifier)
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
            .fetch(identifier, readOption: .memory)
            .subscribe(onSuccess: { (asset) in
                XCTFail("Asset should be deleted")
            }) { (error) in
                XCTAssertEqual(error.localizedDescription, KBStorageError.notFound.localizedDescription)
                errorExpectation.fulfill()
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testClearDisk() {
        let someData = "text".data(using: .utf8)!
        let identifier = "testClearDisk".hashValue
        let asset = KBDataAsset(identifier: identifier, data: someData)

        let writeExpectation = expectation(description: "testClearDiskWrite")
        storageManager
            .store(asset, writeOption: .disk)
            .subscribe(onCompleted: {
                writeExpectation.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        let readExpectation = expectation(description: "testClearDiskRead")
        storageManager
            .fetch(identifier, readOption: .disk)
            .subscribe(onSuccess: { (asset) in
                XCTAssertEqual(asset.identifier, identifier)
                readExpectation.fulfill()
            }) { (error) in
                XCTFail(error.localizedDescription)
            }
            .disposed(by: disposeBag)

        let clearMemoryExpection = expectation(description: "testClearDiskDelete")
        storageManager
            .clearDiskStorage()
            .subscribe(onCompleted: {
                clearMemoryExpection.fulfill()
            }) { (error) in
                XCTFail(error.localizedDescription)
            }
            .disposed(by: disposeBag)

        let errorExpectation = expectation(description: "testClearDiskEmpty")
        storageManager
            .fetch(identifier, readOption: .disk)
            .subscribe(onSuccess: { (asset) in
                XCTFail("Asset should be deleted")
            }) { (error) in
                XCTAssertEqual(error.localizedDescription, KBStorageError.notFound.localizedDescription)
                errorExpectation.fulfill()
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testAssetExpiry() {
        let someData = "text".data(using: .utf8)!
        let identifier = "testAssetExpiry".hashValue
        let asset = KBDataAsset(identifier: identifier, data: someData)

        // Set the expiry date to be in half a second
        asset.expiryDate = Date(timeIntervalSinceNow: 0.5)

        let writeExpectation = expectation(description: "testAssetExpiryWrite")
        storageManager
            .store(asset, writeOption: .memory)
            .subscribe(onCompleted: {
                writeExpectation.fulfill()
            }) { (error) in
                XCTFail(error.localizedDescription)
            }.disposed(by: disposeBag)

        // First read should be valid
        let readExpectation = expectation(description: "testAssetExpiryFirstRead")
        storageManager
            .fetch(identifier, readOption: .memory)
            .subscribe(onSuccess: { (asset) in
                readExpectation.fulfill()
            }) { (error) in
                XCTFail(error.localizedDescription)
            }
            .disposed(by: disposeBag)

        sleep(1)

        // Second read should return invalid
        let errorExpectation = expectation(description: "testAssetExpirySecondRead")
        storageManager
            .fetch(identifier, readOption: .memory)
            .subscribe(onSuccess: { (asset) in
                XCTFail("Asset should be deleted")
            }) { (error) in
                XCTAssertEqual(error.localizedDescription, KBStorageError.invalid.localizedDescription)
                errorExpectation.fulfill()
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 2, handler: nil)
    }
}
