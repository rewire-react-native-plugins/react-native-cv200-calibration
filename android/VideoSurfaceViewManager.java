// VideoSurfaceViewManager.java
package com.rem.rewire;

import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;

import androidx.annotation.NonNull;
import android.util.Log;

public class VideoSurfaceViewManager extends SimpleViewManager<VideoSurfaceView> {
    public static final String REACT_CLASS = "VideoSurfaceView";
    private static final String TAG = "VideoSurfaceViewManager";

    private VideoDecoderModule decoderModule;

    public VideoSurfaceViewManager(VideoDecoderModule module) {
        this.decoderModule = module;
    }

    @NonNull
    @Override
    public String getName() {
        return REACT_CLASS;
    }

    @NonNull
    @Override
    protected VideoSurfaceView createViewInstance(@NonNull ThemedReactContext reactContext) {
        VideoSurfaceView view = new VideoSurfaceView(reactContext);
        if (decoderModule != null) {
            view.setDecoderModule(decoderModule);
        } else {
            Log.e(TAG, "VideoDecoderModule instance is null");
        }
        return view;
    }
}
