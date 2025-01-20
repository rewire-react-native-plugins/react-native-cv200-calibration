
## IOS

Follow these steps for the iOS setup:

- First, copy the "VideoDecoder" folder located in the "ios" directory to the "your-project/ios" directory.
- Open your project in XCode and ensure that the files "VideoView.m", "VideoDecoder.m", and "VideoViewManager.m" are included in the "Build Phases->Compile Sources" section. (If they are not added automatically, you must manually add them from the folder you included in the previous step.)



## ANDROID

Follow these steps for the Android setup:

- First, copy the files from the "android" folder to the following directory in your project: "your-project/android/app/src/main/java/{your-bundle-name}/". -- (MainActivity.java and MainApplication.java should already exist in this directory.)
- In the 4 files you copied, replace "com.rem.rewire" with "your-project-bundle-name". -- (This is usually found at the top of each file as package com.rem.rewire)

"In the "MainApplication.java" file:

```bash
 protected List<ReactPackage> getPackages() {
```

add the following line inside:

```bash
 packages.add(new VideoDecoderPackage());
```


## REACT NATIVE IMPLEMENTATION

- To use the structure in your React-Native application, copy the "Decoder.bridge.tsx", "VideoCodec.tsx", and "VideoSurface.component.tsx" files into the src directory of your project.
- In your project, call the following code where you want to display the camera feed:

```bash
 <VideoCodec IP="{CV200_DEVICE_IP}" SOCKET_PORT={CV_200_DEVICE_WS_PORT} />
