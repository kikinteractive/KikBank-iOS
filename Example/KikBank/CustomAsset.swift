//
//  ImageAsset.swift
//  KikBank_Example
//
//  Created by James Harquail on 2018-05-30.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import KikBank

class ImageAsset: KBAsset {

    var image: UIImage? {
        return UIImage(data: data)
    }
}
