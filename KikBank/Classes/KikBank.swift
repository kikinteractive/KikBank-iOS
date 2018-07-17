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
    var logger: KBLoggerType { get set }
}

public class KikBank {

    private struct Constants {
        static let pathExtension = "KBStorage"
    }

    public var downloadManager: KBDownloadManagerType
    public var storageManager: KBStorageManagerType

    public var logger: KBLoggerType = KBLogger() {
        didSet {
            downloadManager.logger = logger
            storageManager.logger = logger
        }
    }

    private lazy var saveOperation = PublishSubject<(KBAssetType, KBParameters)>()
    private lazy var disposeBag = DisposeBag()

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
        saveOperation.subscribe(onNext: { [weak self] (asset, options) in
            self?.runSaveOperation(asset: asset, options: options)
        }).disposed(by: disposeBag)
    }

    private func runSaveOperation(asset: KBAssetType, options: KBParameters) {
        storageManager
            .store(asset, writeOption: options.writeOption)
            .subscribe()
            .disposed(by: disposeBag)
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
            let identifier = request.url?.absoluteString.hashValue // Rethink this
            else {
                return .error(KBError.badRequest)
        }

        // Prepare the read operation
        let readOperation = storageManager.fetch(identifier, readOption: options.readOption)

        // Prepare the download operation
        let downloadOperation = downloadManager.downloadData(with: request)

        // Prepare the asset generation operation
        let assetOperation = downloadOperation.map { (data) -> KBDataAssetType in
            return KBDataAsset(identifier: identifier, data: data)
        }

        // If the read options don't include memory or disk reads, use the download instead
        return readOperation
            .catchError { (error) -> Single<KBAssetType> in
                if !options.readOption.contains(.network) {
                    // We have no network read, abort
                    return .error(KBError.badRequest)
                }

                return assetOperation.map({ (dataAsset) -> KBAssetType in
                    return dataAsset
                })
            }.flatMap({ (asset) -> Single<Data> in
                // If needed, add action to caching queue
                if options.writeOption.contains(.memory) || options.writeOption.contains(.disk) {
                    self.saveOperation.onNext((asset, options))
                }

                if let asset = asset as? KBDataAssetType {
                    return .just(asset.data)
                }

                return .error(KBError.badRequest)
            })
    }
}
