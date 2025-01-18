// VideoDecoder.h
// Author: Faruk Aslan - 18.11.2024
#import <React/RCTBridgeModule.h>
#import <Foundation/Foundation.h>

@interface VideoDecoder : NSObject <RCTBridgeModule>

- (void)decodeFrame:(NSArray *)dataArray;

@end
