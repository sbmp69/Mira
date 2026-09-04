import React, { useState, useEffect } from 'react';
import { StyleSheet, View, Text, TouchableOpacity, SafeAreaView, ActivityIndicator } from 'react-native';
import { Colors } from '../../constants/Colors';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Audio } from 'expo-av';
import { chatApi } from '../../services/api';

const TEST_USER_ID = '925bfa8e-db2c-4e42-a346-738c6e32ee97';
const TEST_COMPANION_ID = '815ca4b0-1ffe-441f-b519-66ef79040b30';

export default function CallScreen() {
  const { id } = useLocalSearchParams();
  const router = useRouter();

  const [status, setStatus] = useState<'IDLE' | 'LISTENING' | 'THINKING' | 'SPEAKING'>('IDLE');
  const [recording, setRecording] = useState<Audio.Recording | null>(null);
  const [sound, setSound] = useState<Audio.Sound | null>(null);

  useEffect(() => {
    return () => {
      if (recording) recording.stopAndUnloadAsync();
      if (sound) sound.unloadAsync();
    };
  }, []);

  const handleOrbPress = async () => {
    if (status === 'IDLE') {
      await startListening();
    } else if (status === 'LISTENING') {
      await stopListeningAndSend();
    } else if (status === 'SPEAKING') {
      await stopSpeaking();
    }
  };

  const startListening = async () => {
    try {
      if (sound) await sound.unloadAsync();
      
      await Audio.requestPermissionsAsync();
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });
      const { recording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );
      setRecording(recording);
      setStatus('LISTENING');
    } catch (err) {
      console.error('Failed to start recording', err);
      setStatus('IDLE');
    }
  };

  const stopListeningAndSend = async () => {
    if (!recording) return;
    setStatus('THINKING');
    
    try {
      await recording.stopAndUnloadAsync();
      const uri = recording.getURI();
      setRecording(null);

      if (uri) {
        const FileSystem = await import('expo-file-system');
        const base64 = await FileSystem.readAsStringAsync(uri, { encoding: FileSystem.EncodingType.Base64 });
        const audioToSend = `data:audio/m4a;base64,${base64}`;
        
        // Send to backend
        const response = await chatApi.sendMessage(TEST_USER_ID, TEST_COMPANION_ID, '', undefined, audioToSend);
        
        if (response.audioData) {
          setStatus('SPEAKING');
          const { sound: newSound } = await Audio.Sound.createAsync(
            { uri: response.audioData }
          );
          setSound(newSound);
          
          newSound.setOnPlaybackStatusUpdate((playbackStatus) => {
            if (playbackStatus.isLoaded && playbackStatus.didJustFinish) {
              setStatus('IDLE');
            }
          });
          
          await newSound.playAsync();
        } else {
          setStatus('IDLE');
        }
      }
    } catch (error) {
      console.error('Failed to process audio:', error);
      setStatus('IDLE');
    }
  };

  const stopSpeaking = async () => {
    if (sound) {
      await sound.stopAsync();
      setStatus('IDLE');
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <Ionicons name="chevron-down" size={32} color={Colors.text} />
        </TouchableOpacity>
      </View>

      <View style={styles.centerContainer}>
        <Text style={styles.statusText}>
          {status === 'IDLE' && 'Tap to speak'}
          {status === 'LISTENING' && 'Listening...'}
          {status === 'THINKING' && 'Thinking...'}
          {status === 'SPEAKING' && 'Mira is speaking'}
        </Text>

        <TouchableOpacity 
          style={[
            styles.orb, 
            status === 'LISTENING' && styles.orbListening,
            status === 'THINKING' && styles.orbThinking,
            status === 'SPEAKING' && styles.orbSpeaking
          ]}
          onPress={handleOrbPress}
          activeOpacity={0.8}
        >
          {status === 'THINKING' ? (
            <ActivityIndicator size="large" color={Colors.background} />
          ) : (
            <Ionicons 
              name={status === 'LISTENING' ? "square" : status === 'SPEAKING' ? "volume-high" : "mic"} 
              size={48} 
              color={status === 'IDLE' ? Colors.text : Colors.background} 
            />
          )}
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#050505', // Deep black for call mode
  },
  header: {
    padding: 20,
    alignItems: 'flex-start',
  },
  backButton: {
    padding: 8,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  statusText: {
    color: Colors.textMuted,
    fontSize: 18,
    marginBottom: 60,
    fontWeight: '300',
    letterSpacing: 2,
  },
  orb: {
    width: 160,
    height: 160,
    borderRadius: 80,
    backgroundColor: Colors.surface,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: Colors.surfaceLight,
    shadowColor: Colors.primary,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.2,
    shadowRadius: 20,
    elevation: 10,
  },
  orbListening: {
    backgroundColor: '#ff4444',
    borderColor: '#ff4444',
    transform: [{ scale: 1.1 }],
    shadowColor: '#ff4444',
    shadowOpacity: 0.5,
    shadowRadius: 30,
  },
  orbThinking: {
    backgroundColor: Colors.primary,
    borderColor: Colors.primary,
    opacity: 0.8,
  },
  orbSpeaking: {
    backgroundColor: Colors.primary,
    borderColor: Colors.primary,
    shadowColor: Colors.primary,
    shadowOpacity: 0.6,
    shadowRadius: 40,
    transform: [{ scale: 1.05 }],
  }
});
