import { Router } from 'express';
import { prisma } from '../db';
import { OpenAIProvider } from '../ai/openai';
import { AIEngine } from '../ai/engine';
import { MemoryService } from '../ai/memory';

const router = Router();
const aiProvider = new OpenAIProvider();
const engine = new AIEngine(aiProvider);
const memoryService = new MemoryService(aiProvider);

router.post('/send', async (req, res) => {
  try {
    const { userId, companionId, message } = req.body;

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
        content: message
      }
    });

    // 4. Extract and save memory in background (don't await so we respond faster)
    memoryService.extractAndSaveMemory(userId, message).catch(console.error);

    // 5. Retrieve relevant memories for context
    const relevantMemories = await memoryService.retrieveRelevantMemories(userId, message);

    // 6. Format recent history for the Engine
    const recentHistory = conversation.messages.reverse().map(m => ({
      sender: m.sender,
      content: m.content
    }));
    recentHistory.push({ sender: 'USER', content: message });

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

    res.json({ message: aiMessage });

  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ error: 'Failed to generate response' });
  }
});

export default router;
