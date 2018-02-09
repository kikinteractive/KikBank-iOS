//
//  ObjCBridgeCheck.m
//  KikBank_Example
//
//  Created by James Harquail on 2018-02-09.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

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

- (void)checkObjcBridge
{
    KBRequestParameters *params = [KBRequestParameters new];
    [params setWritePolicy:KBWritePolicyMemory];
    [params setReadPolicy:KBReadPolicyCache];
    [params setExpiryDate:NULL];

    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://placekitten.com/g/300/300"]];

    [_kikBank dataWith:request options:params success:^(NSData * _Nonnull data) {
        NSLog(@"Got data");
    } failure:^(NSError * _Nonnull error) {
        NSLog(@"Got error %@", error.localizedDescription);
    }];
}

@end
