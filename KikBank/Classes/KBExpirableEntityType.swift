//
//  KBExpirableEntityType.swift
//  KikBank
//
//  Created by Yucheng Yan on 2018/3/20.
//

import Foundation

public protocol KBExpirableEntityType: KBAssetType {
    var expiryDate: Date? { get set }
    var isValid: Bool { get }
}
