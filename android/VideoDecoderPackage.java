// VideoDecoderPackage.java
/*
 * Author: Faruk Aslan
 * Date: 01.12.2024
 * Description: This is a video decoder package for React Native. (CV200 Device)
 */
package com.rem.rewire;

import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.ViewManager;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class VideoDecoderPackage implements ReactPackage {

    private VideoDecoderModule decoderModule;

    public VideoDecoderPackage() {

    }

    @Override
    public List<NativeModule> createNativeModules(ReactApplicationContext reactContext) {
        decoderModule = new VideoDecoderModule(reactContext);
        List<NativeModule> modules = new ArrayList<>();
        modules.add(decoderModule);
        return modules;
    }

    @Override
    public List<ViewManager> createViewManagers(ReactApplicationContext reactContext) {
        List<ViewManager> managers = new ArrayList<>();
        if (decoderModule != null) {
            managers.add(new VideoSurfaceViewManager(decoderModule));
        } else {
            android.util.Log.e("VideoDecoderPackage", "VideoDecoderModule instance is null");
        }
        return managers;
    }
}
