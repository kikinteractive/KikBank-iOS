//
//  KBStorageManager.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import RxSwift

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
    func fetch(_ key: String) -> KBAssetType?

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

    /// Custom path for content storage
    private let cachePathExtension: String

    /// The in memory asset cache
    private lazy var memoryCache = [String: KBAssetType]()

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
    private func fetchContent(with key: String) -> KBAssetType? {
        // Check in memory cache
        if let asset = memoryCache[key]  {
            print("KBStorageManager - Found memory - \(key)")
            return validateAndReturn(asset)
        }

        // Check disk
        if let asset = readAssetFomDisk(with: key) {
            print("KBStorageManager - Found disk - \(key)")
            return validateAndReturn(asset)
        }

        print("KBStorageManager - No Record - \(key)")

        // Nothin
        return nil
    }

    /// Check if the provided asset has passed validation checks and should return asset
    ///
    /// - Parameter asset: The asset to check for validity
    /// - Returns: asset if it is valid
    private func validateAndReturn(_ asset: KBAssetType) -> KBAssetType? {
        if !asset.isValid {
            // Asset has become invalid, remove references
            memoryCache[asset.key] = nil
            delete(asset)
            return nil
        }

        return asset
    }

    /// Reads an asset defined by a uuid from disk if available
    ///
    /// - Parameter uuid: The unique identifier of the data
    /// - Returns: An asset matching the provided uuid, if one exists
    private func readAssetFomDisk(with key: String) -> KBAssetType? {
        guard let pathURL = contentURL?.appendingPathExtension(key) else {
            return nil
        }

        return NSKeyedUnarchiver.unarchiveObject(withFile: pathURL.path) as? KBAssetType
    }

    /// Write the provided asset to disk
    ///
    /// - Parameter asset: The asset to be written to disk
    private func writeToDisk(_ asset: KBAssetType) {
        guard let pathURL = contentURL?.appendingPathExtension(asset.key) else {
            return
        }

        do {
            let data = NSKeyedArchiver.archivedData(withRootObject: asset)
            try data.write(to: pathURL, options: .atomic)
            print("KBStorageManager - Writing Record to Disk - \(asset.key)")
        } catch {
            print("KBStorageManager - Error Writing Record to Disk - \(error)")
        }
    }

    /// Deletes the provided asset
    ///
    /// - Parameter asset: The asset to be removed from disk
    private func delete(_ asset: KBAssetType) {
        guard let pathURL = contentURL?.appendingPathExtension(asset.key) else {
            return
        }

        if FileManager.default.fileExists(atPath: pathURL.path) {
            do {
                try FileManager.default.removeItem(at: pathURL)
                print("KBStorageManager - Deleting Record - \(asset.key)")
            } catch {
                print("KBStorageManager - Error Deleting Record - \(asset.key)")
            }
        }
    }
}

extension KBStorageManager: KBStorageManagerType {
    
    public func store(_ key: String, asset: KBAssetType, options: KBParameters) -> Completable {
        asset.expiryDate = options.expiryDate
        
        switch options.writePolicy {
        case .disk:
            print("KBStorageManager - Writing to Disk - \(asset.key)")
            writeToDisk(asset)
            fallthrough // Disk items are included in memory (for now?)
        case .memory:
            print("KBStorageManager - Writing to Memory - \(asset.key)")
            memoryCache[asset.key] = asset
        default:
            break
        }

        return Completable.empty()
    }

    public func fetch(_ key: String) -> KBAssetType? {
        return fetchContent(with: key)
    }

    public func clearMemoryStorage() -> Completable {
        memoryCache = [String: KBAssetType]()
        print("KBStorageManager - Cleared memory storage")

        return Completable.empty()
    }

    public func clearDiskStorage() -> Completable {
        guard let pathURL = contentURL else {
            return Completable.error(NSError())
        }

        do {
            try FileManager.default.removeItem(at: pathURL)
            print("KBStorageManager - Cleared disk storage")
        } catch {
            print("KBStorageManager - Error clearing disk storage")
        }

        return Completable.empty()
    }
}
