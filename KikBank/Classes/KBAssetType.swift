//
//  KBAssetType.swift
//  KikBank
//
//  Created by Yucheng Yan on 2018/3/21.
//

import Foundation

public protocol KBAssetType {
    var identifier: Int { get }
    var data: Data { get }

    var expiryDate: Date? { get set }
    var isValid: Bool { get }
}
