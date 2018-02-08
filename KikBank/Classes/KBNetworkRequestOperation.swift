//
//  KBNetworkRequestOperation.swift
//  KikBank
//
//  Created by James Harquail on 2018-02-07.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation

class KBNetworkRequestOperation: KBAsyncOperation {

    typealias RequestResult = (data: Data?, response: URLResponse?, error: Error?)

    private let request: URLRequest
    private let session: URLSession = .shared
    private var dataTask: URLSessionDataTask?

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
