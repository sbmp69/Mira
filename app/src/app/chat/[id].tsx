import React, { useState, useRef } from 'react';
import { StyleSheet, View, Text, TextInput, TouchableOpacity, ScrollView, KeyboardAvoidingView, Platform, ActivityIndicator } from 'react-native';
import { Colors } from '../../constants/Colors';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { chatApi } from '../../services/api';

interface Message {
  id: string;
  text: string;
  isUser: boolean;
  timestamp: string;
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
  const [isTyping, setIsTyping] = useState(false);
  const scrollViewRef = useRef<ScrollView>(null);

  const handleSend = async () => {
    if (!inputText.trim()) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      text: inputText.trim(),
      isUser: true,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    setMessages(prev => [...prev, userMessage]);
    setInputText('');
    setIsTyping(true);

    try {
      // Send to Backend
      const response = await chatApi.sendMessage(TEST_USER_ID, TEST_COMPANION_ID, userMessage.text);
      
      const aiMessage: Message = {
        id: response.message.id || (Date.now() + 1).toString(),
        text: response.message.content,
        isUser: false,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };
      
      setMessages(prev => [...prev, aiMessage]);
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
        <TouchableOpacity style={styles.menuButton}>
          <Ionicons name="ellipsis-vertical" size={24} color={Colors.textMuted} />
        </TouchableOpacity>
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
              <Text style={msg.isUser ? styles.userMessageText : styles.aiMessageText}>
                {msg.text}
              </Text>
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
      <View style={styles.inputArea}>
        <TouchableOpacity style={styles.attachButton}>
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

        <TouchableOpacity 
          style={[styles.sendButton, !inputText.trim() && { opacity: 0.5 }]} 
          onPress={handleSend}
          disabled={!inputText.trim()}
        >
          <Ionicons name="send" size={18} color={Colors.background} />
        </TouchableOpacity>
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
  }
});
