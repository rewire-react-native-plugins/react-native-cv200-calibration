import {NativeModules, Platform} from 'react-native';

const {VideoDecoder} = NativeModules;

const decodeFrame = async (
  yuvData: number[],
  width: number,
  height: number,
) => {
  try {
    if (Platform.OS === 'android') {
      await VideoDecoder.decodeFrame(yuvData, width, height);
    } else {
      await VideoDecoder.decodeFrame(yuvData);
    }
  } catch (error) {
    console.error('Decode Error:', error);
  }
};

export default {decodeFrame};
