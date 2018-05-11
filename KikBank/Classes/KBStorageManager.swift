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
    case noWrite
    case notFound
    case invalid
    case generic(error: Error)
}

public protocol KBStorageManagerType {

    /// Store the provded data based on provided storage policy
    ///
    /// - Parameters:
    ///   - asset: The asset to be stored
    ///   - writeOptions: The write policy of the asset
    /// - Returns: A completable indicating the write operation finished
    func store(_ asset: KBAssetType, writeOptions: KBWriteOtions) -> Completable


    /// Get any valid data defined by the provided uuid
    ///
    /// - Parameters
    ///     - key: The unique identifier of the asset
    ///     - readOptions: The read policy of the request
    /// - Returns: An asset matching the key and read options, if availiable
    func fetch(_ key: String, readOptions: KBReadOptions) -> Single<KBAssetType>

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
    var logger: KBStaticLoggerType.Type { get set }
}

/// Storage manager provides simple caching and disk storage solutions
public class KBStorageManager {

    private struct Constants {
        static let operationSchedulerName = "kbStorageManager.serialQueue"
    }

    /// Custom path for content storage
    private let cachePathExtension: String

    /// The in memory asset cache
    private lazy var memoryCache = [String: KBAssetType]()

    /// Delete operation queue
    private lazy var deleteSubject = PublishSubject<KBAssetType>()
    private lazy var disposeBag = DisposeBag()

    private lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private lazy var operationScheduler = OperationQueueScheduler(operationQueue: operationQueue)

    public lazy var logger: KBStaticLoggerType.Type = KBStaticLogger.self

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
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
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
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
            .subscribe(onCompleted: { [weak self] in
                guard let this = self else {
                    return
                }

                this.logger.log(verbose: "Done")
            }) { [weak self] (error) in
                guard let this = self else {
                    return
                }

                this.logger.log(error: "Error \(error)")
            }
            .disposed(by: disposeBag)
    }

    /// Enqueues then runs an asset disk delete action
    ///
    private func runDeleteDiskAction(with asset: KBAssetType) {
        deleteAssetFromDisk(asset)
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
            .subscribe(onCompleted: { [weak self] in
                guard let this = self else {
                    return
                }

                this.logger.log(verbose: "Done")
            }) { [weak self] (error) in
                guard let this = self else {
                    return
                }

                this.logger.log(error: "Error \(error)")
            }
            .disposed(by: disposeBag)
    }

    /// Checks for a stored asset matching the povided uuid
    ///
    /// - Parameter uuid: The unique identifier of the asset
    /// - Returns: Valid asset, if possible
    private func fetchContent(with key: String, readOptions: KBReadOptions) -> Single<KBAssetType> {
        return readAssetFromMemory(with: key)
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
            .catchError({ [weak self] (error) -> Single<KBAssetType> in
                guard let this = self else {
                    return .error(KBStorageError.deallocated)
                }

                return this.readAssetFomDisk(with: key)
            })
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
    private func readAssetFromMemory(with key: String) -> Single<KBAssetType> {
        return Single
            .create(subscribe: { [weak self] (single) -> Disposable in
                guard let this = self else {
                    single(.error(KBStorageError.deallocated))
                    return Disposables.create {}
                }

                guard let asset = this.memoryCache[key] else {
                    single(.error(KBStorageError.notFound))
                    return Disposables.create {}
                }

                this.logger.log(verbose: "KBStorageManager - Read - Memory - \(key)")

                single(.success(asset))
                return Disposables.create {}
            })
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
    }

    /// Reads an asset defined by a unique idenentifier from disk if available
    ///
    /// - Parameter key: The unique identifier of the data
    /// - Returns: An asset matching the provided key, if one exists
    private func readAssetFomDisk(with key: String) -> Single<KBAssetType> {
        return Single
            .create(subscribe: { [weak self] (single) -> Disposable in
                guard let this = self else {
                    single(.error(KBStorageError.deallocated))
                    return Disposables.create {}
                }

                guard let pathURL = this.contentURL?.appendingPathComponent(key) else {
                    single(.error(KBStorageError.badPath))
                    return Disposables.create {}
                }

                guard let unarchived = NSKeyedUnarchiver.unarchiveObject(withFile: pathURL.path) as? KBAssetType else {
                    single(.error(KBStorageError.notFound))
                    return Disposables.create {}
                }

                this.logger.log(verbose: "KBStorageManager - Read - Disk - \(key)")

                single(.success(unarchived))
                return Disposables.create {}
            })
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
    }

    /// Write the provided asset to memory
    ///
    /// - Parameter asset: The asset the be writted to memory
    private func writeToMemory(_ asset: KBAssetType) -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create {}
                }

                this.logger.log(verbose: "KBStorageManager - Write - Memory - \(asset.key)")
                this.memoryCache[asset.key] = asset

                completable(.completed)
                return Disposables.create {}
            })
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
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
                    return Disposables.create {}
                }

                let pathURL = contentURL.appendingPathComponent(asset.key)

                do {
                    if !FileManager.default.fileExists(atPath: contentURL.path) {
                        try FileManager.default.createDirectory(at: contentURL,
                                                                withIntermediateDirectories: true,
                                                                attributes: nil)
                    }

                    let data = NSKeyedArchiver.archivedData(withRootObject: asset)
                    try data.write(to: pathURL, options: .atomic)

                    this.logger.log(verbose: "KBStorageManager - Write - Disk - \(asset.key)")

                    completable(.completed)

                } catch {
                    this.logger.log(error: "KBStorageManager - Write - Disk - Error - \(error)")
                    completable(.error(KBStorageError.generic(error: error)))
                }

                return Disposables.create {}
            })
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
    }

    /// Deletes the provided asset from memory storageg
    ///
    /// - Parameter asset: The asset to be removed from memory
    private func deleteAssetFromMemory(_ asset: KBAssetType) -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create {}
                }

                this.logger.log(verbose: "KBStorageManager - Delete - Memory - \(asset.key)")

                this.memoryCache[asset.key] = nil

                completable(.completed)
                return Disposables.create {}
            })
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
    }

    /// Deletes the provided asset from disk storageg
    ///
    /// - Parameter asset: The asset to be removed from disk
    private func deleteAssetFromDisk(_ asset: KBAssetType) -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create {}
                }

                guard let pathURL = this.contentURL?.appendingPathComponent(asset.key) else {
                    completable(.error(KBStorageError.badPath))
                    return Disposables.create {}
                }

                if FileManager.default.fileExists(atPath: pathURL.path) {
                    do {
                        try FileManager.default.removeItem(at: pathURL)
                        this.logger.log(verbose: "KBStorageManager - Delete - Disk - \(asset.key)")
                        completable(.completed)
                    } catch {
                        this.logger.log(error: "KBStorageManager - Delete - Disk - Error - \(asset.key)")
                        completable(.error(KBStorageError.generic(error: error)))
                    }
                } else {
                    completable(.error(KBStorageError.notFound))
                }

                return Disposables.create {}
            })
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
    }
}

extension KBStorageManager: KBStorageManagerType {

    public func store(_ asset: KBAssetType, writeOptions: KBWriteOtions) -> Completable {
        var completable = Completable
            .empty()
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)

        if writeOptions.contains(.disk) {
            completable = completable.andThen(writeToDisk(asset))
        }

        if writeOptions.contains(.memory) {
            completable = completable.andThen(writeToMemory(asset))
        }

        return completable
    }

    public func fetch(_ key: String, readOptions: KBReadOptions) -> Single<KBAssetType> {
        return fetchContent(with: key, readOptions: readOptions)
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
    }

    public func clearMemoryStorage() -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create {}
                }

                this.memoryCache = [String: KBAssetType]()
                this.logger.log(verbose: "KBStorageManager - Delete - Memory - All")

                completable(.completed)
                return Disposables.create {}
            })
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
    }

    public func clearDiskStorage() -> Completable {
        return Completable
            .create(subscribe: { [weak self] (completable) -> Disposable in
                guard let this = self else {
                    completable(.error(KBStorageError.deallocated))
                    return Disposables.create {}
                }

                guard let pathURL = this.contentURL else {
                    completable(.error(KBStorageError.badPath))
                    return Disposables.create {}
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

                return Disposables.create {}
            })
            .subscribeOn(operationScheduler)
            .observeOn(operationScheduler)
    }
}
