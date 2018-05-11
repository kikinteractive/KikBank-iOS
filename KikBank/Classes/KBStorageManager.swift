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
    case pathError
    case generic // TODO: not this
    case noWrite // No write policy has been set on
    case notFound
    case invalid
}

public protocol KBStorageManagerType {

    /// Store the provded data based on provided storage policy
    ///
    /// - Parameters:
    ///   - key: The unique identifier of the asset
    ///   - asset: The asset to be stored
    ///   - options: The write policy of the asset
    func store(_ key: String, asset: KBAssetType, options: KBParameters) -> Completable

    /// Get any valid data defined by the provided uuid
    ///
    /// - Parameter key: The unique identifier of the asset
    /// - Returns: Valid asset, if possible
    func fetch(_ key: String) -> Single<KBAssetType>

    /// Reset the in memory storage
    ///
    func clearMemoryStorage() -> Completable

    /// Resets the storage
    /// Caution! This removes all stored content at the current content path
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
        static let storageSchedulerName = "kbStorageManager.serialQueue"
    }

    /// Custom path for content storage
    private let cachePathExtension: String

    /// The in memory asset cache
    private lazy var memoryCache = [String: KBAssetType]()

    /// Delete operation queue
    private lazy var deleteSubject = PublishSubject<KBAssetType>()
    private lazy var disposeBag = DisposeBag()
    private lazy var storageScheduler = SerialDispatchQueueScheduler(internalSerialQueueName: Constants.storageSchedulerName)

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
            .subscribe(onNext: { [weak self] (asset) in
                guard let this = self else {
                    return
                }

                this.runDeleteMemoryAction(with: asset)
                this.runDeleteDiskAction(with: asset)
            })
            .disposed(by: disposeBag)
    }

    private func runDeleteMemoryAction(with asset: KBAssetType) {
        deleteAssetFromMemory(asset)
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
            }.disposed(by: disposeBag)
    }

    private func runDeleteDiskAction(with asset: KBAssetType) {
        deleteAssetFromDisk(asset)
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
            }.disposed(by: disposeBag)
    }

    /// Checks for a stored asset matching the povided uuid
    ///
    /// - Parameter uuid: The unique identifier of the asset
    /// - Returns: Valid asset, if possible
    private func fetchContent(with key: String) -> Single<KBAssetType> {
        return readAssetFromMemory(with: key)
            .catchError({ [weak self] (error) -> Single<KBAssetType> in
                guard let this = self else {
                    return .error(KBStorageError.deallocated)
                }

                return this.readAssetFomDisk(with: key)
            }).flatMap({ [weak self] (asset) -> Single<KBAssetType> in
                guard let expirableAsset = asset as? KBExpirableEntityType else {
                    return .just(asset)
                }

                guard let this = self else {
                    return .error(KBStorageError.deallocated)
                }

                if !expirableAsset.isValid {
                    // Our content is no longer valid, clear it
                    this.deleteSubject.onNext(asset)
                    // Nothing to return
                    return .error(KBStorageError.invalid)
                }

                return .just(asset)
            }).subscribeOn(storageScheduler)
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

                single(.success(asset))

                return Disposables.create {}
            })
            .subscribeOn(storageScheduler)
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
                    single(.error(KBStorageError.pathError))
                    return Disposables.create {}
                }

                guard let unarchived = NSKeyedUnarchiver.unarchiveObject(withFile: pathURL.path) as? KBAssetType else {
                    single(.error(KBStorageError.notFound))
                    return Disposables.create {}
                }

                single(.success(unarchived))

                return Disposables.create {}
            })
            .subscribeOn(storageScheduler)
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

                this.logger.log(verbose: "KBStorageManager - Writing to Memory - \(asset.key)")
                this.memoryCache[asset.key] = asset

                completable(.completed)

                return Disposables.create {}
            })
            .subscribeOn(storageScheduler)
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
                    completable(.error(KBStorageError.pathError))
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

                    this.logger.log(verbose: "KBStorageManager - Writing Record to Disk - \(asset.key)")

                    completable(.completed)

                } catch {
                    this.logger.log(error: "KBStorageManager - Error Writing Record to Disk - \(error)")
                    completable(.error(KBStorageError.generic))
                }

                return Disposables.create {}
            })
            .subscribeOn(storageScheduler)
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
                this.logger.log(verbose: "KBStorageManager - Deleting Record From Memory - \(asset.key)")

                this.memoryCache[asset.key] = nil

                return Disposables.create {}
            })
            .subscribeOn(storageScheduler)
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
                    completable(.error(KBStorageError.pathError))
                    return Disposables.create {}
                }

                if FileManager.default.fileExists(atPath: pathURL.path) {
                    do {
                        try FileManager.default.removeItem(at: pathURL)
                        this.logger.log(verbose: "KBStorageManager - Deleting Record From Disk - \(asset.key)")
                    } catch {
                        this.logger.log(error: "KBStorageManager - Error Deleting Record - \(asset.key)")
                    }
                }

                return Disposables.create {}
            })
            .subscribeOn(storageScheduler)
    }
}

extension KBStorageManager: KBStorageManagerType {

    // TODO switch params to just read type
    public func store(_ key: String, asset: KBAssetType, options: KBParameters) -> Completable {
        if var asset = asset as? KBExpirableEntityType {
            asset.expiryDate = options.expiryDate
        }

        if options.writePolicy == .disk {
            return writeToDisk(asset).andThen(writeToMemory(asset))

        } else if options.writePolicy == .memory {
            return writeToMemory(asset)
        }

        return Completable.empty()
    }

    // TODO: Needs read type options
    public func fetch(_ key: String) -> Single<KBAssetType> {
        return fetchContent(with: key)
    }

    public func clearMemoryStorage() -> Completable {
        memoryCache = [String: KBAssetType]()
        logger.log(verbose: "KBStorageManager - Cleared memory storage")
        
        return Completable.empty()
    }

    public func clearDiskStorage() -> Completable {
        guard let pathURL = contentURL else {
            return Completable.error(NSError())
        }

        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(atPath: pathURL.path)
            for path in directoryContents {
                let fullPath = pathURL.appendingPathComponent(path)
                try FileManager.default.removeItem(atPath: fullPath.path)
            }
            logger.log(verbose: "KBStorageManager - Cleared disk storage")
        } catch {
            logger.log(error: "KBStorageManager - Error clearing disk storage")
        }

        return Completable.empty()
    }
}
