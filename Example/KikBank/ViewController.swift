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

    private var storageManager: KBStorageManagerType
    private var downloadManager: KBDownloadManagerType
    private var kikBank: KikBankType

    private lazy var disposeBag = DisposeBag()

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.frame = self.view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    
    required init?(coder aDecoder: NSCoder) {
        self.storageManager = KBStorageManager(pathExtension: "kbDemo")
        self.downloadManager = KBDownloadManager()
        self.kikBank = KikBank(storageManager: self.storageManager, downloadManager: self.downloadManager)
        super.init(coder: aDecoder)
    }

    override func loadView() {
        super.loadView()

        view.addSubview(imageView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let url = URL(string: "https://placekitten.com/g/300/300")!

        let options = KBParameters()
        options.readOption = .any
        options.writeOption = .memory

        kikBank
            .data(with: url, options: options)
            .map { (data) -> UIImage? in
                return UIImage(data: data)
            }
            .asObservable()
            .bind(to: imageView.rx.image)
            .disposed(by: disposeBag)

        print("Sleep 1")
        sleep(3)

        imageView.image = nil

        print("Sleep 2")
        sleep(3)

        kikBank
            .data(with: url, options: options)
            .map { (data) -> UIImage? in
                return UIImage(data: data)
            }
            .asObservable()
            .bind(to: imageView.rx.image)
            .disposed(by: disposeBag)
    }
}

