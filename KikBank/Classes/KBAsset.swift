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
        static let expiryKey = "kbExpiry"
    }

    /// The unique identifer of the data request
    public var identifier: Int

    /// The date at which to invalidate the stored data
    public var expiryDate: Date?

    public init(identifier: AnyHashable) {
        self.identifier = identifier.hashValue
        super.init()
    }

    public required init?(coder aDecoder: NSCoder) {
        self.identifier = aDecoder.decodeInteger(forKey: Constants.identifierKey)
        self.expiryDate = aDecoder.decodeObject(forKey: Constants.expiryKey) as? Date
    }

    /**
     Check if the data has passed validity checks

     - Returns: If the data should be returned or removed from storage
    */
    open var isValid: Bool {
        if let expiryDate = expiryDate {
            return expiryDate > Date()
        }
        return true
    }

    open override func isEqual(_ object: Any?) -> Bool {
        guard let otherAsset = object as? KBAssetType else {
            return false
        }

        return identifier == otherAsset.identifier && expiryDate == otherAsset.expiryDate
    }
}

extension KBAsset: NSCoding {
    
    open func encode(with aCoder: NSCoder) {
        aCoder.encode(identifier, forKey: Constants.identifierKey)
        aCoder.encode(expiryDate, forKey: Constants.expiryKey)
    }
}
