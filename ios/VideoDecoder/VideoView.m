// VideoView.m
// Author: Faruk Aslan - 18.11.2024
#import "VideoView.h"
#import <AVFoundation/AVFoundation.h>

@interface VideoView()

@property (nonatomic, strong) AVSampleBufferDisplayLayer *videoLayer;

@end

@implementation VideoView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
    self.videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.videoLayer.backgroundColor = [UIColor blackColor].CGColor;
    [self.layer addSublayer:self.videoLayer];

    // Observe status and error properties using KVO
    [self.videoLayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
  }
  return self;
}

- (void)dealloc {
  [self.videoLayer removeObserver:self forKeyPath:@"status"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
  if ([keyPath isEqualToString:@"status"]) {
    AVQueuedSampleBufferRenderingStatus status = self.videoLayer.status;
    NSError *error = self.videoLayer.error;
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  dispatch_async(dispatch_get_main_queue(), ^{
    self.videoLayer.frame = self.bounds;
    self.videoLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
  });
}

NSString* NSStringFromOSType(OSType osType) {
  char str[5];
  *(UInt32 *)str = CFSwapInt32HostToBig(osType);
  str[4] = '\0';
  return [NSString stringWithCString:str encoding:NSASCIIStringEncoding];
}

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer {
  if (pixelBuffer == NULL) {
    return;
  }
  
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    NSString *pixelFormatString = NSStringFromOSType(pixelFormat);

    if (pixelFormat != kCVPixelFormatType_32BGRA) {
      return;
    }

  size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    NSLog(@"Decoded frame size: %zu x %zu", width, height);
  
  CMVideoFormatDescriptionRef videoInfo = NULL;
  OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
  if (status != noErr) {
    NSLog(@"CMVideoFormatDescription not created, error code: %d", (int)status);
    return;
  }

  CMSampleBufferRef sampleBuffer = NULL;
  // Zaman damgasını ayarlama
  static int64_t frameNumber = 0;
  CMTime presentationTimeStamp = CMTimeMake(frameNumber++, 30); // default 30 fps
  CMSampleTimingInfo timingInfo = {
      .duration = CMTimeMake(1, 30),
      .presentationTimeStamp = presentationTimeStamp,
      .decodeTimeStamp = kCMTimeInvalid
    };

  status = CMSampleBufferCreateReadyWithImageBuffer(NULL, pixelBuffer, videoInfo, &timingInfo, &sampleBuffer);
  if (status != noErr) {
    CFRelease(videoInfo);
    return;
  }

  if (![self.videoLayer isReadyForMoreMediaData]) {
    NSLog(@"videoLayer not ready");
  }

  [self.videoLayer enqueueSampleBuffer:sampleBuffer];

  CFRelease(sampleBuffer);
  CFRelease(videoInfo);

  // Increment the time base
  CMTime nextTime = CMTimeAdd(presentationTimeStamp, timingInfo.duration);
  CMTimebaseSetTime(self.videoLayer.controlTimebase, nextTime);
}



@end
