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
    func data(with url: URL, options: KBRequestParameters) -> Single<Data>

    func data(with request: URLRequest) -> Single<Data>
    func data(with request: URLRequest, options: KBRequestParameters) -> Single<Data>
}

@objc public class KikBank: NSObject {

    private lazy var disposeBag = DisposeBag()

    private let downloadManager: KBDownloadManagerType
    private let storageManager: KBStorageManagerType

    @objc public convenience override init() {
        let storageManager = KBStorageManager()
        let downloadManager = KBDownloadManager()
        self.init(storageManager: storageManager, downloadManager: downloadManager)
    }

    public required init(storageManager: KBStorageManagerType, downloadManager: KBDownloadManagerType) {
        self.storageManager = storageManager
        self.downloadManager = downloadManager
        super.init()
    }
}

extension KikBank: KikBankType {

    public func data(with url: URL) -> Single<Data> {
        let request = URLRequest(url: url)
        return data(with: request, options: KBRequestParameters())
    }

    public func data(with url: URL, options: KBRequestParameters) -> Single<Data> {
        let request = URLRequest(url: url)
        return data(with: request, options: KBRequestParameters())
    }

    public func data(with request: URLRequest) -> PrimitiveSequence<SingleTrait, Data> {
        return data(with: request, options: KBRequestParameters())
    }

    public func data(with request: URLRequest, options: KBRequestParameters) -> PrimitiveSequence<SingleTrait, Data> {
        // This is annoyingly long and potentially pointless
        guard let uuid = request.url?.absoluteString.hashValue.description,
            uuid != "" else {
            return .error(NSError())
        }

        // Check if there is an existing record
        if options.readPolicy == .cache,
            let data = storageManager.fetch(uuid) {
            return .just(data)
        }

        // Create a new record and fetch
        let download = downloadManager.downloadData(with: request)

        // Cache on completion
        download
            .subscribe(onSuccess: { [weak self] (data) in
                self?.storageManager.store(uuid, data: data, options: options)
                }, onError: { (error) in
                    print("KikBank - \(error)")
            })
            .disposed(by: disposeBag)

        return download
    }
}

extension KikBank {

    @objc public func data(with request: URLRequest, options: KBRequestParameters, success: @escaping (Data) -> Void, failure: @escaping (Error) -> Void) {
        data(with: request, options: options)
            .subscribe(onSuccess: { (data) in
                success(data)
            }) { (error) in
                failure(error)
            }
            .disposed(by: disposeBag)
    }
}

@objc public class KBRequestParameters: NSObject {
    @objc public var expiryDate: Date?
    @objc public var readPolicy: KBReadPolicy = .cache
    @objc public var writePolicy: KBWritePolicy = .memory
}

// Specify how data should be read
@objc public enum KBReadPolicy: Int {
    case cache // Check the local storage for a copy first
    case network // Force a network fetch
}

// Specify how the data should be saved
@objc public enum KBWritePolicy: Int {
    case none // Don't save anything
    case memory // Write only to memory
    case disk // Write to device
}
