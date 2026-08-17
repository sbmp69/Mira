import { Stack, useRouter, useSegments } from 'expo-router';
import { useEffect, useState } from 'react';
import { Colors } from '../constants/Colors';
import { authApi } from '../services/api';

export default function RootLayout() {
  const router = useRouter();
  const segments = useSegments();
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const token = await authApi.getToken();
        const inAuthGroup = segments[0] === 'login' || segments[0] === 'signup';

        if (!token && !inAuthGroup) {
          router.replace('/login');
        } else if (token && inAuthGroup) {
          router.replace('/');
        }
      } catch (err) {
        console.error('Auth check failed', err);
      } finally {
        setIsReady(true);
      }
    };
    
    checkAuth();
  }, [segments]);

  if (!isReady) return null;

  return (
    <Stack screenOptions={{ 
      headerShown: false,
      contentStyle: { backgroundColor: Colors.background }
    }}>
      <Stack.Screen name="index" />
      <Stack.Screen name="login" options={{ animation: 'fade' }} />
      <Stack.Screen name="signup" options={{ animation: 'fade' }} />
      <Stack.Screen name="chat/[id]" />
      <Stack.Screen name="call/[id]" />
    </Stack>
  );
}
