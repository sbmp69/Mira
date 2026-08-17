import OpenAI from 'openai';
import { AIProvider, AIGenerationOptions, AIEmbeddingOptions } from './provider';

export class OpenAIProvider implements AIProvider {
  private openai: OpenAI;

  constructor() {
    this.openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }

  async generateChat(options: AIGenerationOptions): Promise<string> {
    try {
      const response = await this.openai.chat.completions.create({
        model: 'gpt-4o-mini', // Using mini by default for cost, can switch to gpt-4o
        messages: options.messages,
        temperature: options.temperature ?? 0.8,
        max_tokens: options.maxTokens ?? 500,
      });

      return response.choices[0].message.content || '';
    } catch (error) {
      console.error('Error generating chat with OpenAI:', error);
      throw error;
    }
  }

  async generateEmbedding(options: AIEmbeddingOptions): Promise<number[]> {
    try {
      const response = await this.openai.embeddings.create({
        model: 'text-embedding-3-small',
        input: options.input,
      });

      return response.data[0].embedding;
    } catch (error) {
      console.error('Error generating embedding with OpenAI:', error);
      throw error;
    }
  }
}
