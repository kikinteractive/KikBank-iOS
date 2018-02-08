//
//  KikBank.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import RxSwift

public protocol KikBankType {
    func data(with url: URL, options: KBRequestParameters) -> Observable<Data>
}

public class KikBank {

    private let downloadManager: KBDownloadManagerType
    private let storageManager: KBStorageManagerType

    private lazy var disposeBag = DisposeBag()

    public convenience init() {
        let storageManager = KBStorageManager()
        let downloadManager = KBDownloadManager()
        self.init(storageManager: storageManager, downloadManager: downloadManager)
    }

    public required init(storageManager: KBStorageManagerType, downloadManager: KBDownloadManagerType) {
        self.storageManager = storageManager
        self.downloadManager = downloadManager
    }
}

extension KikBank: KikBankType {

    public func data(with url: URL, options: KBRequestParameters) -> Observable<Data> {
        let uuid = String(describing: url.absoluteString.hashValue) // NOTE: this is not guaranteed between sessions?
        guard uuid != "" else {
            return .error(NSError())
        }

        // Check if there is an existing record
        if options.readPolicy == .cache,
            let data = storageManager.fetch(uuid) {
            return .just(data)
        }

        // Create a new record and fetch
        let download = downloadManager.downloadData(with: url)

        // Cache on completion
        download
            .subscribe(onNext: { [weak self] (data) in
                self?.storageManager.store(uuid, data: data, options: options)
                }, onError: { (error) in
                    print("KikBank - \(error)")
            })
            .disposed(by: disposeBag)

        return download
    }
}

public struct KBRequestParameters {
    var expiryDate: Date?
    var readPolicy: KBReadPolicy = .cache
    var writePolicy: KBWritePolicy = .memory

    public init() {
        
    }
}

// Specify where data should be read
public enum KBReadPolicy {
    case cache // Check the local storage for a copy first
    case network // Force a network fetch
}

// Specify how the data should be saved
public enum KBWritePolicy {
    case none // Don't save anything
    case memory // Write only to memory, lost on bank dealloc
    case disk // Write to device, recovered between sessions
}
