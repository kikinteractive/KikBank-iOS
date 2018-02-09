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
    func store(_ uuid: String, data: Data, options: KBParameters)

    /// Get any valid data defined by the provided uuid
    ///
    /// - Parameter uuid: The unique identifier of the data
    /// - Returns: Valid data from a matching asset, if possible
    func fetch(_ uuid: String) -> Data?
}

/// Storage manager provides simple caching and disk storage solutions
@objc public class KBStorageManager: NSObject {

    private struct Constants {
        static let cachePathExtension = "KikBankStorage"
    }

    /// The in memory asset cache
    private lazy var memoryCache = [String: KBAsset]()

    /// Convenience accessor of the disk file location
    private lazy var contentURL: URL? = {
        let fileManager = FileManager.default

        do {
            let documentsPath = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            return documentsPath.appendingPathComponent(Constants.cachePathExtension)
        } catch {
            return nil
        }
    }()

    /// Checks for a stored asset matching the povided uuid
    ///
    /// - Parameter uuid: The unique identifier of the data
    /// - Returns: Valid data from a matching asset, if possible
    private func fetchContent(with uuid: String) -> Data? {
        // Check in memory cache
        if let asset = memoryCache[uuid]  {
            print("KBStorageManager - Found memory - \(uuid)")
            return validateAndReturn(asset)
        }

        // Check disk
        if let asset = readAssetFomDisk(with: uuid) {
            print("KBStorageManager - Found disk - \(uuid)")
            return validateAndReturn(asset)
        }

        print("KBStorageManager - No Record - \(uuid)")

        // Nothin
        return nil
    }

    /// Check if the provided asset has passed validation checks and should return data
    ///
    /// - Parameter asset: The asset to check for validity
    /// - Returns: The asset's data if it is valid
    private func validateAndReturn(_ asset: KBAsset) -> Data? {
        if !asset.isValid() {
            // Asset has become invalid, remove references
            memoryCache[asset.uuid] = nil
            delete(asset)
            return nil
        }

        return asset.data
    }

    /// Reads an asset defined by a uuid from disk if available
    ///
    /// - Parameter uuid: The unique identifier of the data
    /// - Returns: An asset matching the provided uuid, if one exists
    private func readAssetFomDisk(with uuid: String) -> KBAsset? {
        guard let pathURL = contentURL?.appendingPathExtension(uuid) else {
            return nil
        }

        return NSKeyedUnarchiver.unarchiveObject(withFile: pathURL.path) as? KBAsset
    }

    /// Write the provided asset to disk
    ///
    /// - Parameter asset: The asset to be written to disk
    private func writeToDisk(_ asset: KBAsset) {
        guard let pathURL = contentURL?.appendingPathExtension(asset.uuid) else {
            return
        }

        do {
            let data = NSKeyedArchiver.archivedData(withRootObject: asset)
            try data.write(to: pathURL, options: .atomic)
            print("KBStorageManager - Writing Record to Disk - \(asset.uuid)")
        } catch {
            print("KBStorageManager - Error Writing Record to Disk - \(error)")
        }
    }

    /// Deletes the provided asset
    ///
    /// - Parameter asset: The asset to be removed from disk
    private func delete(_ asset: KBAsset) {
        guard let pathURL = contentURL?.appendingPathExtension(asset.uuid) else {
            return
        }

        if FileManager.default.fileExists(atPath: pathURL.path) {
            do {
                try FileManager.default.removeItem(at: pathURL)
                print("KBStorageManager - Deleting Record - \(asset.uuid)")
            } catch {
                print("KBStorageManager - Error Deleting Record - \(asset.uuid)")
            }
        }
    }
}

extension KBStorageManager: KBStorageManagerType {

    public func store(_ uuid: String, data: Data, options: KBParameters) {
        let asset = KBAsset(uuid: uuid, data: data)
        asset.expiryDate = options.expiryDate

        switch options.writePolicy {
        case .disk:
            print("KBStorageManager - Writing to Disk - \(asset.uuid)")
            writeToDisk(asset)
            fallthrough // Disk items are included in memory (for now?)
        case .memory:
            print("KBStorageManager - Writing to Memory - \(asset.uuid)")
            memoryCache[uuid] = asset
        default:
            break
        }
    }

    public func fetch(_ uuid: String) -> Data? {
        return fetchContent(with: uuid)
    }
}
