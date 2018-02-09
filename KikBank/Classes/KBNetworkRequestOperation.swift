//
//  KBNetworkRequestOperation.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation

/// Subclass of KBAsyncOperation providing an async network request operation
class KBNetworkRequestOperation: KBAsyncOperation {

    typealias RequestResult = (data: Data?, response: URLResponse?, error: Error?)

    /// The URLRequest to be run
    private let request: URLRequest

    /// Convenience accessor for URLSession
    private let session: URLSession = .shared

    /// Reference to potentially running network data task
    private var dataTask: URLSessionDataTask?

    /// The network request result, should be access in the operation completion block
    public var result: RequestResult?

    convenience init(url: URL) {
        let request = URLRequest(url: url)
        self.init(request: request)
    }

    required init(request: URLRequest) {
        self.request = request
    }

    override func main() {
        guard !isCancelled else {
            _finished = true
            return
        }

        _executing = true

        dataTask = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            self?.result = (data, response, error)
            self?._executing = false
            self?._finished = true
        }
        
        dataTask?.resume()
    }

    deinit {
        dataTask?.cancel()
    }
}
