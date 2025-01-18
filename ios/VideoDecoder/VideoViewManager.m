// VideoViewManager.m
// Author: Faruk Aslan - 18.11.2024
#import "VideoViewManager.h"
#import "VideoView.h"

@implementation VideoViewManager

RCT_EXPORT_MODULE()

static VideoView *videoViewInstance = nil;

- (UIView *)view {
  videoViewInstance = [[VideoView alloc] init];
  return videoViewInstance;
}

+ (VideoView *)getVideoViewInstance {
  return videoViewInstance;
}

@end
