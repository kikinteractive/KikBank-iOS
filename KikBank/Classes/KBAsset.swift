//
//  KBAsset.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//

import Foundation

/// Cached and saved object which tracks data validity
public class KBAsset: NSObject, KBAssetType {

    private struct Constants {
        static let uuidKey = "kbuuid"
        static let dataKey = "kbdata"
        static let expiryKey = "kbexpiry"
    }

    /// The unique identifer of the data request
    public var key: String

    /// The stored data
    var data: Data

    /// The date at which to invalidate the stored data
    public var expiryDate: Date?

    public init(uuid: String, data: Data) {
        self.key = uuid
        self.data = data
        super.init()
    }

    public required init?(coder aDecoder: NSCoder) {
        guard
            let uuid = aDecoder.decodeObject(forKey: Constants.uuidKey) as? String,
            let data = aDecoder.decodeObject(forKey: Constants.dataKey) as? Data else {
                return nil
        }

        self.key = uuid
        self.data = data

        self.expiryDate = aDecoder.decodeObject(forKey: Constants.dataKey) as? Date
    }

    /**
     Check if the data has passed validity checks

     - Returns: If the data should be returned or removed from storage
    */
    public var isValid: Bool {
        if let expiryDate = expiryDate {
            return expiryDate > Date()
        }
        return true
    }
}

extension KBAsset: NSCoding {
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(key, forKey: Constants.uuidKey)
        aCoder.encode(data, forKey: Constants.dataKey)
        aCoder.encode(expiryDate, forKey: Constants.expiryKey)
    }
}
