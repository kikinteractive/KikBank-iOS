//
//  ObjCBridgeCheck.m
//  KikBank_Example
//
//  Created by James Harquail on 2018-02-09.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

/*
 *  This is just to make sure that I'm bridging to objc correctly
 */
#import <Foundation/Foundation.h>
#import <KikBank/KikBank-Swift.h>

@interface ObjCBridgeCheck: NSObject

@property (nonatomic, strong) KikBank *kikBank;

@end

@implementation ObjCBridgeCheck

- (id)init
{
    self = [super init];
    if (self) {
        _kikBank = [KikBank new];
    }
    return self;
}

- (void)checkParams
{
    KBParameters *params = [KBParameters new];
    [params setWritePolicy:KBWritePolicyMemory];
    [params setReadPolicy:KBReadPolicyCache];
    [params setExpiryDate:NULL];
}

- (void)checkKikBankBridge
{
    KBParameters *params = [KBParameters new];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://placekitten.com/g/300/300"]];

    [_kikBank dataWith:request options:params success:^(NSData * _Nonnull data) {
        NSLog(@"Got data");
    } failure:^(NSError * _Nonnull error) {
        NSLog(@"Got error %@", error.localizedDescription);
    }];
}

- (void)checkDownloadManagerBridge
{
    KBDownloadManager *downloadManager = [KBDownloadManager new];
    [downloadManager setMaxConcurrentOperationCount:1];

    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://placekitten.com/g/300/300"]];

    [downloadManager downloadDataWith:request success:^(NSData * _Nonnull data) {
        NSLog(@"Got data");
    } failure:^(NSError * _Nonnull error) {
        NSLog(@"Got error %@", error.localizedDescription);
    }];
}

- (void)checkStorageManagerBridge
{
    KBParameters *params = [KBParameters new];

    KBStorageManager *storageManager = [KBStorageManager new];
    [storageManager store:@"test" data:[NSData new] options:params];
}

@end
