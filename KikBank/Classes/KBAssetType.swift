//
//  KBAssetType.swift
//  KikBank
//
//  Created by Yucheng Yan on 2018/3/21.
//

import Foundation

public protocol KBAssetType: class, NSCoding {
    // The unique identifier of the data
    var identifier: Int { get }
    // The optional date after which to invalidate the stored data
    var expiryDate: Date? { get set }
    // Convenience accessor to calculate validity
    var isValid: Bool { get }

    func isEqual(_ object: Any?) -> Bool
}
