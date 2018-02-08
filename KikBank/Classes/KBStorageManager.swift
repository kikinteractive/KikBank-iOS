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
            return validateAndReturn(asset)
        }

        // Check disk
        if let asset = readAssetFomDisk(with: uuid) {
            return validateAndReturn(asset)
        }

        // Nothin
        return nil
    }

    private func validateAndReturn(_ asset: KBAsset) -> Data? {
        if let expiryDate = asset.expiryDate {
            if Date().timeIntervalSince(expiryDate) > 0 {
                // Asset has passed expiry date, delete it
                memoryCache[asset.uuid] = nil
                delete(asset)
                return nil
            }
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
        guard let fullPath = contentURL?.appendingPathComponent(asset.uuid) else {
            return
        }

        do {
            let data = NSKeyedArchiver.archivedData(withRootObject: asset)
            try data.write(to: fullPath)
        } catch {
            print("Couldn't write file")
        }
    }

    private func delete(_ asset: KBAsset) {
        guard let fullPath = contentURL?.appendingPathComponent(asset.uuid).absoluteString else {
            return
        }

        if FileManager.default.fileExists(atPath: fullPath) {
            do {
                try FileManager.default.removeItem(atPath: fullPath)
            } catch {
                print("Couldn't delete file")
            }
        }

    }
}

enum KBCachePolicy {
    case none
    case memory
    case disk
}

extension KBStorageManager: KBStorageManagerType {

    func store(_ uuid: String, data: Data) {
        store(uuid, data: data, cachePolicy: .memory)
    }

    func store(_ uuid: String, data: Data, cachePolicy: KBCachePolicy) {
        let asset = KBAsset(uuid: uuid, data: data)
        switch cachePolicy {
        case .disk:
            writeToDisk(asset)
            fallthrough // Disk items are persisted in memory. good/bad?
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

class KBAsset: NSObject {

    private struct Constants {
        static let uuidKey = "kbuuid"
        static let dataKey = "kbdata"
        static let expiryKey = "kbexpiry"
    }

    var uuid: String
    var data: Data

    var expiryDate: Date?

    init(uuid: String, data: Data) {
        self.uuid = uuid
        self.data = data
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        guard
            let uuid = aDecoder.decodeObject(forKey: Constants.uuidKey) as? String,
            let data = aDecoder.decodeObject(forKey: Constants.dataKey) as? Data else {
                return nil
        }

        self.uuid = uuid
        self.data = data

        self.expiryDate = aDecoder.decodeObject(forKey: Constants.dataKey) as? Date
    }

    func isValid() -> Bool {
        if let expiryDate = expiryDate {
            return Date().timeIntervalSince(expiryDate) > 0
        }
        return true
    }
}

extension KBAsset: NSCoding {
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(uuid, forKey: Constants.uuidKey)
        aCoder.encode(uuid, forKey: Constants.uuidKey)
        aCoder.encode(uuid, forKey: Constants.uuidKey)
    }
}
