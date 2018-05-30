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

    private lazy var downloadManager = KBDownloadManager()
    private lazy var storageManager = KBStorageManager(pathExtension: "kikBankExample")

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


    }

}

