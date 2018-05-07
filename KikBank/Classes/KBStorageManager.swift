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
    private lazy var storageScheduler: SchedulerType = SerialDispatchQueueScheduler(queue: DispatchQueue.global(),
                                                                                    internalSerialQueueName: Constants.storageSchedulerName)

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
    }

    /// Checks for a stored asset matching the povided uuid
    ///
    /// - Parameter uuid: The unique identifier of the asset
    /// - Returns: Valid asset, if possible
    private func fetchContent(with key: String) -> Single<KBAssetType> {
        return readAssetFromMemory(with: key)
            .catchError({ [weak self] (error) -> Single<KBAssetType> in
                guard let this = self else {
                    return Single.error(KBStorageError.deallocated)
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
                    return this.deleteAssetFromDisk(asset).asObservable().take(1).asSingle().flatMap({ (_) -> Single<KBAssetType> in // wtf
                        return .error(KBStorageError.invalid)
                    })
                }

                return .just(asset)
            })
    }

    /// Read an asset defined by a unique idenentifier from in-memory cache
    ///
    /// - Parameter key: The unique identifier of the data
    /// - Returns: An asset matching the provided key, if one exists
    private func readAssetFromMemory(with key: String) -> Single<KBAssetType> {
        return Single.create(subscribe: { [weak self] (single) -> Disposable in
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
    }

    /// Reads an asset defined by a unique idenentifier from disk if available
    ///
    /// - Parameter key: The unique identifier of the data
    /// - Returns: An asset matching the provided key, if one exists
    private func readAssetFomDisk(with key: String) -> Single<KBAssetType> {
        return Single.create(subscribe: { [weak self] (single) -> Disposable in
            guard let this = self else {
                single(.error(KBStorageError.deallocated))
                return Disposables.create {}
            }

            guard let pathURL = this.contentURL?.appendingPathExtension(key) else {
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
    }

    /// Write the provided asset to memory
    ///
    /// - Parameter asset: The asset the be writted to memory
    private func writeToMemory(_ asset: KBAssetType) -> Completable {
        return Completable.create(subscribe: { [weak self] (completable) -> Disposable in
            guard let this = self else {
                completable(.error(KBStorageError.deallocated))
                return Disposables.create {}
            }

            this.logger.log(verbose: "KBStorageManager - Writing to Memory - \(asset.key)")
            this.memoryCache[asset.key] = asset

            completable(.completed)

            return Disposables.create {}
        })
    }

    /// Write the provided asset to disk
    ///
    /// - Parameter asset: The asset to be written to disk
    private func writeToDisk(_ asset: KBAssetType) -> Completable {
        return Completable.create(subscribe: { [weak self] (completable) -> Disposable in
            guard let this = self else {
                completable(.error(KBStorageError.deallocated))
                return Disposables.create {}
            }

            guard let pathURL = this.contentURL?.appendingPathExtension(asset.key) else {
                completable(.error(KBStorageError.pathError))
                return Disposables.create {}
            }

            do {
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
    }

    /// Deletes the provided asset
    ///
    /// - Parameter asset: The asset to be removed from disk
    private func deleteAssetFromDisk(_ asset: KBAssetType) -> Completable {
        return Completable.create(subscribe: { [weak self] (completable) -> Disposable in
            guard let this = self else {
                completable(.error(KBStorageError.deallocated))
                return Disposables.create {}
            }

            guard let pathURL = this.contentURL?.appendingPathExtension(asset.key) else {
                completable(.error(KBStorageError.pathError))
                return Disposables.create {}
            }

            if FileManager.default.fileExists(atPath: pathURL.path) {
                do {
                    try FileManager.default.removeItem(at: pathURL)
                    this.logger.log(verbose: "KBStorageManager - Deleting Record - \(asset.key)")
                    completable(.completed)
                } catch {
                    this.logger.log(error: "KBStorageManager - Error Deleting Record - \(asset.key)")
                    completable(.error(KBStorageError.generic))
                }
            } else {
                completable(.error(KBStorageError.generic))
            }

            return Disposables.create {}
        })
    }
}

extension KBStorageManager: KBStorageManagerType {

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
            try FileManager.default.removeItem(at: pathURL)
            logger.log(verbose: "KBStorageManager - Cleared disk storage")
        } catch {
            logger.log(error: "KBStorageManager - Error clearing disk storage")
        }

        return Completable.empty()
    }
}
