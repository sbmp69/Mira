import { Router } from 'express';
import { prisma } from '../db';
import { OpenAIProvider } from '../ai/openai';
import { AIEngine } from '../ai/engine';
import { MemoryService } from '../ai/memory';
import { AIProvider } from '../ai/provider';
import jwt from 'jsonwebtoken';

const router = Router();
const JWT_SECRET = process.env.JWT_SECRET || 'supersecretfallbackkey';
const aiProvider = new OpenAIProvider();
const engine = new AIEngine(aiProvider);
const memoryService = new MemoryService(aiProvider);

router.post('/send', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }
    const token = authHeader.split(' ')[1];
    
    let decodedToken;
    try {
      decodedToken = jwt.verify(token, JWT_SECRET) as { userId: string };
    } catch (err) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    const userId = decodedToken.userId;

    let { companionId, message, image, audio } = req.body;

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
        image: image || null
      }
    });

    // 4. Extract and save memory in background (don't await so we respond faster)
    memoryService.extractAndSaveMemory(userId, message).catch(console.error);

    // 5. Retrieve relevant memories for context
    const relevantMemories = await memoryService.retrieveRelevantMemories(userId, message);

    // 6. Format recent history for the Engine
    const recentHistory = conversation.messages.reverse().map(m => ({
      sender: m.sender,
      content: m.content,
      imageBase64: m.image || undefined
    }));
    recentHistory.push({ sender: 'USER', content: message, imageBase64: image || undefined });

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

export default router;
