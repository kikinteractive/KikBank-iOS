//
//  KBDownloadManager.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import RxSwift

public protocol KBDownloadManagerType {
    func downloadData(with url: URL) -> Single<Data>
}

class KBDownloadManager: KBDownloadManagerType {

    private lazy var downloadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 5
        return queue
    }()

    func downloadData(with url: URL) -> Single<Data> {
        return Observable<Data>
            .create({ [weak self] (observable) -> Disposable in
                guard let this = self else { return Disposables.create() }

                print("KBDownloadManager - Fetching - \(url)")

                let request = KBNetworkRequestOperation(url: url)
                request.completionBlock = {
                    print("KBDownloadManager - Done - \(url)")
                    guard let data = request.result?.data else {
                        observable.onError(NSError())
                        return
                    }
                    observable.onNext(data)
                }

                this.downloadQueue.addOperation(request)

                return Disposables.create { request.cancel() }
            })
            .share()
            .take(1)
            .asSingle()
    }
}
