//
//  KBExpirableEntityType.swift
//  KikBank
//
//  Created by Yucheng Yan on 2018/3/20.
//

import Foundation

@objc public protocol KBExpirableEntityType {
    var expiryDate: Date? { get set }
    var isValid: Bool { get }
}
