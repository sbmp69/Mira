// Base URL for the local backend
// Android emulator uses 10.0.2.2 to access localhost, iOS uses localhost
import { Platform } from 'react-native';

const BASE_URL = 'https://mira-ruby-six.vercel.app/api';

export const chatApi = {
  async getCompanions() {
    try {
      const response = await fetch(`${BASE_URL}/companions`);
      const data = await response.json();
      return data.companions;
    } catch (error) {
      console.error('Error fetching companions:', error);
      throw error;
    }
  },

  async sendMessage(userId: string, companionId: string, message: string, imageBase64?: string, audioBase64?: string) {
    try {
      const response = await fetch(`${BASE_URL}/chat/send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          userId,
          companionId,
          message,
          image: imageBase64,
          audio: audioBase64,
        }),
      });
      
      if (!response.ok) {
        throw new Error('Network response was not ok');
      }
      
      return await response.json();
    } catch (error) {
      console.error('Error sending message:', error);
      throw error;
    }
  }
};
