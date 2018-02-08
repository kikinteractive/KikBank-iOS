//
//  KBStorageManager.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation

public protocol KBStorageManagerType {
    func store(_ uuid: String, data: Data, options: KBRequestParameters)
    func fetch(_ uuid: String) -> Data?
}

class KBStorageManager {

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
        } catch {
            print("KBStorageManager - Error writing to disk - \(error)")
        }
    }

    private func delete(_ asset: KBAsset) {
        guard let pathString = contentURL?.appendingPathComponent(asset.uuid).absoluteString else {
            return
        }

        let fullPath = "file:///" + pathString

        if FileManager.default.fileExists(atPath: fullPath) {
            do {
                try FileManager.default.removeItem(atPath: fullPath)
            } catch {
                print("KBStorageManager - Error deleting file - \(error)")
            }
        }
    }
}

extension KBStorageManager: KBStorageManagerType {

    func store(_ uuid: String, data: Data, options: KBRequestParameters) {
        let asset = KBAsset(uuid: uuid, data: data)
        asset.expiryDate = options.expiryDate

        switch options.writePolicy {
        case .disk:
            writeToDisk(asset)
            fallthrough
        case .memory:
            memoryCache[uuid] = asset
        default:
            break
        }
    }

    func fetch(_ uuid: String) -> Data? {
        return fetchContent(with: uuid)
    }
}
