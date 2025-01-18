// VideoDecoderModule.java
/*
 * Author: Faruk Aslan
 * Date: 01.12.2024
 * Description: This is a video decoder module for React Native. (CV200 Device)
 */
package com.rem.rewire;

import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.util.Log;
import android.view.Surface;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.module.annotations.ReactModule;

import java.nio.ByteBuffer;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;

@ReactModule(name = VideoDecoderModule.NAME)
public class VideoDecoderModule extends ReactContextBaseJavaModule {
    public static final String NAME = "VideoDecoder";
    private static final String TAG = "VideoDecoderModule";

    private MediaCodec decoder;
    private boolean isDecoderConfigured = false;

    private BlockingQueue<byte[]> frameQueue = new LinkedBlockingQueue<>();
    private byte[] sps;
    private byte[] pps;

    private long frameIndex = 0;

    private Surface surface;

    private ReactApplicationContext reactContext;

    private int videoWidth = 640;
    private int videoHeight = 380;

    public VideoDecoderModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
        initDecoder();
    }

    @NonNull
    @Override
    public String getName() {
        return NAME;
    }

    /**
     * Start MediaCodec
     */
    private synchronized void initDecoder() {
        try {
            decoder = MediaCodec.createDecoderByType("video/avc");

            MediaCodecInfo codecInfo = decoder.getCodecInfo();
            MediaCodecInfo.CodecCapabilities capabilities = codecInfo.getCapabilitiesForType("video/avc");
        } catch (Exception e) {
            Log.e(TAG, "Decoder oluşturulamadı.", e);
            decoder = null;
        }
    }

    /**
     * Yuv data decode
     *
     * @param dataArray YUV data array
     * @param width     Width
     * @param height    Height
     * @param promise   Promise
     */
    @ReactMethod
    public synchronized void decodeFrame(com.facebook.react.bridge.ReadableArray dataArray, int width, int height, Promise promise) {
        try {
            int length = dataArray.size();
            byte[] data = new byte[length];
            for (int i = 0; i < length; i++) {
                data[i] = (byte) dataArray.getInt(i);
            }
            processNalUnits(data, width, height);

            promise.resolve(null);
        } catch (Exception e) {
            promise.reject("DecodeError", e);
        }
    }

    private ByteBuffer nalBuffer = ByteBuffer.allocate(1024 * 1024);

    private synchronized void processNalUnits(byte[] data, int width, int height) {
        nalBuffer.put(data);

        nalBuffer.flip();
        while (true) {
            int startCodeIndex = findStartCode(nalBuffer);
            if (startCodeIndex == -1) {
                nalBuffer.compact();
                break;
            }

            
            nalBuffer.position(startCodeIndex);

            
            int nextStartCodeIndex = findNextStartCode(nalBuffer);
            if (nextStartCodeIndex == -1) {
                nalBuffer.position(startCodeIndex);
                nalBuffer.compact();
                break;
            }

            int nalUnitLength = nextStartCodeIndex - startCodeIndex;
            byte[] nalUnit = new byte[nalUnitLength];
            nalBuffer.get(nalUnit);

            if (nalUnit.length < 5) {
                continue;
            }
            int nalUnitType = nalUnit[4] & 0x1F;

            if (nalUnitType == 7) {
                sps = nalUnit;
            } else if (nalUnitType == 8) {
                pps = nalUnit;
               
                if (!isDecoderConfigured) {
                    videoWidth = width;
                    videoHeight = height;
                    configureDecoder(width, height);
                }
            } else {
                frameQueue.add(nalUnit);
            }
        }

        processFrames();
    }

    private int findStartCode(ByteBuffer buffer) {
        for (int i = buffer.position(); i < buffer.limit() - 3; i++) {
            if (buffer.get(i) == 0x00 && buffer.get(i + 1) == 0x00) {
                if (buffer.get(i + 2) == 0x00 && buffer.get(i + 3) == 0x01) {
                    return i;
                } else if (buffer.get(i + 2) == 0x01) {
                    return i;
                }
            }
        }
        return -1;
    }

    private int findNextStartCode(ByteBuffer buffer) {
        for (int i = buffer.position() + 4; i < buffer.limit() - 3; i++) {
            if (buffer.get(i) == 0x00 && buffer.get(i + 1) == 0x00) {
                if (buffer.get(i + 2) == 0x00 && buffer.get(i + 3) == 0x01) {
                    return i;
                } else if (buffer.get(i + 2) == 0x01) {
                    return i;
                }
            }
        }
        return -1;
    }

    /**
     * Configure MediaDecoder and start
     *
     * @param width  Video width
     * @param height Video height
     */
    private synchronized void configureDecoder(int width, int height) {
        if (sps == null || pps == null) {
            return;
        }

        if (decoder == null) {
            return;
        }

        MediaFormat format = MediaFormat.createVideoFormat("video/avc", width, height);
        format.setByteBuffer("csd-0", ByteBuffer.wrap(sps));
        format.setByteBuffer("csd-1", ByteBuffer.wrap(pps));

        try {
            decoder.configure(format, surface, null, 0);
            decoder.start();
            isDecoderConfigured = true;
            videoWidth = width;
            videoHeight = height;
        } catch (Exception e) {
            isDecoderConfigured = false;
        }
    }

    private synchronized void decode() {
        if (!isDecoderConfigured) {
            return;
        }

        if (decoder == null) {
            return;
        }

        while (!frameQueue.isEmpty()) {
            byte[] nalUnit = frameQueue.poll();
           
            try {
                int inputBufferIndex = decoder.dequeueInputBuffer(10000);
                if (inputBufferIndex >= 0) {
                    ByteBuffer inputBuffer = decoder.getInputBuffer(inputBufferIndex);
                    if (inputBuffer != null) {
                        inputBuffer.clear();
                        inputBuffer.put(nalUnit);

                        long presentationTimeUs = computePresentationTime(frameIndex);
                        frameIndex++;

                        decoder.queueInputBuffer(inputBufferIndex, 0, nalUnit.length, presentationTimeUs, 0);
                    }
                } else {
                    continue;
                }

                // Output buffer
                MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();
                int outputBufferIndex;

                do {
                    outputBufferIndex = decoder.dequeueOutputBuffer(bufferInfo, 10000);
                    if (outputBufferIndex >= 0) {
                        decoder.releaseOutputBuffer(outputBufferIndex, true);
                    } else if (outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        MediaFormat newFormat = decoder.getOutputFormat();
                    } else if (outputBufferIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                        Log.d(TAG, "No output buffer");
                    }
                } while (outputBufferIndex >= 0);
            } catch (IllegalStateException e) {
                Log.e(TAG, "IllegalStateException for decoder", e);
                resetDecoder();
                return;
            } catch (Exception e) {
                Log.e(TAG, "General error for decoder", e);
                resetDecoder();
                return;
            }
        }
    }

    private synchronized void resetDecoder() {
        if (decoder != null) {
            try {
                decoder.stop();
                decoder.release();
            } catch (Exception e) {
                Log.e(TAG, "Error for stop and release decoder", e);
            }
            decoder = null;
        }
        isDecoderConfigured = false;
        // Re-initialize decoder
        initDecoder();
        if (decoder != null && sps != null && pps != null && surface != null) {
            configureDecoder(640, 368); 
        }
    }

    private long computePresentationTime(long frameIndex) {
        return frameIndex * 1000000 / 30;
    }

    private synchronized void processFrames() {
        new Thread(new Runnable() {
            @Override
            public void run() {
                decode();
            }
        }).start();
    }

    /**
     * Set Surface reference
     *
     * @param surface Surface
     */
    public synchronized void setSurface(Surface surface) {
        this.surface = surface;
        if (!isDecoderConfigured && sps != null && pps != null) {
            configureDecoder(videoWidth, videoHeight); 
        }
    }

    /**
     * Release MediaCodec
     */
    public synchronized void release() {
        resetDecoder();
    }
}
