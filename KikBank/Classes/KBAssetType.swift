//
//  KBAssetType.swift
//  KikBank
//
//  Created by Yucheng Yan on 2018/3/21.
//

import Foundation

@objc public protocol KBAssetType: KBExpirableEntityType {
    var key: String { get }
}
