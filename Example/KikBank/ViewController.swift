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
import Foundation

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

        let options1 = KBParameters()
        options1.readOption = .network
        options1.writeOption = [.memory, .disk]

        kikBank
            .data(with: url, options: options1)
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

        let options2 = KBParameters()
        options2.readOption = .memory
        options2.writeOption = .none

        kikBank
            .data(with: url, options: options2)
            .map { (data) -> UIImage? in
                return UIImage(data: data)
            }
            .asObservable()
            .bind(to: imageView.rx.image)
            .disposed(by: disposeBag)
        
        imageView.image = nil
        
        print("Sleep 3")
        sleep(3)
        
        let options3 = KBParameters()
        options3.readOption = .disk
        options3.writeOption = .none
        
        kikBank
            .data(with: url, options: options3)
            .map { (data) -> UIImage? in
                return UIImage(data: data)
            }
            .asObservable()
            .bind(to: imageView.rx.image)
            .disposed(by: disposeBag)
    }
}
