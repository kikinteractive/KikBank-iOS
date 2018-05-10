//
//  KBStorageManager.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation

@objc public protocol KBStorageManagerType {

    /// Store the provded data based on provided storage policy
    ///
    /// - Parameters:
    ///   - key: The unique identifier of the asset
    ///   - asset: The asset to be stored
    ///   - options: The write policy of the asset
    func store(_ key: String, asset: KBAssetType, options: KBParameters)

    /// Get any valid data defined by the provided uuid
    ///
    /// - Parameter key: The unique identifier of the asset
    /// - Returns: Valid asset, if possible
    func fetch(_ key: String) -> KBAssetType?

    /// Reset the in memory storage
    ///
    func clearMemoryStorage() -> Void

    /// Resets the storage
    /// Caution! This removes all stored content at the current content path
    /// The storage manager may be using a shared resoure location
    ///
    func clearDiskStorage() -> Void
}

/// Storage manager provides simple caching and disk storage solutions
@objc public class KBStorageManager: NSObject {

    var cachePathExtension: String

    /// The in memory asset cache
    private lazy var memoryCache = [String: KBAssetType]()

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
    
    @objc public init(pathExtension: String) {
        cachePathExtension = pathExtension
        super.init()
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
        guard let pathURL = contentURL?.appendingPathComponent(key) else {
            return nil
        }

        return NSKeyedUnarchiver.unarchiveObject(withFile: pathURL.path) as? KBAssetType
    }

    /// Write the provided asset to disk
    ///
    /// - Parameter asset: The asset to be written to disk
    private func writeToDisk(_ asset: KBAssetType) {

        guard let baseURL = contentURL else {
            return
        }

        let pathURL = baseURL.appendingPathComponent(asset.key)
        do {
            if !FileManager.default.fileExists(atPath: baseURL.path) {
                try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
            }
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
        guard let pathURL = contentURL?.appendingPathComponent(asset.key) else {
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
    
    public func store(_ key: String, asset: KBAssetType, options: KBParameters) {
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
    }

    public func fetch(_ key: String) -> KBAssetType? {
        return fetchContent(with: key)
    }

    public func clearMemoryStorage() -> Void {
        memoryCache = [String: KBAssetType]()
        print("KBStorageManager - Cleared memory storage")
    }

    public func clearDiskStorage() -> Void {
        guard let pathURL = contentURL else {
            return
        }

        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(atPath: pathURL.path)
            for path in directoryContents {
                let fullPath = pathURL.appendingPathComponent(path)
                try FileManager.default.removeItem(atPath: fullPath.path)
            }
            print("KBStorageManager - Cleared disk storage")
        } catch {
            print("KBStorageManager - Error clearing disk storage - \(error)")
        }
    }
}
