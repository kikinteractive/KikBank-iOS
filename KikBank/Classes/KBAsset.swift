//
//  KBAsset.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//

import Foundation

/// Cached and saved object which tracks data validity
open class KBAsset: NSObject, KBAssetType {

    private struct Constants {
        static let identifierKey = "kbIdentifier"
        static let dataKey = "kbData"
        static let expiryKey = "kbExpiry"
    }

    /// The unique identifer of the data request
    public var identifier: Int

    /// The stored data
    public var data: Data

    /// The date at which to invalidate the stored data
    public var expiryDate: Date?

    public init(identifier: Int, data: Data) {
        self.identifier = identifier
        self.data = data
        super.init()
    }

    public required init?(coder aDecoder: NSCoder) {
        guard
            let data = aDecoder.decodeObject(forKey: Constants.dataKey) as? Data else {
                return nil
        }

        self.identifier = aDecoder.decodeInteger(forKey: Constants.identifierKey)
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
        aCoder.encode(identifier, forKey: Constants.identifierKey)
        aCoder.encode(data, forKey: Constants.dataKey)
        aCoder.encode(expiryDate, forKey: Constants.expiryKey)
    }
}
