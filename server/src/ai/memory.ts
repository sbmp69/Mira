import { prisma } from '../db';
import { AIProvider } from './provider';

export class MemoryService {
  constructor(private aiProvider: AIProvider) {}

  /**
   * Evaluates the latest user message to see if a memory should be extracted and saved.
   * Also analyzes sentiment to progress the relationship stage.
   */
  public async extractAndSaveMemory(userId: string, conversationId: string, userMessage: string): Promise<void> {
    // 1. Ask the AI if there is a memory to extract, and get sentiment
    const extractionPrompt = `Analyze the following user message. 
First, extract any important personal information, preferences, or events that a close companion should remember. If there is nothing worth remembering, output "NONE" for the memory.
Second, analyze the sentiment of the message towards the companion. Is the user being kind/affectionate (+1), neutral (0), or mean/abusive (-1)?

You MUST return a raw JSON object (without markdown code blocks) exactly matching this format:
{
  "memory": "concise statement or NONE",
  "sentiment": 1 or 0 or -1
}

User Message: "${userMessage}"`;

    const extractedResult = await this.aiProvider.generateChat({
      messages: [{ role: 'system', content: extractionPrompt }],
      temperature: 0.1, // Low temp for extraction tasks
    });

    let resultJson;
    try {
      let cleaned = extractedResult.trim();
      if (cleaned.startsWith('```json')) cleaned = cleaned.replace(/```json\n?/, '').replace(/```$/, '');
      if (cleaned.startsWith('```')) cleaned = cleaned.replace(/```\n?/, '').replace(/```$/, '');
      resultJson = JSON.parse(cleaned.trim());
    } catch (e) {
      console.error('Failed to parse memory/sentiment JSON:', extractedResult);
      return;
    }

    // Process Sentiment -> Relationship Stage
    if (resultJson.sentiment === 1) {
      // Small chance to increment relationship stage if they are being nice
      if (Math.random() > 0.5) { // 50% chance on a positive message to grow
        await prisma.conversation.update({
          where: { id: conversationId },
          data: {
            relationshipStage: {
              increment: 1
            }
          }
        });
        console.log(`[RELATIONSHIP UP] Conversation ${conversationId} grew closer!`);
      }
    }

    if (resultJson.memory === 'NONE' || !resultJson.memory) {
      return; // Nothing to remember
    }

    // 2. Generate embedding for the extracted memory
    const embedding = await this.aiProvider.generateEmbedding({ input: resultJson.memory });

    // 3. Save to database using raw SQL for the vector column
    const pgVector = `[${embedding.join(',')}]`;
    
    await prisma.$executeRaw`
      INSERT INTO "Memory" ("id", "userId", "content", "type", "importance", "createdAt", "embedding")
      VALUES (gen_random_uuid(), ${userId}, ${resultJson.memory}, 'personal', 'medium', NOW(), ${pgVector}::vector)
    `;
  }

  /**
   * Retrieves relevant memories based on the current conversation context.
   */
  public async retrieveRelevantMemories(userId: string, contextMessage: string, limit: number = 3): Promise<string[]> {
    // 1. Embed the context message
    const embedding = await this.aiProvider.generateEmbedding({ input: contextMessage });
    const pgVector = `[${embedding.join(',')}]`;

    // 2. Perform cosine similarity search using raw SQL
    // <=> is the cosine distance operator in pgvector
    const memories = await prisma.$queryRaw<{ content: string }[]>`
      SELECT content 
      FROM "Memory" 
      WHERE "userId" = ${userId}
      ORDER BY "embedding" <=> ${pgVector}::vector
      LIMIT ${limit}
    `;

    return memories.map(m => m.content);
  }
}
