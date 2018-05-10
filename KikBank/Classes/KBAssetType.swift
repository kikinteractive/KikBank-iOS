//
//  KBAssetType.swift
//  KikBank
//
//  Created by Yucheng Yan on 2018/3/21.
//

import Foundation

public protocol KBAssetType {
    var key: String { get }
    var data: Data { get }
}
