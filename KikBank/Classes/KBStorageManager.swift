//
//  KBStorageManager.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import RxSwift

enum KBStorageError: Error, Equatable {
    case deallocated    // The storage manager has been deallocated
    case badPath        // Could not create a path to the asset
    case noWrite        // Invalid write operation specified
    case noRead         // Invalid read operation specified
    case notFound       // No asset found with that identifier
    case invalid        // The asset failed validation and has been deleted
    case optionalSkip   // An existing record is equal, no write required
    case generic(error: Error)

    static func ==(lhs: KBStorageError, rhs: KBStorageError) -> Bool {
        switch (lhs, rhs) {
        case (.deallocated, .deallocated):
            return true
        case (.badPath, .badPath):
            return true
        case (.noWrite, .noWrite):
            return true
        case (.noRead, .noRead):
            return true
        case (.notFound, .notFound):
            return true
        case (.invalid, .invalid):
            return true
        case (.optionalSkip, .optionalSkip):
            return true
        case (.generic, .generic):
            return true
        case (.deallocated, _),
             (.badPath, _),
             (.noWrite, _),
             (.noRead, _),
             (.notFound, _),
             (.invalid, _),
             (.optionalSkip, _),
             (.generic, _):
            return false
        }
    }
}

public protocol KBStorageManagerType {

    /// Store an asset based on provided storage policy
    ///
    /// - Parameters:
    ///   - asset: The asset to be stored
    ///   - writeOption: The write policy of the asset
    /// - Returns: A single observable sequence returning the saved asset
    func store(_ asset: KBAssetType, writeOption: KBWriteOption) -> Single<KBAssetType>


    /// Get any valid data defined by the provided identifier
    ///
    /// - Parameters
    ///     - identifier: The unique identifier of the asset, Int hash value
    ///     - readOptions: The read policy of the request
    /// - Returns: An asset matching the key and read options, if availiable
    func fetch(_ identifier: AnyHashable, readOption: KBReadOption) -> Single<KBAssetType>

    /// Reset the in memory storage
    ///
    func clearMemoryStorage() -> Completable

    /// Resets the storage
    /// Caution! This removes everything stored at the current content path
    /// The storage manager may be using a shared resoure location
    ///
    func clearDiskStorage() -> Completable

    /// The static logger
    ///
    var logger: KBLoggerType { get set }
}

/// Storage manager provides simple caching and disk storage solutions
public class KBStorageManager {

    /// Custom path for content storage
    private let cachePathExtension: String

    /// The in memory asset cache
    private lazy var memoryCache = [Int: Data]()

    /// Delete operation queue
    private lazy var deleteSubject = PublishSubject<KBAssetType>()
    
    private lazy var disposeBag = DisposeBag()

    public lazy var logger: KBLoggerType = KBLogger()

    /// Convenience accessor of the disk file location
    private lazy var contentURL: URL? = {
        let fileManager = FileManager.default

        do {
            let documentsPath = try fileManager.url(for: .cachesDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: nil,
                                                    create: false)
            return documentsPath.appendingPathComponent(self.cachePathExtension)
        } catch {
            return nil
        }
    }()
    
    public required init(pathExtension: String) {
        cachePathExtension = pathExtension
        bind()
    }

    /// Attach all observables
    private func bind() {
        deleteSubject
            .subscribe(onNext: { [weak self] (asset) in
                guard let this = self else {
                    return
                }

                this.runDeleteMemoryAction(with: asset)
                this.runDeleteDiskAction(with: asset)
            })
            .disposed(by: disposeBag)
    }

    /// Enqueues then runs an asset memory delete action
    ///
    private func runDeleteMemoryAction(with asset: KBAssetType) {
        deleteAssetFromMemory(asset)
            .subscribe()
            .disposed(by: disposeBag)
    }

    /// Enqueues then runs an asset disk delete action
    ///
    private func runDeleteDiskAction(with asset: KBAssetType) {
        deleteAssetFromDisk(asset)
            .subscribe()
            .disposed(by: disposeBag)
    }

    /// Checks for a stored asset matching the povided identifier
    ///
    /// - Parameter key: The unique identifier of the asset
    /// - Returns: Valid asset, if possible
    private func fetchContent(with identifier: AnyHashable, readOption: KBReadOption) -> Single<KBAssetType> {
        // Check for restricted read types
        if readOption == .network {
            // Nothing to do
            return Single.error(KBStorageError.noRead)
        }

        var readOperation: Single<KBAssetType>?

        if readOption == .memory {
            // Only read from memory
            readOperation = readAssetFromMemory(with: identifier)
        } else if readOption == .disk {
            // Only read from disk
            readOperation = readAssetFromDisk(with: identifier)
        } else if readOption.contains(.memory) && readOption.contains(.disk) {
            // Read memory and then disk if needed
            readOperation = readAssetFromMemory(with: identifier)
                .catchError({ [weak self] (error) -> Single<KBAssetType> in
                    guard let this = self else {
                        return .error(KBStorageError.deallocated)
                    }

                    // Could not read from memory, check disk
                    return this.readAssetFromDisk(with: identifier)
                })
        }

        guard let _readOperation = readOperation else {
            return .error(KBStorageError.noRead)
        }

        // Return the selected read operation, and run a validation check
        return _readOperation
            .flatMap({ [weak self] (asset) -> Single<KBAssetType> in
                guard let this = self else {
                    return .error(KBStorageError.deallocated)
                }

                if !asset.isValid {
                    // Our content is no longer valid, clear it
                    this.deleteSubject.onNext(asset)
                    // Nothing to return
                    return .error(KBStorageError.invalid)
                }

                return .just(asset)
            })
    }

    /// Read an asset defined by a unique identifier from in-memory cache
    ///
    /// - Parameter key: The unique identifier of the data
    /// - Returns: An asset matching the provided key, if one exists
    private func readAssetFromMemory(with identifier: AnyHashable) -> Single<KBAssetType> {
        return Single
            .create(subscribe: { [weak self] (single) -> Disposable in
                guard let this = self else {
                    single(.error(KBStorageError.deallocated))
                    return Disposables.create()
                }

                guard
                    let assetData = this.memoryCache[identifier.hashValue],
                    let asset = NSKeyedUnarchiver.unarchiveObject(with: assetData) as? KBAssetType else {
                        single(.error(KBStorageError.notFound))
                        return Disposables.create()
                }


                this.logger.log(verbose: "KBStorageManager - Read - Memory - \(identifier)")

                single(.success(asset))

                return Disposables.create()
            })
    }

    /// Reads an asset defined by a unique identifier from disk if available
    ///
    /// - Parameter key: The unique identifier of the data
    /// - Returns: An asset matching the provided key, if one exists
    private func readAssetFromDisk(with identifier: AnyHashable) -> Single<KBAssetType> {
        return Single
            .create(subscribe: { [weak self] (single) -> Disposable in
                guard let this = self else {
                    single(.error(KBStorageError.deallocated))
                    return Disposables.create()
                }

                guard let pathURL = this.contentURL?.appendingPathComponent(identifier.description) else {
                    single(.error(KBStorageError.badPath))
                    return Disposables.create()
                }

                guard let unarchived = NSKeyedUnarchiver.unarchiveObject(withFile: pathURL.path) as? KBAssetType else {
                    single(.error(KBStorageError.notFound))
                    return Disposables.create()
                }

                this.logger.log(verbose: "KBStorageManager - Read - Disk - \(identifier)")

                single(.success(unarchived))

                return Disposables.create()
            })
    }

    /// Check for an existing matching record, and if none exists write it to memory
    ///
    /// - Parameter asset: The asset the be optionally writted to memory
    private func optionallyWriteToMemory(_ asset: KBAssetType) -> Single<KBAssetType> {
        // Do a read to see if we have an exisiting record
        return readAssetFromMemory(with: asset.identifier)
            .flatMap({ (existingAsset) -> Single<KBAssetType> in
                // A record was found, check if it is equal to the write operation
                if existingAsset.isEqual(asset) {
                    // Skip the write
                    return .error(KBStorageError.optionalSkip)
                }

                return .just(asset)
            })
            .catchError({ [weak self] (error) -> Single<KBAssetType> in
                guard let this = self else {
                    return .error(KBStorageError.deallocated)
                }

                if (error as? KBStorageError) == KBStorageError.notFound {
                    // No record found, a write is needed
                    return this.writeToMemory(asset)
                }

                // Otherwise, we propagate the error
                return .error(error)
            })
    }

    /// Write the provided asset to memory
    ///
    /// - Parameter asset: The asset the be writted to memory
    private func writeToMemory(_ asset: KBAssetType) -> Single<KBAssetType> {
        return Single
            .create(subscribe: { [weak self] (single) -> Disposable in
                guard let this = self else {
                    single(.error(KBStorageError.deallocated))
                    return Disposables.create()
                }

                let assetData = NSKeyedArchiver.archivedData(withRootObject: asset)
                this.memoryCache[asset.identifier] = assetData

                this.logger.log(verbose: "KBStorageManager - Write - Memory - \(asset.identifier)")

                single(.success(asset))

                return Disposables.create()
            })
    }

    /// Check for an existing matching record, and if none exists write it to disk
    ///
    /// - Parameter asset: The asset the be optionally writted to disk
    private func optionallyWriteToDisk(_ asset: KBAssetType) -> Single<KBAssetType> {
        // Do a read to see if we have an exisiting record
        return readAssetFromDisk(with: asset.identifier)
            .flatMap({ (existingAsset) -> Single<KBAssetType> in
                // A record was found, check if it is equal to the write operation
                if existingAsset.isEqual(asset) {
                    // Skip the write
                    return .error(KBStorageError.optionalSkip)
                }

                return .just(asset)
            })
            .catchError({ [weak self] (error) -> Single<KBAssetType> in
                guard let this = self else {
                    return .error(KBStorageError.deallocated)
                }

                if (error as? KBStorageError) == KBStorageError.notFound {
                    // No record found, a write is needed
                    return this.writeToDisk(asset)
                }

                // Otherwise, we propagate the error
                return .error(error)
            })
    }


    /// Write the provided asset to disk
    ///
    /// - Parameter asset: The asset to be written to disk
    private func writeToDisk(_ asset: KBAssetType) -> Single<KBAssetType> {
        return Single
            .create(subscribe: { [weak self] (single) -> Disposable in
                guard let this = self else {
                    single(.error(KBStorageError.deallocated))
                    return Disposables.create {}
                }

                guard let contentURL = this.contentURL else {
                    single(.error(KBStorageError.badPath))
                    return Disposables.create()
                }

                let pathURL = contentURL.appendingPathComponent(asset.identifier.description)

                do {
                    if !FileManager.default.fileExists(atPath: contentURL.path) {
                        try FileManager.default.createDirectory(at: contentURL,
                                                                withIntermediateDirectories: true,
                                                                attributes: nil)
                    }

                    let data = NSKeyedArchiver.archivedData(withRootObject: asset)
                    try data.write(to: pathURL, options: .atomic)

                    this.logger.log(verbose: "KBStorageManager - Write - Disk - \(asset.identifier)")

                    single(.success(asset))
                } catch {
                    this.logger.log(error: "KBStorageManager - Write - Disk - Error - \(error)")

                    single(.error(KBStorageError.generic(error: error)))
                }

                return Disposables.create()
            })
    }

    /// Deletes the provided asset from memory storage
    ///
    /// - Parameter asset: The asset to be removed from memory
    private func deleteAssetFromMemory(_ asset: KBAssetType) -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create()
                }

                this.logger.log(verbose: "KBStorageManager - Delete - Memory - \(asset.identifier)")

                this.memoryCache[asset.identifier] = nil

                completable(.completed)

                return Disposables.create()
            })
    }

    /// Deletes the provided asset from disk storage
    ///
    /// - Parameter asset: The asset to be removed from disk
    private func deleteAssetFromDisk(_ asset: KBAssetType) -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create()
                }

                guard let pathURL = this.contentURL?.appendingPathComponent(asset.identifier.description) else {
                    completable(.error(KBStorageError.badPath))
                    return Disposables.create()
                }

                if FileManager.default.fileExists(atPath: pathURL.path) {
                    do {
                        try FileManager.default.removeItem(at: pathURL)
                        this.logger.log(verbose: "KBStorageManager - Delete - Disk - \(asset.identifier)")

                        completable(.completed)
                    } catch {
                        this.logger.log(error: "KBStorageManager - Delete - Disk - Error - \(asset.identifier)")

                        completable(.error(KBStorageError.generic(error: error)))
                    }
                } else {
                    completable(.error(KBStorageError.notFound))
                }

                return Disposables.create()
            })
    }
}

extension KBStorageManager: KBStorageManagerType {

    public func store(_ asset: KBAssetType, writeOption: KBWriteOption) -> Single<KBAssetType> {
        // Keep track of any optional skip errors. In the event that one operation skips
        // while the other completes we do not return a skip error
        let isDiskWrite = writeOption.contains(.disk)
        let isOptionalDiskWrite = writeOption.contains(.disk) && writeOption.contains(.optional)
        var didSkipDiskWrite = false

        let isMemoryWrite = writeOption.contains(.memory)
        let isOptionalMemoryWrite = writeOption.contains(.memory) && writeOption.contains(.optional)
        var didSkipMemoryWrite = false

        return Single
            .just(asset)
            .flatMap { [weak self] (_) -> Single<KBAssetType> in
                // Disk operations
                guard let this = self else {
                    return Single.error(KBStorageError.deallocated)
                }

                if isOptionalDiskWrite {
                    return this.optionallyWriteToDisk(asset)
                }

                if isDiskWrite {
                    return this.writeToDisk(asset)
                }

                return Single.just(asset)
            }
            .catchError { (error) -> Single<KBAssetType> in
                // Disk error handling
                // In the event that we have a memory write, we will just keep track of this error
                if (error as? KBStorageError) == KBStorageError.optionalSkip && isOptionalDiskWrite {
                    didSkipDiskWrite = true
                }

                // Even with an error, if there is memory work we should do it
                if isMemoryWrite {
                    return .just(asset)
                }

                // If it is not a skip issue, we propagate the error
                return .error(error)
            }
            .flatMap { [weak self] (_) -> Single<KBAssetType> in
                // Memory operations
                guard let this = self else {
                    return Single.error(KBStorageError.deallocated)
                }

                if isOptionalMemoryWrite {
                    return this.optionallyWriteToMemory(asset)
                }

                if isMemoryWrite {
                    return this.writeToMemory(asset)
                }

                return Single.just(asset)
            }
            .catchError { (error) -> Single<KBAssetType> in
                // Memory error handling and final state checks
                // In the event we did an optional memory write, and did not end up writing
                if (error as? KBStorageError) == KBStorageError.optionalSkip && isOptionalMemoryWrite {
                    didSkipMemoryWrite = true
                }

                // Handle the final error cases
                // In the event both memory and disk writes were optionally skipped
                if didSkipDiskWrite && didSkipMemoryWrite {
                    // We return a global error
                    return .error(KBStorageError.optionalSkip)
                }

                // In the event we skipped a disk write
                if didSkipDiskWrite {
                    // It is considered a valid operation if there was also a memory write
                    if isMemoryWrite && !didSkipMemoryWrite {
                        return .just(asset)
                    }
                }

                // Same is true for the inverse
                if didSkipMemoryWrite {
                    if isDiskWrite && !didSkipDiskWrite {
                        return .just(asset)
                    }
                }

                // Otherwise, we propagate the error
                return .error(error)
        }
    }

    public func fetch(_ identifier: AnyHashable, readOption: KBReadOption) -> Single<KBAssetType> {
        return fetchContent(with: identifier, readOption: readOption)
    }

    public func clearMemoryStorage() -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create()
                }

                this.memoryCache = [Int: Data]()

                this.logger.log(verbose: "KBStorageManager - Delete - Memory - All")

                completable(.completed)

                return Disposables.create()
            })
    }

    public func clearDiskStorage() -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create()
                }

                guard let pathURL = this.contentURL else {
                    completable(.error(KBStorageError.badPath))
                    return Disposables.create()
                }

                do {
                    let directoryContents = try FileManager.default.contentsOfDirectory(atPath: pathURL.path)
                    for path in directoryContents {
                        let fullPath = pathURL.appendingPathComponent(path)
                        try FileManager.default.removeItem(atPath: fullPath.path)
                    }
                    this.logger.log(verbose: "KBStorageManager - Delete - Disk - All")

                    completable(.completed)
                } catch {
                    this.logger.log(error: "KBStorageManager - Delete - Disk - Error - \(error)")

                    completable(.error(KBStorageError.generic(error: error)))
                }

                return Disposables.create()
            })
    }
}
