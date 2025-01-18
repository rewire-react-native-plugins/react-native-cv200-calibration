// VideoViewManager.h
// Author: Faruk Aslan - 18.11.2024
#import <React/RCTViewManager.h>
#import "VideoView.h"
@interface VideoViewManager : RCTViewManager

+ (VideoView *)getVideoViewInstance;

@end
