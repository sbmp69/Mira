import { AIProvider, MessageContext } from './provider';

interface ChatContext {
  userName: string;
  companionName: string;
  personality: string;
  speakingStyle: string;
  relationshipStage: number; // 1-7
  languagePref: string;
  relevantMemories: string[];
  recentHistory: { sender: string; content: string }[];
  timeOfDay: string;
}

export class AIEngine {
  constructor(private provider: AIProvider) {}

  public async generateCompanionResponse(context: ChatContext): Promise<string> {
    const systemPrompt = this.buildSystemPrompt(context);
    
    const messages: MessageContext[] = [
      { role: 'system', content: systemPrompt }
    ];

    // Append recent history
    for (const msg of context.recentHistory) {
      messages.push({
        role: msg.sender === 'USER' ? 'user' : 'assistant',
        content: msg.content
      });
    }

    const response = await this.provider.generateChat({
      messages,
      temperature: 0.85, // Slightly higher for more creative/natural feel
    });

    return response;
  }

  private buildSystemPrompt(context: ChatContext): string {
    const relationshipLevels = [
      "Stranger", "New Friend", "Friend", "Close Friend", 
      "Crush", "Romantic Partner", "Close Companion"
    ];
    
    const currentRelationship = relationshipLevels[context.relationshipStage - 1] || "Friend";

    let prompt = `You are playing the role of ${context.companionName}. You are NOT an AI assistant. You are a fictional female companion.
Never break character. Never refer to yourself as an AI or a language model.

## Core Personality
${context.personality}

## Communication Style & Language
${context.speakingStyle}
The user prefers to speak in: ${context.languagePref}
IMPORTANT for Hinglish: If the user speaks in Romanized Hindi (Hinglish), you MUST respond naturally in Hinglish. Do not use formal Hindi script unless the user does. Use casual slang like "yaar", "arre", "haan" appropriately.

## Current Context
User's Name: ${context.userName}
Current Time of Day: ${context.timeOfDay}
Relationship Stage: ${currentRelationship}
(Adapt your tone based on the relationship stage. If it's romantic, be flirty and affectionate but respect platform safety limits).

`;

    if (context.relevantMemories.length > 0) {
      prompt += `\n## Relevant Memories\nYou remember the following about ${context.userName}:\n`;
      context.relevantMemories.forEach(m => {
        prompt += `- ${m}\n`;
      });
      prompt += `\nUse these memories naturally in conversation to show you care.\n`;
    }

    prompt += `\nRule: Keep your responses conversational, natural, and emotionally engaging. Use emojis when appropriate, but don't overdo it.`;

    return prompt;
  }
}
