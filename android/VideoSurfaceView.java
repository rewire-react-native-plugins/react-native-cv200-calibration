// VideoSurfaceView.java
package com.rem.rewire;

import android.content.Context;
import android.graphics.SurfaceTexture;
import android.util.AttributeSet;
import android.view.TextureView;
import android.view.Surface;

public class VideoSurfaceView extends TextureView implements TextureView.SurfaceTextureListener {
    private Surface surface;
    private VideoDecoderModule decoderModule;

    public VideoSurfaceView(Context context) {
        super(context);
        init();
    }

    public VideoSurfaceView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public VideoSurfaceView(Context context, AttributeSet attrs, int defStyle) {
        super(context, attrs, defStyle);
        init();
    }

    private void init() {
        setSurfaceTextureListener(this);
    }

    public void setDecoderModule(VideoDecoderModule module) {
        this.decoderModule = module;
        if (surface != null && decoderModule != null) {
            decoderModule.setSurface(surface);
        }
    }

    @Override
    public void onSurfaceTextureAvailable(SurfaceTexture surfaceTexture, int width, int height) {
        surface = new Surface(surfaceTexture);
        if (decoderModule != null) {
            decoderModule.setSurface(surface);
        }
    }

    @Override
    public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) {
    }

    @Override
    public boolean onSurfaceTextureDestroyed(SurfaceTexture surfaceTexture) {
        if (decoderModule != null) {
            decoderModule.release();
        }
        if (surface != null) {
            surface.release();
            surface = null;
        }
        return true;
    }

    @Override
    public void onSurfaceTextureUpdated(SurfaceTexture surface) {
    }
}
