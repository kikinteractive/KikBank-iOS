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
    func data(with url: URL) -> Single<Data>
    func data(with url: URL, cachePolicy: KBCachePolicy) -> Single<Data>
    func data(with url: URL, cachePolicy: KBCachePolicy, expiryDate: Date?) -> Single<Data>
}

public class KikBank {

    private let downloadManager: KBDownloadManagerType
    private let storageManager: KBStorageManagerType

    // Is a map the best way to track im requests?
    private lazy var uuidMap = [URL: String]()
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

    public func data(with url: URL) -> Single<Data> {
        return data(with: url, cachePolicy: .memory, expiryDate: nil)
    }

    public func data(with url: URL, cachePolicy: KBCachePolicy) -> Single<Data> {
        return data(with: url, cachePolicy: cachePolicy, expiryDate: nil)
    }

    public func data(with url: URL, cachePolicy: KBCachePolicy, expiryDate: Date?) -> Single<Data> {
        // Check if there is an existing record
        if let uuid = uuidMap[url],
            let data = storageManager.fetch(uuid) {
            return Single<Data>.create(subscribe: { (single) -> Disposable in
                single(.success(data))
                return Disposables.create()
            })
        }

        // Create a new record
        let uuid = UUID().uuidString
        uuidMap[url] = uuid

        let download = downloadManager.downloadData(with: url)

        download
            .subscribe(onSuccess: { [weak self] (data) in
                self?.storageManager.store(uuid, data: data, cachePolicy: .disk, expiryDate: expiryDate)
            }) { (error) in
                print("KikBank - \(error)")
            }
            .disposed(by: disposeBag)

        return download
    }
}
