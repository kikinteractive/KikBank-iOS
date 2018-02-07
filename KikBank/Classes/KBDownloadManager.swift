//
//  KBDownloadManager.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import RxSwift

protocol KBDownloadManagerType {
    func downloadData(with url: URL) -> Single<Data>
}

class KBDownloadManager: KBDownloadManagerType {

    private lazy var downloadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 5
        return queue
    }()

    func downloadData(with url: URL) -> Single<Data> {
        return Single<Data>.create(subscribe: { [weak self] (single) -> Disposable in
            guard let this = self else { return Disposables.create() }

            let request = KBNetworkRequestOperation(url: url)
            request.completionBlock = {
                guard let data = request.result?.data else {
                    single(.error(NSError()))
                    return
                }
                single(.success(data))
            }

            this.downloadQueue.addOperation(request)

            return Disposables.create { request.cancel() }
        })
    }
}
