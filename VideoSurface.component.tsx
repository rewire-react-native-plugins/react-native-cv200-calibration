import {requireNativeComponent, ViewPropTypes, Platform} from 'react-native';
import React from 'react';

const VideoSurfaceView = requireNativeComponent('VideoSurfaceView');
const VideoView = requireNativeComponent('VideoView');

const CV200VideoSurface = props => {
  if (Platform.OS === 'ios') {
    return <VideoView {...props} />;
  } else {
    return <VideoSurfaceView {...props} />;
  }
};

CV200VideoSurface.propTypes = {
  style: ViewPropTypes.style,
};

export default CV200VideoSurface;