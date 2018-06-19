//
//  KBDataAsset.swift
//  KikBank
//
//  Created by James Harquail on 2018-05-31.
//

import Foundation

public protocol KBDataAssetType: KBAssetType {

    var data: Data { get }
}

open class KBDataAsset: KBAsset, KBDataAssetType {

    private struct Constants {
        static let dataKey = "kbData"
    }

    public var data: Data

    public required init(identifier: Int, data: Data) {
        self.data = data
        super.init(identifier: identifier)
    }

    public required init?(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeObject(forKey: Constants.dataKey) as? Data else {
            return nil
        }

        self.data = data

        super.init(coder: aDecoder)
    }

    open override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)

        aCoder.encode(data, forKey: Constants.dataKey)
    }

    open override func isEqual(_ object: Any?) -> Bool {
        guard let dataAsset = object as? KBDataAsset else {
            return false
        }

        return super.isEqual(object) && data == dataAsset.data
    }
}
