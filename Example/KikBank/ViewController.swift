//
//  ViewController.swift
//  KikBank
//
//  Created by JamesRagnar on 02/07/2018.
//  Copyright (c) 2018 JamesRagnar. All rights reserved.
//

import UIKit
import KikBank
import RxSwift
import RxCocoa

class ViewController: UIViewController {

    private lazy var kikBank = KikBank()
    private lazy var disposeBag = DisposeBag()

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.frame = self.view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override func loadView() {
        super.loadView()

        view.addSubview(imageView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let url = URL(string: "https://placekitten.com/g/300/300")!

        let fetchPolicy = KBParameters()
        fetchPolicy.writeOptions = .all
        fetchPolicy.readOptions = .cacheOnly

        kikBank
            .data(with: url, options: fetchPolicy)
            .map { (data) -> UIImage? in
                return UIImage(data: data)
            }
            .asDriver(onErrorJustReturn: nil)
            .asObservable()
            .bind(to: imageView.rx.image)
            .disposed(by: disposeBag)
    }
}

