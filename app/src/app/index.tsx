import React, { useEffect, useState } from 'react';
import { StyleSheet, View, Text, Image, TouchableOpacity, ScrollView, ActivityIndicator } from 'react-native';
import { Colors } from '../constants/Colors';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { chatApi } from '../services/api';

interface Companion {
  id: string;
  name: string;
  avatar: string;
  description: string;
}

export default function HomeScreen() {
  const router = useRouter();
  const [companions, setCompanions] = useState<Companion[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchCompanions = async () => {
      try {
        const data = await chatApi.getCompanions();
        setCompanions(data);
      } catch (error) {
        console.error('Failed to load companions');
      } finally {
        setLoading(false);
      }
    };
    fetchCompanions();
  }, []);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.greeting}>GOOD EVENING,</Text>
          <Text style={styles.userName}>Meet</Text>
        </View>
        <TouchableOpacity style={styles.profileBtn}>
          <Ionicons name="person-circle-outline" size={36} color={Colors.primary} />
        </TouchableOpacity>
      </View>

      {/* Companion List */}
      {loading ? (
        <ActivityIndicator size="large" color={Colors.primary} style={{ marginVertical: 50 }} />
      ) : (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.companionList} contentContainerStyle={styles.companionListContent}>
          {companions.map((companion) => (
            <View key={companion.id} style={styles.companionCard}>
              <Image 
                source={{ uri: companion.avatar }} 
                style={styles.companionImage}
              />
              <View style={styles.cardOverlay}>
                <View style={styles.cardHeader}>
                  <Text style={styles.companionName}>{companion.name.toUpperCase().split('').join(' ')}</Text>
                  <View style={styles.onlineBadge} />
                </View>
                <Text style={styles.companionMessage}>{companion.description}</Text>
                
                <TouchableOpacity 
                  style={[styles.chatButton, { zIndex: 10, elevation: 10 }]}
                  onPress={() => {
                    router.push({ pathname: '/chat/[id]', params: { id: companion.id } });
                  }}
                >
                  <Text style={styles.chatButtonText}>Enter Chat</Text>
                  <Ionicons name="chevron-forward" size={16} color={Colors.background} />
                </TouchableOpacity>
              </View>
            </View>
          ))}
        </ScrollView>
      )}

      {/* Stats row */}
      <View style={styles.statsRow}>
        <View style={styles.statBox}>
          <Ionicons name="heart-outline" size={24} color={Colors.secondary} style={styles.statIcon} />
          <Text style={styles.statValue}>1,284</Text>
          <Text style={styles.statLabel}>interactions</Text>
        </View>
        <View style={styles.statBox}>
          <Ionicons name="git-network-outline" size={24} color={Colors.primary} style={styles.statIcon} />
          <Text style={styles.statValue}>124</Text>
          <Text style={styles.statLabel}>memories</Text>
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  content: {
    padding: 24,
    paddingTop: 60,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 40,
  },
  greeting: {
    color: Colors.textMuted,
    fontSize: 10,
    fontWeight: '400',
    letterSpacing: 3,
    marginBottom: 4,
  },
  userName: {
    color: Colors.text,
    fontSize: 24,
    fontWeight: '300',
    letterSpacing: 1,
  },
  profileBtn: {
    padding: 4,
  },
  companionList: {
    marginBottom: 30,
    marginHorizontal: -24, // Break out of padding
  },
  companionListContent: {
    paddingHorizontal: 24,
    gap: 16,
  },
  companionCard: {
    width: 300,
    height: 480,
    borderRadius: 16,
    overflow: 'hidden',
    backgroundColor: Colors.surface,
    position: 'relative',
    borderWidth: 1,
    borderColor: Colors.glassBorder,
  },
  companionImage: {
    width: '100%',
    height: '100%',
    position: 'absolute',
    opacity: 0.85, // Slightly faded into the black
  },
  cardOverlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: 32,
    backgroundColor: 'rgba(5, 5, 5, 0.75)',
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  companionName: {
    color: Colors.primary,
    fontSize: 20,
    fontWeight: '400',
    letterSpacing: 4,
    marginRight: 12,
  },
  onlineBadge: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: Colors.primary,
    shadowColor: Colors.primary,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 1,
    shadowRadius: 8,
  },
  companionMessage: {
    color: Colors.text,
    fontSize: 15,
    fontStyle: 'italic',
    fontWeight: '300',
    marginBottom: 30,
    opacity: 0.9,
  },
  chatButton: {
    backgroundColor: Colors.primary,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    borderRadius: 4, // Sharp corners
    gap: 8,
  },
  chatButtonText: {
    color: Colors.background,
    fontSize: 13,
    fontWeight: '600',
    letterSpacing: 2,
    textTransform: 'uppercase',
  },
  statsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 16,
  },
  statBox: {
    flex: 1,
    backgroundColor: Colors.surface,
    padding: 24,
    alignItems: 'flex-start',
    borderWidth: 1,
    borderColor: Colors.glassBorder,
  },
  statIcon: {
    marginBottom: 16,
  },
  statValue: {
    color: Colors.text,
    fontSize: 22,
    fontWeight: '300',
    letterSpacing: 1,
  },
  statLabel: {
    color: Colors.textMuted,
    fontSize: 10,
    marginTop: 6,
    letterSpacing: 2,
    textTransform: 'uppercase',
  },
});
