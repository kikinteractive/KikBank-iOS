//
//  DemoImageAsset.swift
//  KikBank_Example
//
//  Created by James Harquail on 2018-05-30.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import KikBank

// Example of create a custom subset of a base data asset
class DemoImageAsset: KBDataAsset {

    var image: UIImage? {
        return UIImage(data: data)
    }
}
