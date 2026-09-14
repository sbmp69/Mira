import { Router } from 'express';
import { prisma } from '../db';
import { OpenAIProvider } from '../ai/openai';
import { AIEngine } from '../ai/engine';
import { MemoryService } from '../ai/memory';
import { requireAuth } from '../middleware/auth';

const router = Router();
const aiProvider = new OpenAIProvider();
const engine = new AIEngine(aiProvider);
const memoryService = new MemoryService(aiProvider);

router.post('/send', requireAuth, async (req, res) => {
  try {
    const userId = (req as any).userId;
    let { companionId, message, image, audio, replyToId } = req.body;

    // If audio is provided, transcribe it first
    if (audio) {
      try {
        message = await aiProvider.transcribeAudio({ audioBase64: audio });
        console.log(`Transcribed audio to: "${message}"`);
      } catch (err) {
        console.error('Transcription failed', err);
        return res.status(400).json({ error: 'Failed to transcribe audio' });
      }
    }

    // 1. Fetch User and Companion
    const user = await prisma.user.findUnique({ where: { id: userId } });
    const companion = await prisma.companion.findUnique({ where: { id: companionId } });

    if (!user || !companion) {
      return res.status(404).json({ error: 'User or Companion not found' });
    }

    // 1.5 Fetch replied message if exists
    let repliedMessageContent = null;
    if (replyToId) {
      const repliedMsg = await prisma.message.findUnique({ where: { id: replyToId } });
      if (repliedMsg) {
        repliedMessageContent = repliedMsg.content;
      }
    }

    // 2. Find or create conversation
    let conversation = await prisma.conversation.findFirst({
      where: { userId, companionId },
      include: {
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 10, // Get last 10 messages for context
        }
      }
    });

    if (!conversation) {
      conversation = await prisma.conversation.create({
        data: { userId, companionId, relationshipStage: 1 },
        include: { messages: true }
      });
    }

    // 3. Save User Message
    await prisma.message.create({
      data: {
        conversationId: conversation.id,
        sender: 'USER',
        content: message,
        image: image || null,
        replyToId: replyToId || null
      }
    });

    // 4. Extract and save memory in background (don't await so we respond faster)
    memoryService.extractAndSaveMemory(userId, conversation.id, message).catch(console.error);

    // 5. Retrieve relevant memories for context
    const relevantMemories = await memoryService.retrieveRelevantMemories(userId, message);

    // 6. Format recent history for the Engine
    const recentHistory = conversation.messages.reverse().map(m => ({
      sender: m.sender,
      content: m.content,
      imageBase64: m.image || undefined
    }));
    
    let contextualMessage = message;
    if (repliedMessageContent) {
       contextualMessage = `[User is replying to this specific past message: "${repliedMessageContent}"]\n\nUser says: ${message}`;
    }
    
    recentHistory.push({ sender: 'USER', content: contextualMessage, imageBase64: image || undefined });

    // 7. Generate AI Response
    const responseContent = await engine.generateCompanionResponse({
      userName: user.name || 'User',
      companionName: companion.name,
      personality: companion.personality,
      speakingStyle: companion.speakingStyle,
      relationshipStage: conversation.relationshipStage,
      languagePref: user.languagePref || 'Auto',
      relevantMemories,
      recentHistory,
      timeOfDay: new Date().toLocaleTimeString(),
    });

    // 8. Save AI Message
    const aiMessage = await prisma.message.create({
      data: {
        conversationId: conversation.id,
        sender: 'AI',
        content: responseContent
      }
    });

    // 9. If the user sent audio, send audio back (TTS)
    let audioData = null;
    if (audio) {
      try {
        audioData = await aiProvider.generateSpeech({ input: responseContent });
      } catch (err) {
        console.error('TTS failed', err);
      }
    }

    res.json({ message: aiMessage, audioData });

  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ error: 'Failed to generate response' });
  }
});

// GET /api/chat/:companionId/history
router.get('/:companionId/history', requireAuth, async (req, res) => {
  try {
    const userId = (req as any).userId;
    const { companionId } = req.params;

    const conversation = await prisma.conversation.findFirst({
      where: { userId, companionId },
      include: {
        messages: {
          orderBy: { createdAt: 'asc' }, // Oldest first for chat UI
        }
      }
    });

    if (!conversation) {
      return res.json({ messages: [] });
    }

    res.json({ messages: conversation.messages });
  } catch (error) {
    console.error('Chat history error:', error);
    res.status(500).json({ error: 'Failed to fetch history' });
  }
});

export default router;
