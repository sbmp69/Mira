// Base URL for the local backend
// Android emulator uses 10.0.2.2 to access localhost, iOS uses localhost
import AsyncStorage from '@react-native-async-storage/async-storage';

const BASE_URL = 'https://mira-ruby-six.vercel.app/api';

export const authApi = {
  async setToken(token: string) {
    await AsyncStorage.setItem('userToken', token);
  },
  async getToken() {
    return await AsyncStorage.getItem('userToken');
  },
  async logout() {
    await AsyncStorage.removeItem('userToken');
  },
  async login(email: string, password: string) {
    const res = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error);
    await this.setToken(data.token);
    return data.user;
  },
  async register(name: string, email: string, password: string) {
    const res = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, email, password })
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error);
    await this.setToken(data.token);
    return data.user;
  },
  async updatePushToken(pushToken: string) {
    const token = await this.getToken();
    if (!token) return;
    await fetch(`${BASE_URL}/auth/push-token`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ pushToken })
    });
  }
};

export const chatApi = {
  async getCompanions() {
    const token = await authApi.getToken();
    try {
      const response = await fetch(`${BASE_URL}/companions`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();
      return data.companions;
    } catch (error) {
      console.error('Error fetching companions:', error);
      throw error;
    }
  },

  async sendMessage(userId: string, companionId: string, message: string, imageBase64?: string, audioBase64?: string) {
    const token = await authApi.getToken();
    try {
      const response = await fetch(`${BASE_URL}/chat/send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
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
