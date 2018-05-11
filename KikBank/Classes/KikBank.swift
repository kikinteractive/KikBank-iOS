//
//  KikBank.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import RxSwift

enum KBError: Error {
    case deallocated
    case badRequest
}

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

    private lazy var storageQueue = PublishSubject<(KBAssetType, KBParameters)>()

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
        bind()
    }

    private func bind() {
        storageQueue
            .subscribe(onNext: { [weak self] (asset, options) in
                guard let this = self else {
                    return
                }

                this.runSaveAction(with: asset, options: options)
            })
            .disposed(by: disposeBag)
    }

    private func runSaveAction(with asset: KBAssetType, options: KBParameters) {
        storageManager
            .store(asset, writeOptions: options.writeOptions).subscribe(onCompleted: { [weak self] in
                guard let this = self else {
                    return
                }

                this.logger.log(verbose: "Saved")
            }) { [weak self] (error) in
                guard let this = self else {
                    return
                }

                this.logger.log(error: "Error \(error)")
            }.disposed(by: disposeBag)
    }

    private func readRequest(for key: String) -> Single<KBAssetType> {
        return Single.error(NSError())
    }

    private func saveAsset(_ asset: KBAssetType, with options: KBParameters) {

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
            let uuid = request.url?.absoluteString.hashValue.description, // Rethink this
            uuid != ""
            else {
                return .error(KBError.badRequest)
        }

        // Cache only request
        if options.readOptions == .cache {
            return storageManager
                .fetch(uuid, readOptions: options.readOptions)
                .flatMap({ (asset) -> Single<Data> in
                    return .just(asset.data)
                })
        }

        // This is incomplete, still needs to check cache for value
        //
        //
        
        let download = downloadManager.downloadData(with: request)

        // Write request
        if options.writeOptions == .disk || options.writeOptions == .memory {
            download.subscribe(onSuccess: { [weak self] (data) in
                guard let this = self else {
                    return
                }

                let asset = KBAsset(uuid: uuid, data: data)
                this.storageQueue.onNext((asset, options))
            })
            .disposed(by: disposeBag)
        }

        return download
    }
}
