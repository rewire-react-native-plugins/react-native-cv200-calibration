// VideoView.h
// Author: Faruk Aslan - 18.11.2024
#import <UIKit/UIKit.h>
#import <React/RCTComponent.h>

@interface VideoView : UIView

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
