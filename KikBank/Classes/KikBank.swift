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
}

public class KikBank {

    private let downloadManager: KBDownloadManagerType
    private let storageManager: KBStorageManagerType

    private lazy var uuidMap = [URL: UUID]()
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
        // Check if there is an existing record
        if let uuid = uuidMap[url],
            let data = storageManager.fetch(uuid) { // TODO: Handle cache invalidation
            return Single<Data>.create(subscribe: { (single) -> Disposable in
                single(.success(data))
                return Disposables.create()
            })
        }

        // Create a new record
        let uuid = UUID()
        uuidMap[url] = uuid

        let download = downloadManager.downloadData(with: url)
        download
            .subscribe(onSuccess: { [weak self] (data) in
                self?.storageManager.store(uuid, data: data)
            }) { (error) in
                print("KikBank - \(error)")
            }
            .disposed(by: disposeBag)

        return download
    }
}
