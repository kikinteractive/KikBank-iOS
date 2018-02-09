//
//  KBAsset.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//

import Foundation

/// Cached and saved object which tracks data validity
class KBAsset: NSObject {

    private struct Constants {
        static let uuidKey = "kbuuid"
        static let dataKey = "kbdata"
        static let expiryKey = "kbexpiry"
    }

    /// The unique identifer of the data request
    var uuid: String

    /// The stored data
    var data: Data

    /// The date at which to invalidate the stored data
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

    /**
     Check if the data has passed validity checks

     - Returns: If the data should be returned or removed from storage
    */
    func isValid() -> Bool {
        if let expiryDate = expiryDate {
            return expiryDate > Date()
        }
        return true
    }
}

extension KBAsset: NSCoding {
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(uuid, forKey: Constants.uuidKey)
        aCoder.encode(data, forKey: Constants.dataKey)
        aCoder.encode(expiryDate, forKey: Constants.expiryKey)
    }
}
