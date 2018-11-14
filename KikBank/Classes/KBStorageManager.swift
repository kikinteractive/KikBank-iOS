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
    ///     - identifier: The unique identifier of the asset
    ///     - readOptions: The read policy of the request
    /// - Returns: An asset matching the key and read options, if availiable
    func fetch(_ identifier: String, readOption: KBReadOption) -> Single<KBAssetType>

    /// Deletes a single asset item from memory storage
    ///
    /// - Parameters
    ///     - identifier: The unique identifier of the asset
    /// - Returns: A single sequence of the asset item that was successfully deleted
    func deleteAssetFromMemory(_ identifier: String) -> Single<KBAssetType>

    /// Deletes a single asset item from disk storage
    ///
    /// - Parameters
    ///     - identifier: The unique identifier of the asset
    /// - Returns: A single sequence of the asset item that was successfully deleted
    func deleteAssetFromDisk(_ identifier: String) -> Single<KBAssetType>

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
    private lazy var memoryCache = [String: Data]()

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
        deleteAssetFromMemory(asset.identifier)
            .subscribe()
            .disposed(by: disposeBag)
    }

    /// Enqueues then runs an asset disk delete action
    ///
    private func runDeleteDiskAction(with asset: KBAssetType) {
        deleteAssetFromDisk(asset.identifier)
            .subscribe()
            .disposed(by: disposeBag)
    }

    /// Read an asset defined by a unique identifier from in-memory cache
    ///
    /// - Parameter key: The unique identifier of the data
    /// - Returns: An asset matching the provided key, if one exists
    private func readAssetFromMemory(with identifier: String) -> Single<KBAssetType> {
        return Single
            .create(subscribe: { [weak self] (single) -> Disposable in
                guard let this = self else {
                    single(.error(KBStorageError.deallocated))
                    return Disposables.create()
                }

                guard
                    let assetData = this.memoryCache[identifier],
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
    private func readAssetFromDisk(with identifier: String) -> Single<KBAssetType> {
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

    /// Writes an asset to memory dependant on supplied options
    ///
    /// - Parameter asset: The asset to be written to memory
    /// - Parameter options: The write option parameters
    private func writeToMemory(_ asset: KBAssetType, options: KBWriteOption) -> Single<KBAssetType> {
        guard options.contains(.memory) else {
            return Single.error(KBStorageError.noWrite)
        }

        guard options.contains(.optional) else {
            return writeToMemory(asset)
        }

        // Check for an existing record
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

    /// Writes an asset to memory
    ///
    /// - Paremeter asset: The asset to be written to memory
    private func writeToMemory(_ asset: KBAssetType) -> Single<KBAssetType> {
        let assetData = NSKeyedArchiver.archivedData(withRootObject: asset)
        memoryCache[asset.identifier] = assetData

        logger.log(verbose: "KBStorageManager - Write - Memory - \(asset.identifier)")

        return .just(asset)
    }

    /// Writes an asset to disk dependant on supplied options
    ///
    /// - Parameter asset: The asset to be written to disk
    /// - Parameter options: The write option parameters
    private func writeToDisk(_ asset: KBAssetType, options: KBWriteOption) -> Single<KBAssetType> {
        guard options.contains(.disk) else {
            return Single.error(KBStorageError.noWrite)
        }

        guard options.contains(.optional) else {
            return writeToDisk(asset)
        }

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

    /// Writes an asset to disk
    ///
    /// - Paremeter asset: The asset to be written to memory
    private func writeToDisk(_ asset: KBAssetType) -> Single<KBAssetType> {
        guard let contentURL = contentURL else {
            return Single.error(KBStorageError.badPath)
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

            logger.log(verbose: "KBStorageManager - Write - Disk - \(asset.identifier)")

            return .just(asset)
        } catch {
            logger.log(error: "KBStorageManager - Write - Disk - Error - \(error)")

            return .error(KBStorageError.generic(error: error))
        }
    }
}

extension KBStorageManager: KBStorageManagerType {
    
    public func store(_ asset: KBAssetType, writeOption: KBWriteOption) -> Single<KBAssetType> {
        var diskError: Error?
        var memoryError: Error?

        let diskWrite = writeToDisk(asset, options: writeOption)
            .catchError { (error) -> Single<KBAssetType> in
                diskError = error
                return .just(asset)
        }

        let memoryWrite = writeToMemory(asset, options: writeOption)
            .catchError { (error) -> Single<KBAssetType> in
                memoryError = error
                return .just(asset)
        }

        return Single
            .zip(diskWrite, memoryWrite) { return ($0, $1) }
            .flatMap({ (_, _) -> Single<KBAssetType> in
                // Handle error cases
                // If both disk and memory writes skipped
                if (diskError as? KBStorageError) == KBStorageError.optionalSkip
                    && (memoryError as? KBStorageError) == KBStorageError.optionalSkip {
                    // Return a global error state
                    return .error(KBStorageError.optionalSkip)
                }

                // If the disk write skipped
                if (diskError as? KBStorageError) == KBStorageError.optionalSkip {
                    // But we stil did a memory write
                    if writeOption.contains(.memory) && memoryError == nil {
                        // This is considered a valid write
                        return .just(asset)
                    }
                }

                // And vice versa
                // If the memory write skipped
                if (memoryError as? KBStorageError) == KBStorageError.optionalSkip {
                    // But we stil did a disk write
                    if writeOption.contains(.disk) && diskError == nil {
                        // This is considered a valid write
                        return .just(asset)
                    }
                }

                // Now we are in edge cases. If we have errors, propagate
                if let error = diskError, writeOption.contains(.disk) {
                    return .error(error)
                }

                if let error = memoryError, writeOption.contains(.memory) {
                    return .error(error)
                }

                return .just(asset)
            })
    }

    public func fetch(_ identifier: String, readOption: KBReadOption) -> Single<KBAssetType> {
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

    public func deleteAssetFromMemory(_ identifier: String) -> Single<KBAssetType> {
        return readAssetFromMemory(with: identifier)
            .flatMap({ [weak self] (asset) -> Single<KBAssetType> in
                guard let this = self else {
                    return Single.error(KBStorageError.deallocated)
                }

                this.logger.log(verbose: "KBStorageManager - Delete - Memory - \(asset.identifier)")

                this.memoryCache[asset.identifier] = nil

                return Single.just(asset)
            })
    }

    public func deleteAssetFromDisk(_ identifier: String) -> Single<KBAssetType> {
        return readAssetFromDisk(with: identifier)
            .flatMap({ [weak self] (asset) -> Single<KBAssetType> in
                guard let this = self else {
                    return Single.error(KBStorageError.deallocated)
                }

                guard let pathURL = this.contentURL?.appendingPathComponent(asset.identifier.description) else {
                    return Single.error(KBStorageError.badPath)
                }

                if FileManager.default.fileExists(atPath: pathURL.path) {
                    do {
                        try FileManager.default.removeItem(at: pathURL)

                        this.logger.log(verbose: "KBStorageManager - Delete - Disk - \(asset.identifier)")

                        return Single.just(asset)
                    } catch {
                        this.logger.log(error: "KBStorageManager - Delete - Disk - Error - \(asset.identifier)")

                        return Single.error(KBStorageError.generic(error: error))
                    }
                } else {
                    return Single.error(KBStorageError.notFound)
                }
            })
    }

    public func clearMemoryStorage() -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create()
                }

                this.memoryCache = [String: Data]()

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
