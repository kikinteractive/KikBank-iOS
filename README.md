# KikBank

[![CI Status](http://img.shields.io/travis/JamesRagnar/KikBank.svg?style=flat)](https://travis-ci.org/JamesRagnar/KikBank)
[![Version](https://img.shields.io/cocoapods/v/KikBank.svg?style=flat)](http://cocoapods.org/pods/KikBank)
[![License](https://img.shields.io/cocoapods/l/KikBank.svg?style=flat)](http://cocoapods.org/pods/KikBank)
[![Platform](https://img.shields.io/cocoapods/p/KikBank.svg?style=flat)](http://cocoapods.org/pods/KikBank)

## Use

Currently KikBank offers basic fetch and cache mechanisms, with a few options on how the data is requested and stored.

After creating an instance of KikBank...

```swift
let kikBank = KikBank()
```

provide the url the data can be found at, KikBank will return a Single<Data> observable that you can map or bind as needed.

```swift
let url = URL(string: "https://placekitten.com/g/300/300")!
let dataObservable = kikBank.data(with: url, options: KBRequestParameters())

// you can bind this to a UIImageView, etc.
dataObservable
    .map { (data) -> UIImage? in
        return UIImage(data: data)
    }
    .asObservable()
    .bind(to: imageView.rx.image)
    .disposed(by: disposeBag)
```

The KBRequestParameters struct handles the fetch and cache types. By default, it will check in memory for a copy of the data, and then do a network request. You can change the KBReadPolicy and KBWritePolicy enums to force a network fetch, handle memory and disk storage, and more. Additionally, set the expiryDate property to invalidate the cached data after a set time.

## TODO

* Retry logic
* More cache/timeout policies
* Cache Versioning
* Modify concurrent network request count

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

KikBank is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'KikBank'
```

## Author

James Harquail, ragnar@kik.com

## License

KikBank is available under the MIT license. See the LICENSE file for more info.
