import React from 'react';
import {View, StyleSheet} from 'react-native';
import VideoCodec from './VideoCodec';

interface Props {
}

const Component: React.FC<Props> = () => {
  return (
    <View style={styles.container}>
      <VideoCodec IP="192.168.43.1" SOCKET_PORT={13456} />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});

export default Component;
