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

    private let url: URL
    private let urlSession: URLSession

    public var result: RequestResult?

    init(url: URL, urlSession: URLSession = .shared) {
        self.url = url
        self.urlSession = urlSession
    }

    override func main() {
        guard !isCancelled else {
            _finished = true
            return
        }

        _executing = true

        let request = urlSession.dataTask(with: url) { [weak self] (data, response, error) in
            self?.result = (data, response, error)
            self?._executing = false
            self?._finished = true
        }

        request.resume()
    }
}
