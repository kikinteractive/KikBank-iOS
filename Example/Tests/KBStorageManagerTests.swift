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
            .subscribe()
            .disposed(by: disposeBag)

        storageManager
            .clearDiskStorage()
            .subscribe()
            .disposed(by: disposeBag)
    }

    // Ability to write to memory
    func testMemoryWrite() {
        let someData = "text".data(using: .utf8)!
        let asset = KBDataAsset(identifier: "testMemoryWrite".hashValue, data: someData)

        let expect = expectation(description: "testMemoryWrite")
        storageManager
            .store(asset, writeOption: .memory)
            .subscribe(onSuccess: { (_) in
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
            .subscribe(onSuccess: { (_) in
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
            .subscribe(onSuccess: { (_) in
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
            .subscribe(onSuccess: { (_) in
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

    // Ability to write to cache and then read from disk
    func testCacheThenDiskRead() {
        let someData = "text".data(using: .utf8)!
        let identifier = "testDiskRead".hashValue
        let asset = KBDataAsset(identifier: identifier, data: someData)

        let writeExpectation = expectation(description: "write")
        storageManager
            .store(asset, writeOption: .cache)
            .subscribe(onSuccess: { (_) in
                writeExpectation.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        let readExpectation = expectation(description: "read")
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

    // Ability to write to disk and then read from cache
    func testDiskThenCacheRead() {
        let someData = "text".data(using: .utf8)!
        let identifier = "testDiskRead".hashValue
        let asset = KBDataAsset(identifier: identifier, data: someData)

        let writeExpectation = expectation(description: "write")
        storageManager
            .store(asset, writeOption: .disk)
            .subscribe(onSuccess: { (_) in
                writeExpectation.fulfill()
            }) { (error) in
                XCTFail()
            }
            .disposed(by: disposeBag)

        let readExpectation = expectation(description: "read")
        storageManager
            .fetch(identifier, readOption: .cache)
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

    // Clearing data
    func testClearMemory() {
        let someData = "text".data(using: .utf8)!
        let identifier = "testClearMemory".hashValue
        let asset = KBDataAsset(identifier: identifier, data: someData)

        let writeExpectation = expectation(description: "testClearMemoryWrite")
        storageManager
            .store(asset, writeOption: .memory)
            .subscribe(onSuccess: { (_) in
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
                XCTAssertEqual(error as? KBStorageError, KBStorageError.notFound)
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
            .subscribe(onSuccess: { (_) in
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

    // Asset Expiry
    func testAssetExpiry() {
        let someData = "text".data(using: .utf8)!
        let identifier = "testAssetExpiry".hashValue
        let asset = KBDataAsset(identifier: identifier, data: someData)

        // Set the expiry date to be in half a second
        asset.expiryDate = Date(timeIntervalSinceNow: 0.5)

        let writeExpectation = expectation(description: "testAssetExpiryWrite")
        storageManager
            .store(asset, writeOption: .memory)
            .subscribe(onSuccess: { (_) in
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

    // Optionality
    func testOptionalMemoryWrite() {
        let someData = "text".data(using: .utf8)!
        let asset = KBDataAsset(identifier: "testOptionalMemoryWrite".hashValue, data: someData)

        let expectWrite = expectation(description: "testOptionalMemoryWrite")
        storageManager
            .store(asset, writeOption: [.memory, .optional])
            .subscribe(onSuccess: { (_) in
                expectWrite.fulfill()
            }) { (error) in
                XCTFail("Could not write to memory")
            }
            .disposed(by: disposeBag)

        let expectSkip = expectation(description: "testOptionalMemorySkip")
        storageManager
            .store(asset, writeOption: [.memory, .optional])
            .subscribe(onSuccess: { (_) in
                XCTFail("Should not have written to memory")
            }) { (error) in
                XCTAssertEqual(error as? KBStorageError, KBStorageError.optionalSkip)
                expectSkip.fulfill()
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testOptionalDiskWrite() {
        let someData = "text".data(using: .utf8)!
        let asset = KBDataAsset(identifier: "testOptionalDiskWrite".hashValue, data: someData)

        let expectWrite = expectation(description: "testOptionalDiskWrite")
        storageManager
            .store(asset, writeOption: [.disk, .optional])
            .subscribe(onSuccess: { (_) in
                expectWrite.fulfill()
            }) { (error) in
                XCTFail("Could not write to disk")
            }
            .disposed(by: disposeBag)

        let expectSkip = expectation(description: "testOptionalDiskSkip")
        storageManager
            .store(asset, writeOption: [.disk, .optional])
            .subscribe(onSuccess: { (_) in
                XCTFail("Should not have written to disk")
            }) { (error) in
                XCTAssertEqual(error as? KBStorageError, KBStorageError.optionalSkip)
                expectSkip.fulfill()
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testSecondayNonOptionalMemoryWrite() {
        // Writing to memory once, and then trying again optionally should return .optionalSkip
        // But writing to memory the second time non-optionally should overwrite existing record and return successful
        let someData = "text".data(using: .utf8)!
        let asset = KBDataAsset(identifier: "testSecondayNonOptionalWrite".hashValue, data: someData)

        let expectWrite = expectation(description: "testSecondayNonOptionalWrite")
        storageManager
            .store(asset, writeOption: [.memory, .optional])
            .subscribe(onSuccess: { (_) in
                expectWrite.fulfill()
            }) { (error) in
                XCTFail("Could not write to memory")
            }
            .disposed(by: disposeBag)

        let expectSecondWrite = expectation(description: "testSecondayNonOptionalSecondWrite")
        storageManager
            .store(asset, writeOption: [.memory])
            .subscribe(onSuccess: { (_) in
                expectSecondWrite.fulfill()
            }) { (error) in
                XCTFail("Should have written to memory")
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testSecondayNonOptionalDiskWrite() {
        // Writing to disk once, and then trying again optionally should return .optionalSkip
        // But writing to disk the second time non-optionally should overwrite existing record and return successful
        let someData = "text".data(using: .utf8)!
        let asset = KBDataAsset(identifier: "testSecondayNonOptionalDiskWrite".hashValue, data: someData)

        let expectWrite = expectation(description: "testSecondayNonOptionalDiskWrite")
        storageManager
            .store(asset, writeOption: [.disk, .optional])
            .subscribe(onSuccess: { (_) in
                expectWrite.fulfill()
            }) { (error) in
                XCTFail("Could not write to disk")
            }
            .disposed(by: disposeBag)

        let expectSecondWrite = expectation(description: "testSecondayNonOptionalDiskSecondWrite")
        storageManager
            .store(asset, writeOption: [.disk])
            .subscribe(onSuccess: { (_) in
                expectSecondWrite.fulfill()
            }) { (error) in
                XCTFail("Should have written to disk")
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testDiskOptionalWriteAfterMemoryWrite() {
        // Writing to memory, and then writing to memory AND disk optionally
        // Should return successful
        let someData = "text".data(using: .utf8)!
        let asset = KBDataAsset(identifier: "testDiskOptionalWriteAfterMemoryWrite".hashValue, data: someData)

        let expectWrite = expectation(description: "testDiskOptionalWriteAfterMemoryWrite")
        storageManager
            .store(asset, writeOption: [.memory])
            .subscribe(onSuccess: { (_) in
                expectWrite.fulfill()
            }) { (error) in
                XCTFail("Could not write to disk")
            }
            .disposed(by: disposeBag)

        let expectSkip = expectation(description: "testDiskOptionalWriteAfterMemoryWriteSecond")
        storageManager
            .store(asset, writeOption: [.memory, .disk, .optional])
            .subscribe(onSuccess: { (_) in
                expectSkip.fulfill()
            }) { (error) in
                XCTFail("Should have written to disk")
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testMemoryOptionalWriteAfterDiskWrite() {
        // Writing to memory, and then writing to memory AND disk optionally
        // Should return successful
        let someData = "text".data(using: .utf8)!
        let asset = KBDataAsset(identifier: "testMemoryOptionalWriteAfterDiskWrite".hashValue, data: someData)

        let expectWrite = expectation(description: "testMemoryOptionalWriteAfterDiskWrite")
        storageManager
            .store(asset, writeOption: [.disk])
            .subscribe(onSuccess: { (_) in
                expectWrite.fulfill()
            }) { (error) in
                XCTFail("Could not write to disk")
            }
            .disposed(by: disposeBag)

        let expectSkip = expectation(description: "testMemoryOptionalWriteAfterDiskWriteSecond")
        storageManager
            .store(asset, writeOption: [.memory, .disk, .optional])
            .subscribe(onSuccess: { (_) in
                expectSkip.fulfill()
            }) { (error) in
                XCTFail("Should have written to disk")
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testOptionalWriteNewData() {
        // Altering an assets data should force a rewrite
        let someData = "text".data(using: .utf8)!
        let asset = KBDataAsset(identifier: "testOptionalWriteNewData".hashValue, data: someData)

        let expectWrite = expectation(description: "testOptionalWriteNewData")
        storageManager
            .store(asset, writeOption: [.memory, .optional])
            .subscribe(onSuccess: { (_) in
                expectWrite.fulfill()
            }) { (error) in
                XCTFail("Could not write to memory")
            }
            .disposed(by: disposeBag)

        // Update the asset
        let newData = "differentText".data(using: .utf8)!
        asset.data = newData

        let expectSecondWrite = expectation(description: "testOptionalWriteNewDataOverwrite")
        storageManager
            .store(asset, writeOption: [.memory, .optional])
            .subscribe(onSuccess: { (_) in
                expectSecondWrite.fulfill()
            }) { (error) in
                XCTFail("Should have written to memory")
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testOptionalWriteNewExpiryDate() {
        // Altering an assets expiry date should force a rewrite
        let someData = "text".data(using: .utf8)!
        let asset = KBDataAsset(identifier: "testOptionalWriteNewExpiryDate".hashValue, data: someData)
        asset.expiryDate = Date().addingTimeInterval(10)

        let expectWrite = expectation(description: "testOptionalWriteNewExpiryDate")
        storageManager
            .store(asset, writeOption: [.memory, .optional])
            .subscribe(onSuccess: { (_) in
                expectWrite.fulfill()
            }) { (error) in
                XCTFail("Could not write to memory")
            }
            .disposed(by: disposeBag)

        // Update the asset
        asset.expiryDate = Date().addingTimeInterval(20)

        let expectSecondWrite = expectation(description: "testOptionalWriteNewExpiryDateOverwrite")
        storageManager
            .store(asset, writeOption: [.memory, .optional])
            .subscribe(onSuccess: { (_) in
                expectSecondWrite.fulfill()
            }) { (error) in
                XCTFail("Should have written to memory")
            }
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 0.5, handler: nil)
    }
}
