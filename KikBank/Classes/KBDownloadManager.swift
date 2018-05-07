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

    /// Modify the current concurrent operation count
    ///
    /// - Parameter count: The new concurrent operation count
    func setMaxConcurrentOperationCount(_ count: Int)


    /// Get a Single Observable for the requested data download
    ///
    /// - Parameter request: The URLRequest of the desired data
    /// - Returns: A Single Observable of the pending data download
    func downloadData(with request: URLRequest) -> Single<Data>

    /// The static logger
    ///
    var logger: KBStaticLoggerType.Type { get set }
}

/// Download manager which wraps an asynchronous operation queue and provides a Single<Data> type
public class KBDownloadManager: NSObject {

    private struct Constants {
        static let defaultMaxConcurrentOperationCount = 5
    }

    public lazy var logger: KBStaticLoggerType.Type = KBStaticLogger.self

    private lazy var downloadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = Constants.defaultMaxConcurrentOperationCount
        return queue
    }()

    private lazy var disposeBag = DisposeBag()
}

extension KBDownloadManager: KBDownloadManagerType {

    @objc public func setMaxConcurrentOperationCount(_ count: Int) {
        downloadQueue.maxConcurrentOperationCount = count
    }

    public func downloadData(with request: URLRequest) -> Single<Data> {
        return Observable<Data>
            .create({ [weak self] (observable) -> Disposable in
                guard let this = self, let url = request.url else {
                    observable.onError(NSError())
                    return Disposables.create()
                }

                this.logger.log(verbose: "KBDownloadManager - Fetching - \(url))")

                let request = KBNetworkRequestOperation(request: request)
                request.completionBlock = {
                    this.logger.log(verbose: "KBDownloadManager - Done - \(url)")
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
