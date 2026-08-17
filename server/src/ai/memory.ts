import { prisma } from '../db';
import { AIProvider } from './provider';

export class MemoryService {
  constructor(private aiProvider: AIProvider) {}

  /**
   * Evaluates the latest user message to see if a memory should be extracted and saved.
   */
  public async extractAndSaveMemory(userId: string, userMessage: string): Promise<void> {
    // 1. Ask the AI if there is a memory to extract
    const extractionPrompt = `Analyze the following user message and extract any important personal information, preferences, or events that a close companion should remember. 
If there is nothing worth remembering, output exactly "NONE".
If there is a memory, output it as a concise statement (e.g., "User's birthday is October 12", "User hates pineapple on pizza", "User has a college exam tomorrow").

User Message: "${userMessage}"`;

    const extractedResult = await this.aiProvider.generateChat({
      messages: [{ role: 'system', content: extractionPrompt }],
      temperature: 0.1, // Low temp for extraction tasks
    });

    if (extractedResult.trim() === 'NONE' || extractedResult.trim().length === 0) {
      return; // Nothing to remember
    }

    // 2. Generate embedding for the extracted memory
    const embedding = await this.aiProvider.generateEmbedding({ input: extractedResult });

    // 3. Save to database using raw SQL for the vector column
    // Prisma requires raw queries to insert vector data directly
    const pgVector = `[${embedding.join(',')}]`;
    
    await prisma.$executeRaw`
      INSERT INTO "Memory" ("id", "userId", "content", "type", "importance", "createdAt", "embedding")
      VALUES (gen_random_uuid(), ${userId}, ${extractedResult}, 'personal', 'medium', NOW(), ${pgVector}::vector)
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
