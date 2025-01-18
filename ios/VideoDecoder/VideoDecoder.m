// VideoDecoder.m
// Author: Faruk Aslan - 18.11.2024
#import "VideoDecoder.h"
#import <React/RCTLog.h>
#import <VideoToolbox/VideoToolbox.h>
#import "VideoViewManager.h"

@interface VideoDecoder() {
  VTDecompressionSessionRef decompressionSession;
  CMVideoFormatDescriptionRef formatDescription;
  dispatch_queue_t decodeQueue;
}

@property (nonatomic, strong) NSMutableData *naluBuffer;
@property (nonatomic, strong) NSData *spsData;
@property (nonatomic, strong) NSData *ppsData;

@end

@implementation VideoDecoder

RCT_EXPORT_MODULE();

- (instancetype)init {
  if (self = [super init]) {
    formatDescription = NULL;
    decompressionSession = NULL;
    decodeQueue = dispatch_queue_create("decodeQueue", DISPATCH_QUEUE_SERIAL);
    self.naluBuffer = [NSMutableData data];
  }
  return self;
}

- (void)invalidate {
  if (decompressionSession) {
    VTDecompressionSessionInvalidate(decompressionSession);
    CFRelease(decompressionSession);
    decompressionSession = NULL;
  }
  if (formatDescription) {
    CFRelease(formatDescription);
    formatDescription = NULL;
  }
}

- (void)dealloc {
  [self invalidate];
}

RCT_EXPORT_METHOD(decodeFrame:(NSArray *)dataArray) {
  NSUInteger length = [dataArray count];
  uint8_t *buffer = malloc(sizeof(*buffer) * length);
  for (NSUInteger i = 0; i < length; i++) {
    buffer[i] = [[dataArray objectAtIndex:i] unsignedCharValue];
  }
  NSData *data = [NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES];

  // Decode the H.264 data
  dispatch_async(decodeQueue, ^{
    [self decode:data];
  });
}

- (void)decode:(NSData *)data {
  // Split the incoming data into NAL units
  [self.naluBuffer appendData:data];

  // Process NAL units
  while (true) {
    // Find the start code of the NAL unit
    NSRange startCodeRange = [self findStartCode:self.naluBuffer];
    if (startCodeRange.location == NSNotFound || startCodeRange.location + startCodeRange.length >= self.naluBuffer.length) {
      // Start code not found or the full NAL unit hasn't arrived yet
      break;
    }

    // Find the next start code
    NSRange nextStartCodeRange = [self findStartCode:self.naluBuffer startFrom:startCodeRange.location + startCodeRange.length];
    NSUInteger naluLength = 0;
    if (nextStartCodeRange.location != NSNotFound) {
      naluLength = nextStartCodeRange.location - startCodeRange.location;
    } else {
      naluLength = self.naluBuffer.length - startCodeRange.location;
    }

    // Get the NAL unit
    NSData *naluData = [self.naluBuffer subdataWithRange:NSMakeRange(startCodeRange.location, naluLength)];

    // Process the NAL unit
    [self processNALUnit:naluData];

    // Remove the processed NAL unit from the buffer
    [self.naluBuffer replaceBytesInRange:NSMakeRange(0, startCodeRange.location + naluLength) withBytes:NULL length:0];
  }
}

- (NSRange)findStartCode:(NSData *)data {
  return [self findStartCode:data startFrom:0];
}

- (NSRange)findStartCode:(NSData *)data startFrom:(NSUInteger)startIndex {
  const uint8_t *bytes = data.bytes;
  NSUInteger length = data.length;
  for (NSUInteger i = startIndex; i + 3 < length; i++) {
    if (bytes[i] == 0x00 && bytes[i+1] == 0x00) {
      if (bytes[i+2] == 0x01) {
        return NSMakeRange(i, 3);
      } else if (i + 4 < length && bytes[i+2] == 0x00 && bytes[i+3] == 0x01) {
        return NSMakeRange(i, 4);
      }
    }
  }
  return NSMakeRange(NSNotFound, 0);
}

- (void)processNALUnit:(NSData *)naluData {
  if (naluData.length < 4) {
    return;
  }

  const uint8_t *bytes = naluData.bytes;
  // Determine the length of the start code
  size_t startCodeLength = 0;
  if (bytes[2] == 0x01) {
    startCodeLength = 3;
  } else if (bytes[3] == 0x01) {
    startCodeLength = 4;
  } else {
    // Invalid start code
    return;
  }

  // Get the NAL unit header
  uint8_t nalUnitHeader = bytes[startCodeLength];
  uint8_t nalUnitType = nalUnitHeader & 0x1F;

  // Log the NAL unit type
  NSLog(@"Incoming NAL unit type: %d", nalUnitType);

  // Process SPS and PPS data
  if (nalUnitType == 7) {
    // SPS
    self.spsData = [naluData subdataWithRange:NSMakeRange(startCodeLength, naluData.length - startCodeLength)];
    NSLog(@"SPS data received, size: %lu", (unsigned long)self.spsData.length);
    [self createFormatDescription];
    return;
  } else if (nalUnitType == 8) {
    // PPS
    self.ppsData = [naluData subdataWithRange:NSMakeRange(startCodeLength, naluData.length - startCodeLength)];
    NSLog(@"PPS data received, size: %lu", (unsigned long)self.ppsData.length);
    [self createFormatDescription];
    return;
  } else if (nalUnitType == 6) {
    // Skip SEI messages
    return;
  }

  if (!decompressionSession) {
    NSLog(@"Decompression session not created.");
    return;
  }

  // Decode the NAL unit
  [self decodeNALUnit:naluData];
}

- (void)createFormatDescription {
  if (!self.spsData || !self.ppsData) {
    // SPS and PPS data not received yet
    return;
  }

  const uint8_t *parameterSetPointers[2] = { self.spsData.bytes, self.ppsData.bytes };
  const size_t parameterSetSizes[2] = { self.spsData.length, self.ppsData.length };

  OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
      NULL, 2, parameterSetPointers, parameterSetSizes, 4, &formatDescription);

  if (status != noErr) {
    NSLog(@"CMVideoFormatDescription not created, error code: %d", (int)status);
    return;
  }

  [self createDecompressionSession];
}

- (void)createDecompressionSession {
  if (decompressionSession) {
    VTDecompressionSessionInvalidate(decompressionSession);
    CFRelease(decompressionSession);
    decompressionSession = NULL;
  }

  NSDictionary *destinationPixelBufferAttributes = @{
    (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
  };

  VTDecompressionOutputCallbackRecord callbackRecord;
  callbackRecord.decompressionOutputCallback = decompressionOutputCallback;
  callbackRecord.decompressionOutputRefCon = (__bridge void *)self;

  OSStatus status = VTDecompressionSessionCreate(
      NULL, formatDescription, NULL, (__bridge CFDictionaryRef)(destinationPixelBufferAttributes), &callbackRecord, &decompressionSession);

  if (status != noErr) {
    NSLog(@"VTDecompressionSession not created, error code: %d", (int)status);
  } else {
    NSLog(@"Decompression session created successfully.");
  }
}


- (void)decodeNALUnit:(NSData *)naluData {
  // Add the length of the NAL unit (in big-endian format)
  uint32_t nalUnitLength = (uint32_t)(naluData.length - 4); // Subtract the start code
  uint32_t bigEndianLength = CFSwapInt32HostToBig(nalUnitLength);
  NSMutableData *annexBData = [NSMutableData dataWithBytes:&bigEndianLength length:4];
  [annexBData appendData:[naluData subdataWithRange:NSMakeRange(4, nalUnitLength)]];

  CMBlockBufferRef blockBuffer = NULL;
  OSStatus status = CMBlockBufferCreateWithMemoryBlock(
      NULL, (void *)[annexBData bytes], [annexBData length],
      kCFAllocatorNull, NULL, 0, [annexBData length],
      0, &blockBuffer);

  if (status != kCMBlockBufferNoErr) {
    NSLog(@"CMBlockBuffer not created, error code: %d", (int)status);
    return;
  }

  CMSampleBufferRef sampleBuffer = NULL;
  const size_t sampleSizeArray[] = { [annexBData length] };

  status = CMSampleBufferCreateReady(
      NULL, blockBuffer, formatDescription, 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);

  if (status != noErr) {
    NSLog(@"CMSampleBuffer not created, error code: %d", (int)status);
    CFRelease(blockBuffer);
    return;
  }

  VTDecodeFrameFlags flags = 0;
  VTDecodeInfoFlags flagOut;

  status = VTDecompressionSessionDecodeFrame(
      decompressionSession, sampleBuffer, flags, NULL, &flagOut);

  if (status != noErr) {
    NSLog(@"Decoding failed, error code: %d", (int)status);
  }

  CFRelease(sampleBuffer);
  CFRelease(blockBuffer);
}

// Decompression output callback function
void decompressionOutputCallback(
    void *decompressionOutputRefCon,
    void *sourceFrameRefCon,
    OSStatus status,
    VTDecodeInfoFlags infoFlags,
    CVImageBufferRef imageBuffer,
    CMTime presentationTimeStamp,
    CMTime presentationDuration) {

  if (status != noErr) {
    NSLog(@"Decoded frame not received, error code: %d", (int)status);
    return;
  }

  if (imageBuffer == NULL) {
    NSLog(@"imageBuffer is NULL");
    return;
  }

  CVPixelBufferRetain(imageBuffer);

  // Send to the main thread asynchronously
  dispatch_async(dispatch_get_main_queue(), ^{
    VideoView *videoView = [VideoViewManager getVideoViewInstance];
    if (videoView == nil) {
      NSLog(@"videoView is nil");
    } else {
      [videoView displayPixelBuffer:imageBuffer];
    }

    // Release the imageBuffer
    CVPixelBufferRelease(imageBuffer);
  });
}


@end
