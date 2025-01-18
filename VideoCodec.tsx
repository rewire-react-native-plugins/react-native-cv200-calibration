import decodeFrame from './Decoder.bridge';
import CV200VideoSurface from './VideoSurface.component';
import {View, StyleSheet, useWindowDimensions, Image} from 'react-native';
import React, {useCallback, useEffect} from 'react';


interface VideoCodecProps {
  IP: string;
  SOCKET_PORT: number;
}

const VideoCodec: React.FC<VideoCodecProps> = ({IP, SOCKET_PORT}) => {
  const {width, height} = useWindowDimensions();
  const serverUrl = `ws://${IP}:${SOCKET_PORT}`; // example for CV200: 192.168.43.1:13456
  let ws: WebSocket;
  const isManualDisconnect = React.useRef(false);


  useEffect(() => {
    isManualDisconnect.current = false;
    connectWS();

    return () => {
      isManualDisconnect.current = true;
      disconnectWS();
    };
  }, []);

  const connectWS = () => {
    ws = new WebSocket(serverUrl);

    ws.onopen = () => {
      // console.log('Socket Connected');
    };

    ws.onmessage = e => {
      if (e.data instanceof ArrayBuffer) {
        // console.log('Received', e.data.byteLength);
        Decoder(new Uint8Array(e.data));
        ws.send('OK');
      }
    };

    ws.onerror = e => {
      console.log(`Error: ${e.message}`);
    };

    ws.onclose = () => {
      if (!isManualDisconnect.current) {
        setTimeout(() => {
          connectWS();
        }, 200);
      }
    };
  };

  const disconnectWS = () => {
    ws.close();
  };

  // Send the frame to the decoder
  const Decoder = (fs: Uint8Array) => {
    const vfs = Array.from(fs);
    try {
      decodeFrame.decodeFrame(vfs, 640, 368);
    } catch (error) {
      console.log('Error decoding frame:', error);
    }
  };


  const OverlayScreen = useCallback(() => {
    return (
      <View style={styles.overlay}>
        <Image
          source={require('assets/silhh-red.png')}
          style={{
            width: width - 30,
            height: 200,
          }}
        />
      </View>
    );
  }, [width]);

  const VideoComponent = useCallback(() => {
    return <CV200VideoSurface style={{width: width - 30, height: 200}} />;
  }, [width]);

  return (
    <View style={styles.container}>
      <VideoComponent />
      <OverlayScreen />
    </View>
  );
};

export default VideoCodec;

const styles = StyleSheet.create({
  container: {
    height: 200,
    width: '100%',
  },
  image: {
    width: '100%',
    height: '100%',
    borderWidth: 1,
    borderColor: 'blue',
  },
  overlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: '100%',
    height: '100%',
    zIndex: 1,
  },
});
