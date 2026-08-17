import React, { useState, useRef } from 'react';
import { StyleSheet, View, Text, TextInput, TouchableOpacity, ScrollView, KeyboardAvoidingView, Platform, ActivityIndicator, Image } from 'react-native';
import { Audio } from 'expo-av';
import { Colors } from '../../constants/Colors';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { chatApi } from '../../services/api';

interface Message {
  id: string;
  text: string;
  isUser: boolean;
  timestamp: string;
  imageUri?: string;
  isAudio?: boolean;
}

// Hardcoded IDs from the seed for testing
const TEST_USER_ID = '925bfa8e-db2c-4e42-a346-738c6e32ee97';
const TEST_COMPANION_ID = '815ca4b0-1ffe-441f-b519-66ef79040b30';

export default function ChatScreen() {
  const { id } = useLocalSearchParams();
  const router = useRouter();
  
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '1',
      text: 'I missed you today. How was everything?',
      isUser: false,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    }
  ]);
  const [inputText, setInputText] = useState('');
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [selectedImageBase64, setSelectedImageBase64] = useState<string | null>(null);
  const [isTyping, setIsTyping] = useState(false);
  const [recording, setRecording] = useState<Audio.Recording | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const scrollViewRef = useRef<ScrollView>(null);

  const pickImage = async () => {
    // Dynamically import to avoid errors if not fully installed yet
    const ImagePicker = await import('expo-image-picker');
    let result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      quality: 0.8,
      base64: true,
    });

    if (!result.canceled && result.assets && result.assets.length > 0) {
      // In a real app we'd save the base64 string or upload it.
      // For UI purposes, we'll keep the URI to display it.
      setSelectedImage(result.assets[0].uri);
      if (result.assets[0].base64) {
        setSelectedImageBase64(`data:image/jpeg;base64,${result.assets[0].base64}`);
      }
    }
  };

  const handleSend = async () => {
    if (!inputText.trim() && !selectedImage) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      text: inputText.trim(),
      isUser: true,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      imageUri: selectedImage || undefined,
    };

    setMessages(prev => [...prev, userMessage]);
    setInputText('');
    const imageToSend = selectedImageBase64;
    setSelectedImage(null);
    setSelectedImageBase64(null);
    setIsTyping(true);

    try {
      // Send to Backend (we will update the API service to handle imageToSend later)
        const response = await chatApi.sendMessage(TEST_USER_ID, TEST_COMPANION_ID, userMessage.text, imageToSend || undefined);
      
        const aiMessage: Message = {
          id: response.message.id || (Date.now() + 1).toString(),
          text: response.message.content,
          isUser: false,
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        };
        
        setMessages(prev => [...prev, aiMessage]);

        // Play audio if received
        if (response.audioData) {
          const { sound } = await Audio.Sound.createAsync(
            { uri: response.audioData }
          );
          await sound.playAsync();
        }
      } catch (error) {
      console.error('Failed to get response:', error);
      // Fallback message
      const errorMsg: Message = {
        id: (Date.now() + 1).toString(),
        text: 'Sorry... I am having trouble connecting right now 🥺',
        isUser: false,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };
      setMessages(prev => [...prev, errorMsg]);
    } finally {
      setIsTyping(false);
    }
  };

  const startRecording = async () => {
    try {
      await Audio.requestPermissionsAsync();
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });
      const { recording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );
      setRecording(recording);
      setIsRecording(true);
    } catch (err) {
      console.error('Failed to start recording', err);
    }
  };

  const stopRecording = async () => {
    if (!recording) return;
    setRecording(null);
    setIsRecording(false);
    
    try {
      await recording.stopAndUnloadAsync();
      const uri = recording.getURI();
      if (uri) {
        // Send a temporary "Voice Message" UI bubble
        const userMessage: Message = {
          id: Date.now().toString(),
          text: '🎤 Voice Message',
          isUser: true,
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          isAudio: true
        };
        setMessages(prev => [...prev, userMessage]);
        setIsTyping(true);

        const FileSystem = await import('expo-file-system');
        const base64 = await FileSystem.readAsStringAsync(uri, { encoding: FileSystem.EncodingType.Base64 });
        const audioToSend = `data:audio/m4a;base64,${base64}`;
        
        // Send to backend (requires API update)
        const response = await chatApi.sendMessage(TEST_USER_ID, TEST_COMPANION_ID, '', undefined, audioToSend);
        
        const aiMessage: Message = {
          id: response.message.id || (Date.now() + 1).toString(),
          text: response.message.content,
          isUser: false,
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        };
        setMessages(prev => [...prev, aiMessage]);

        // Play audio if received
        if (response.audioData) {
          const { sound } = await Audio.Sound.createAsync(
            { uri: response.audioData }
          );
          await sound.playAsync();
        }
      }
    } catch (error) {
      console.error('Failed to process audio:', error);
      setIsTyping(false);
    }
  };

  return (
    <KeyboardAvoidingView 
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <Ionicons name="arrow-back-outline" size={24} color={Colors.primary} />
        </TouchableOpacity>
        <View style={styles.headerTitleContainer}>
          <Text style={styles.headerTitle}>M I R A</Text>
          <Text style={styles.headerSubtitle}>Online</Text>
        </View>
        <View style={styles.headerRight}>
          <TouchableOpacity style={styles.callButton} onPress={() => router.push(`/call/${id}`)}>
            <Ionicons name="call" size={22} color={Colors.primary} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.menuButton}>
            <Ionicons name="ellipsis-vertical" size={24} color={Colors.textMuted} />
          </TouchableOpacity>
        </View>
      </View>

      {/* Chat Area */}
      <ScrollView 
        ref={scrollViewRef}
        style={styles.chatArea} 
        contentContainerStyle={styles.chatContent}
        onContentSizeChange={() => scrollViewRef.current?.scrollToEnd({ animated: true })}
      >
        {messages.map((msg) => (
          <View key={msg.id} style={[styles.messageRow, msg.isUser && styles.userMessageRow]}>
            <View style={msg.isUser ? styles.userMessageBubble : styles.aiMessageBubble}>
              {msg.imageUri && (
                <View style={styles.messageImageContainer}>
                  {/* Dynamic import of Image component to avoid missing import errors */}
                  <Image source={{ uri: msg.imageUri }} style={styles.messageImage} />
                </View>
              )}
              {msg.text ? (
                <Text style={[
                  msg.isUser ? styles.userMessageText : styles.aiMessageText,
                  msg.isAudio && { fontStyle: 'italic' }
                ]}>
                  {msg.text}
                </Text>
              ) : null}
              <Text style={[styles.timestamp, msg.isUser && styles.userTimestamp]}>
                {msg.timestamp}
              </Text>
            </View>
          </View>
        ))}

        {isTyping && (
          <View style={styles.messageRow}>
            <View style={styles.aiMessageBubble}>
              <ActivityIndicator size="small" color={Colors.primary} />
            </View>
          </View>
        )}
      </ScrollView>

      {/* Input Area */}
      <View style={styles.inputAreaWrapper}>
        {selectedImage && (
          <View style={styles.selectedImagePreviewContainer}>
            <Image source={{ uri: selectedImage }} style={styles.selectedImagePreview} />
            <TouchableOpacity style={styles.removeImageButton} onPress={() => { setSelectedImage(null); setSelectedImageBase64(null); }}>
              <Ionicons name="close-circle" size={24} color={Colors.primary} />
            </TouchableOpacity>
          </View>
        )}
        <View style={styles.inputArea}>
          <TouchableOpacity style={styles.attachButton} onPress={pickImage}>
            <Ionicons name="add-outline" size={28} color={Colors.primary} />
          </TouchableOpacity>
        
        <View style={styles.inputContainer}>
          <TextInput 
            style={styles.textInput}
            placeholder="Type a message..."
            placeholderTextColor={Colors.textMuted}
            multiline
            value={inputText}
            onChangeText={setInputText}
          />
        </View>

        {!inputText.trim() && !selectedImage ? (
          <TouchableOpacity 
            style={[styles.sendButton, isRecording && styles.recordingButton]} 
            onPressIn={startRecording}
            onPressOut={stopRecording}
          >
            <Ionicons name={isRecording ? "mic" : "mic-outline"} size={18} color={Colors.background} />
          </TouchableOpacity>
        ) : (
          <TouchableOpacity 
            style={styles.sendButton} 
            onPress={handleSend}
          >
            <Ionicons name="send" size={18} color={Colors.background} />
          </TouchableOpacity>
        )}
      </View>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingTop: 60,
    paddingBottom: 20,
    borderBottomWidth: 1,
    borderBottomColor: Colors.surfaceLight,
    backgroundColor: Colors.background,
  },
  backButton: {
    padding: 8,
    marginLeft: -8,
  },
  headerTitleContainer: {
    alignItems: 'center',
  },
  headerTitle: {
    color: Colors.text,
    fontSize: 14,
    fontWeight: '400',
    letterSpacing: 4,
  },
  headerSubtitle: {
    color: Colors.primary,
    fontSize: 10,
    marginTop: 4,
    fontWeight: '300',
    letterSpacing: 1,
  },
  headerRight: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: -8,
  },
  callButton: {
    padding: 8,
    marginRight: 8,
  },
  menuButton: {
    padding: 8,
    marginRight: -8,
  },
  chatArea: {
    flex: 1,
  },
  chatContent: {
    padding: 20,
    paddingBottom: 40,
    gap: 24,
  },
  messageRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    width: '100%',
  },
  userMessageRow: {
    justifyContent: 'flex-end',
  },
  aiMessageBubble: {
    backgroundColor: Colors.surface,
    padding: 16,
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    borderBottomRightRadius: 16,
    borderBottomLeftRadius: 4,
    maxWidth: '80%',
    borderWidth: 1,
    borderColor: Colors.glassBorder,
  },
  userMessageBubble: {
    backgroundColor: Colors.primary,
    padding: 16,
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    borderBottomLeftRadius: 16,
    borderBottomRightRadius: 4,
    maxWidth: '80%',
  },
  aiMessageText: {
    color: Colors.text,
    fontSize: 15,
    lineHeight: 22,
    fontWeight: '300',
  },
  userMessageText: {
    color: Colors.background,
    fontSize: 15,
    lineHeight: 22,
    fontWeight: '500',
  },
  timestamp: {
    color: Colors.textMuted,
    fontSize: 10,
    marginTop: 8,
    alignSelf: 'flex-start',
    letterSpacing: 1,
  },
  userTimestamp: {
    color: 'rgba(5,5,5,0.6)',
    alignSelf: 'flex-end',
  },
  inputArea: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    paddingBottom: Platform.OS === 'ios' ? 32 : 16,
    borderTopWidth: 1,
    borderTopColor: Colors.surfaceLight,
    backgroundColor: Colors.surface,
  },
  attachButton: {
    marginRight: 12,
  },
  inputContainer: {
    flex: 1,
    backgroundColor: Colors.background,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Colors.surfaceLight,
    paddingHorizontal: 16,
    paddingVertical: 12,
    marginRight: 12,
  },
  textInput: {
    color: Colors.text,
    fontSize: 15,
    maxHeight: 100,
    fontWeight: '300',
  },
  sendButton: {
    backgroundColor: Colors.primary,
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  recordingButton: {
    backgroundColor: '#ff4444',
    transform: [{ scale: 1.1 }],
  },
  inputAreaWrapper: {
    backgroundColor: Colors.surface,
  },
  selectedImagePreviewContainer: {
    paddingHorizontal: 20,
    paddingTop: 16,
    flexDirection: 'row',
  },
  selectedImagePreview: {
    width: 60,
    height: 60,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Colors.glassBorder,
  },
  removeImageButton: {
    position: 'absolute',
    top: 8,
    left: 70,
    backgroundColor: Colors.background,
    borderRadius: 12,
  },
  messageImageContainer: {
    marginBottom: 8,
  },
  messageImage: {
    width: 200,
    height: 200,
    borderRadius: 8,
  }
});
