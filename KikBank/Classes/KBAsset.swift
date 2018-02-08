//
//  KBAsset.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//

import Foundation

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
            return expiryDate > Date()
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
