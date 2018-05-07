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

    /// Get data available at the provided URL
    ///
    /// - Parameter url: The URL of the data
    /// - Returns: A Single Observable of the data fetch operation
    func data(with url: URL) -> Single<Data>

    /// Get data available at the provided URL
    ///
    /// - Parameters:
    ///   - url: The URL of the data
    ///   - options: The fetch policies of the requested data
    /// - Returns: A Single Observable of the data fetch operation
    func data(with url: URL, options: KBParameters) -> Single<Data>

    /// Get data available at the provided URLRequest
    ///
    /// - Parameter request: The URLRequest of the requested data
    /// - Returns: A Single Observable of the data fetch operation
    func data(with request: URLRequest) -> Single<Data>


    /// Get data available at the provided URLRequest
    ///
    /// - Parameters:
    ///   - request: The URLRequest of the requested data
    ///   - options: The fetch policies of the requested data
    /// - Returns: A Single Observable of the data fetch operation
    func data(with request: URLRequest, options: KBParameters) -> Single<Data>

    /// The bank request manager
    ///
    var downloadManager: KBDownloadManagerType { get }

    /// The bank storage manager
    ///
    var storageManager: KBStorageManagerType { get }

    /// The static logger
    ///
    var logger: KBStaticLoggerType.Type { get set }
}

public class KikBank {

    private struct Constants {
        static let pathExtension = "KBStorage"
    }
    
    private lazy var disposeBag = DisposeBag()

    public var downloadManager: KBDownloadManagerType
    public var storageManager: KBStorageManagerType

    public var logger: KBStaticLoggerType.Type = KBStaticLogger.self {
        didSet {
            downloadManager.logger = logger
            storageManager.logger = logger
        }
    }

    public convenience init() {
        let storageManager = KBStorageManager(pathExtension: Constants.pathExtension)
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
        let request = URLRequest(url: url)
        return data(with: request, options: KBParameters())
    }

    public func data(with url: URL, options: KBParameters) -> Single<Data> {
        let request = URLRequest(url: url)
        return data(with: request, options: options)
    }

    public func data(with request: URLRequest) -> Single<Data> {
        return data(with: request, options: KBParameters())
    }

    public func data(with request: URLRequest, options: KBParameters) -> Single<Data> {
        guard
            let uuid = request.url?.absoluteString.hashValue.description,
            uuid != ""
            else {
                return .error(NSError())
        }

        // Check if there is an existing record
        if options.readPolicy == .cache,
            let asset = storageManager.fetch(uuid) as? KBAsset {
            return .just(asset.data)
        }

        // Create a new record and fetch
        let download = downloadManager.downloadData(with: request)

        // Cache on completion
        download
            .subscribe(onSuccess: { [weak self] (data) in
                _ = self?.storageManager.store(uuid, asset: KBAsset(uuid: uuid, data: data), options: options)
                }, onError: { [weak self] (error) in
                    self?.logger.log(error: "KikBank - \(error)")
            })
            .disposed(by: disposeBag)

        return download
    }
}

extension KikBank {

    @objc public func data(with request: URLRequest, options: KBParameters, success: @escaping (Data) -> Void, failure: @escaping (Error) -> Void) {
        data(with: request, options: options)
            .subscribe(onSuccess: { (data) in
                success(data)
            }) { (error) in
                failure(error)
            }
            .disposed(by: disposeBag)
    }
}
