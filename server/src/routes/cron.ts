import express from 'express';
import { prisma } from '../db';
import { OpenAIProvider } from '../ai/openai';
import { AIEngine } from '../ai/engine';
import { MemoryService } from '../ai/memory';

const router = express.Router();

const aiProvider = new OpenAIProvider();
const engine = new AIEngine(aiProvider);
const memoryService = new MemoryService(aiProvider);

// GET /api/cron/daily-checkin
// This should be secured via a cron secret in production
router.get('/daily-checkin', async (req, res) => {
  try {
    // 1. Find users who haven't messaged in 24 hours but have an expoPushToken
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    // We get conversations where the user's last message is older than 24h
    const conversations = await prisma.conversation.findMany({
      where: {
        user: {
          expoPushToken: { not: null }
        },
        updatedAt: { lte: yesterday }
      },
      include: {
        user: true,
        companion: true,
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 5
        }
      }
    });

    const messagesToSend = [];

    for (const conv of conversations) {
      if (!conv.user.expoPushToken) continue;
      
      const relevantMemories = await memoryService.retrieveRelevantMemories(conv.user.id, "I haven't talked to you in a while. How are you doing?");
      
      const recentHistory = conv.messages.reverse().map(m => ({
        sender: m.sender,
        content: m.content
      }));

      // Instruct the AI to write a short push notification
      const checkInPrompt = `Write a short, engaging 1-2 sentence push notification to check in on ${conv.user.name}. It should feel natural and entice them to open the app. Use a relevant emoji. Do NOT use quotes.`;
      
      const pushMessage = await engine.generateCompanionResponse({
        userName: conv.user.name || 'User',
        companionName: conv.companion.name,
        personality: conv.companion.personality,
        speakingStyle: conv.companion.speakingStyle,
        relationshipStage: conv.relationshipStage,
        languagePref: conv.user.languagePref || 'Auto',
        relevantMemories,
        recentHistory: [...recentHistory, { sender: 'USER', content: checkInPrompt }],
        timeOfDay: new Date().toLocaleTimeString(),
      });

      // Save this as a proactive message in the DB
      await prisma.message.create({
        data: {
          conversationId: conv.id,
          sender: 'AI',
          content: pushMessage
        }
      });
      
      // Update conversation updatedAt so we don't spam them
      await prisma.conversation.update({
        where: { id: conv.id },
        data: { updatedAt: new Date() }
      });

      if (conv.user.expoPushToken.startsWith('ExponentPushToken')) {
        messagesToSend.push({
          to: conv.user.expoPushToken,
          sound: 'default',
          title: conv.companion.name,
          body: pushMessage,
          data: { conversationId: conv.id },
        });
      }
    }

    // Send notifications via Expo HTTP API
    if (messagesToSend.length > 0) {
      await fetch('https://exp.host/--/api/v2/push/send', {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Accept-encoding': 'gzip, deflate',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(messagesToSend),
      });
    }

    res.json({ success: true, notified: messagesToSend.length });
  } catch (error) {
    console.error('Cron error:', error);
    res.status(500).json({ error: 'Failed to run cron job' });
  }
});

export default router;
