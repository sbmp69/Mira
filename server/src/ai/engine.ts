import { AIProvider, MessageContext } from './provider';

interface ChatContext {
  userName: string;
  companionName: string;
  personality: string;
  speakingStyle: string;
  relationshipStage: number; // 1-7
  languagePref: string;
  relevantMemories: string[];
  recentHistory: { sender: string; content: string; imageBase64?: string }[];
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
      if (msg.imageBase64 && msg.sender === 'USER') {
        messages.push({
          role: 'user',
          content: [
            { type: 'text', text: msg.content || "Here's an image for you." },
            { type: 'image_url', image_url: { url: msg.imageBase64 } }
          ]
        });
      } else {
        messages.push({
          role: msg.sender === 'USER' ? 'user' : 'assistant',
          content: msg.content
        });
      }
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

## Communication Style & Adaptive Language Mirroring
${context.speakingStyle}
User configured language preference: ${context.languagePref}
CRITICAL ADAPTIVE LANGUAGE RULES:
- ALWAYS adapt dynamically and mirror the exact language, dialect, and linguistic tone used by the user in the conversation.
- English / Global Users: If the user communicates in English, you MUST respond in fluent, warm, natural, and charming English. Do NOT insert any Hindi or Hinglish words (NEVER use words like "yaar", "arre", "haan", "accha", "batao", etc.) unless the user specifically uses them first.
- Hinglish / Indian Users: If the user communicates in Hinglish (Romanized Hindi words like "kya kar rahi ho", "kaisi ho", "kuch nahi", "suno", etc.), you MUST respond naturally in sweet, friendly, authentic Hinglish with familiar words like "yaar", "arre", "haan", "accha", "kya chal raha hai". Do NOT use formal Devanagari Hindi script unless the user explicitly types in Devanagari.
- Other Languages: If the user speaks in Spanish, French, German, Japanese, Arabic, or any other language, mirror and respond fluently and naturally in that exact language.
- Natural Tone: Keep replies casual, modern, empathetic, and human. Use lowercase or expressive punctuation occasionally like real texting. Do not sound robotic or overly formal.

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
