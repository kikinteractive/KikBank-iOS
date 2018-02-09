//
//  KBStorageManager.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation

@objc public protocol KBStorageManagerType {
    func store(_ uuid: String, data: Data, options: KBRequestParameters)
    func fetch(_ uuid: String) -> Data?
}

@objc public class KBStorageManager: NSObject {

    private struct Constants {
        static let cachePathExtension = "KikBankStorage"
    }

    private lazy var memoryCache = [String: KBAsset]()

    private lazy var contentURL: URL? = {
        let fileManager = FileManager.default

        do {
            let documentsPath = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            return documentsPath.appendingPathComponent(Constants.cachePathExtension)
        } catch {
            return nil
        }
    }()

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

    private func validateAndReturn(_ asset: KBAsset) -> Data? {
        if !asset.isValid() {
            // Asset has become invalid, remove references
            memoryCache[asset.uuid] = nil
            delete(asset)
            return nil
        }

        return asset.data
    }

    private func readAssetFomDisk(with uuid: String) -> KBAsset? {
        guard let pathURL = contentURL?.appendingPathExtension(uuid) else {
            return nil
        }

        return NSKeyedUnarchiver.unarchiveObject(withFile: pathURL.path) as? KBAsset
    }

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

    public func store(_ uuid: String, data: Data, options: KBRequestParameters) {
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
