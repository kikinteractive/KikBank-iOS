//
//  KBStorageManager.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import RxSwift

enum KBStorageError: Error {
    case deallocated
    case badPath
    case noWrite // Invalid write operation specified
    case noRead // Invalid read operation specified
    case notFound
    case invalid
    case generic(error: Error)
}

public protocol KBStorageManagerType {

    /// Store an asset based on provided storage policy
    ///
    /// - Parameters:
    ///   - asset: The asset to be stored
    ///   - writeOption: The write policy of the asset
    /// - Returns: A completable indicating the write operation finished
    func store(_ asset: KBAssetType, writeOption: KBWriteOption) -> Completable


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
    private lazy var memoryCache = [Int: KBAssetType]()

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
            readOperation = readAssetFomDisk(with: identifier)
        } else if readOption.contains(.memory) && readOption.contains(.disk) {
            // Read memory and then disk if needed
            readOperation = readAssetFromMemory(with: identifier)
                .catchError({ [weak self] (error) -> Single<KBAssetType> in
                    guard let this = self else {
                        return .error(KBStorageError.deallocated)
                    }

                    // Could not read from memory, check disk
                    return this.readAssetFomDisk(with: identifier)
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

    /// Read an asset defined by a unique idenentifier from in-memory cache
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

                guard let asset = this.memoryCache[identifier.hashValue] else {
                    single(.error(KBStorageError.notFound))
                    return Disposables.create()
                }

                this.logger.log(verbose: "KBStorageManager - Read - Memory - \(identifier)")

                single(.success(asset))

                return Disposables.create()
            })
    }

    /// Reads an asset defined by a unique idenentifier from disk if available
    ///
    /// - Parameter key: The unique identifier of the data
    /// - Returns: An asset matching the provided key, if one exists
    private func readAssetFomDisk(with identifier: AnyHashable) -> Single<KBAssetType> {
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

    /// Write the provided asset to memory
    ///
    /// - Parameter asset: The asset the be writted to memory
    private func writeToMemory(_ asset: KBAssetType) -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create()
                }

                this.logger.log(verbose: "KBStorageManager - Write - Memory - \(asset.identifier)")

                this.memoryCache[asset.identifier] = asset

                completable(.completed)

                return Disposables.create()
            })
    }

    /// Write the provided asset to disk
    ///
    /// - Parameter asset: The asset to be written to disk
    private func writeToDisk(_ asset: KBAssetType) -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create {}
                }

                guard let contentURL = this.contentURL else {
                    completable(.error(KBStorageError.badPath))
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

                    completable(.completed)
                } catch {
                    this.logger.log(error: "KBStorageManager - Write - Disk - Error - \(error)")

                    completable(.error(KBStorageError.generic(error: error)))
                }

                return Disposables.create()
            })
    }

    /// Deletes the provided asset from memory storageg
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

    /// Deletes the provided asset from disk storageg
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

    public func store(_ asset: KBAssetType, writeOption: KBWriteOption) -> Completable {
        var completable = Completable.empty()

        if writeOption.contains(.disk) {
            completable = completable.andThen(writeToDisk(asset))
        }

        if writeOption.contains(.memory) {
            completable = completable.andThen(writeToMemory(asset))
        }

        return completable
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

                this.memoryCache = [Int: KBAssetType]()
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
