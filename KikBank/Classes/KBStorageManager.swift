//
//  KBStorageManager.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation

public protocol KBStorageManagerType {
    func store(_ uuid: String, data: Data)
    func store(_ uuid: String, data: Data, cachePolicy: KBCachePolicy)
    func store(_ uuid: String, data: Data, cachePolicy: KBCachePolicy, expiryDate: Date?)
    
    func fetch(_ uuid: String) -> Data?
}

class KBStorageManager {

    private struct Constants {
        static let cachePathExtension = "KikBankStorage"
    }

    private lazy var memoryCache = [String: KBAsset]()

    private lazy var contentURL: URL? = {
        let fileManager = FileManager.default
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return nil
        }
        return URL(string: documentsPath)?.appendingPathComponent(Constants.cachePathExtension)
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
        guard let fullPath = contentURL?.appendingPathComponent(uuid).absoluteString else {
            return nil
        }

        return NSKeyedUnarchiver.unarchiveObject(withFile: fullPath) as? KBAsset
    }

    private func writeToDisk(_ asset: KBAsset) {
        guard let pathString = contentURL?.appendingPathComponent(asset.uuid).path else {
            return
        }

        let fullPath = "file://" + pathString

        guard let pathURL = URL(string: fullPath) else {
            return
        }

        do {
            let data = NSKeyedArchiver.archivedData(withRootObject: asset)
            try data.write(to: pathURL)
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

public enum KBCachePolicy {
    case none
    case memory
    case disk
}

extension KBStorageManager: KBStorageManagerType {

    public func store(_ uuid: String, data: Data) {
        store(uuid, data: data, cachePolicy: .memory, expiryDate: nil)
    }

    public func store(_ uuid: String, data: Data, cachePolicy: KBCachePolicy) {
        store(uuid, data: data, cachePolicy: cachePolicy, expiryDate: nil)
    }

    public func store(_ uuid: String, data: Data, cachePolicy: KBCachePolicy, expiryDate: Date?) {
        let asset = KBAsset(uuid: uuid, data: data)
        asset.expiryDate = expiryDate

        switch cachePolicy {
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
