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
    ///   - uuid: The unique identifier of the data
    ///   - data: The data to be stored
    ///   - options: The write policy of the data
    func store(_ key: String, expirableEntity: ExpirableEntityType, options: KBParameters)

    /// Get any valid data defined by the provided uuid
    ///
    /// - Parameter uuid: The unique identifier of the data
    /// - Returns: Valid data from a matching asset, if possible
    func fetch(_ key: String) -> ExpirableEntityType?
}

/// Storage manager provides simple caching and disk storage solutions
@objc public class KBStorageManager: NSObject {

    var cachePathExtension: String {
        get {
            return self.cachePathExtension
        }
        
        set {
            self.cachePathExtension = "/" + newValue
        }
    }

    /// The in memory expirableEntity cache
    private lazy var memoryCache = [String: ExpirableEntityType]()

    /// Convenience accessor of the disk file location
    private lazy var contentURL: URL? = {
        let fileManager = FileManager.default

        do {
            let documentsPath = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            return documentsPath.appendingPathComponent(self.cachePathExtension)
        } catch {
            return nil
        }
    }()

    /// Checks for a stored expirableEntity matching the povided uuid
    ///
    /// - Parameter uuid: The unique identifier of the expirableEntity
    /// - Returns: Valid expirableEntity, if possible
    private func fetchContent(with key: String) -> ExpirableEntityType? {
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

    /// Check if the provided asset has passed validation checks and should return expirableEntity
    ///
    /// - Parameter asset: The asset to check for validity
    /// - Returns: expirableEntity if it is valid
    private func validateAndReturn(_ expirableEntity: ExpirableEntityType) -> ExpirableEntityType? {
        if !expirableEntity.isValid {
            // Asset has become invalid, remove references
            memoryCache[expirableEntity.key] = nil
            delete(expirableEntity)
            return nil
        }

        return nil
    }

    /// Reads an asset defined by a uuid from disk if available
    ///
    /// - Parameter uuid: The unique identifier of the data
    /// - Returns: An asset matching the provided uuid, if one exists
    private func readAssetFomDisk(with key: String) -> ExpirableEntityType? {
        guard let pathURL = contentURL?.appendingPathExtension(key) else {
            return nil
        }

        return NSKeyedUnarchiver.unarchiveObject(withFile: pathURL.path) as? ExpirableEntityType
    }

    /// Write the provided asset to disk
    ///
    /// - Parameter asset: The expirableEntity to be written to disk
    private func writeToDisk(_ expirableEntity: ExpirableEntityType) {
        guard let pathURL = contentURL?.appendingPathExtension(expirableEntity.key) else {
            return
        }

        do {
            let data = NSKeyedArchiver.archivedData(withRootObject: expirableEntity)
            try data.write(to: pathURL, options: .atomic)
            print("KBStorageManager - Writing Record to Disk - \(expirableEntity.key)")
        } catch {
            print("KBStorageManager - Error Writing Record to Disk - \(error)")
        }
    }

    /// Deletes the provided asset
    ///
    /// - Parameter asset: The asset to be removed from disk
    private func delete(_ expirableEntity: ExpirableEntityType) {
        guard let pathURL = contentURL?.appendingPathExtension(expirableEntity.key) else {
            return
        }

        if FileManager.default.fileExists(atPath: pathURL.path) {
            do {
                try FileManager.default.removeItem(at: pathURL)
                print("KBStorageManager - Deleting Record - \(expirableEntity.key)")
            } catch {
                print("KBStorageManager - Error Deleting Record - \(expirableEntity.key)")
            }
        }
    }
}

extension KBStorageManager: KBStorageManagerType {
    public func store(_ key: String, expirableEntity: ExpirableEntityType, options: KBParameters) {
        expirableEntity.expiryDate = options.expiryDate
        
        switch options.writePolicy {
        case .disk:
            print("KBStorageManager - Writing to Disk - \(expirableEntity.key)")
            writeToDisk(expirableEntity)
            fallthrough // Disk items are included in memory (for now?)
        case .memory:
            print("KBStorageManager - Writing to Memory - \(expirableEntity.key)")
            memoryCache[expirableEntity.key] = expirableEntity
        default:
            break
        }
    }

    public func fetch(_ key: String) -> ExpirableEntityType? {
        return fetchContent(with: key)
    }
}
