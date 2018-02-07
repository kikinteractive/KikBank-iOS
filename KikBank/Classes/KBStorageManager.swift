//
//  KBStorageManager.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation

protocol KBStorageManagerType {
    func store(_ uuid: UUID, data: Data)
    func fetch(_ uuid: UUID) -> Data?
}

class KBStorageManager {
    private lazy var memoryCache = [UUID: Data]()
}

extension KBStorageManager: KBStorageManagerType {

    func store(_ uuid: UUID, data: Data) {
        memoryCache[uuid] = data
    }

    func fetch(_ uuid: UUID) -> Data? {
        return memoryCache[uuid]
    }
}
