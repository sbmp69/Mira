import OpenAI, { toFile } from 'openai';
import { AIProvider, AIGenerationOptions, AIEmbeddingOptions, AITranscriptionOptions, AISpeechOptions } from './provider';

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

      return response.choices[0]?.message?.content || '';
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

      return response.data[0]?.embedding || [];
    } catch (error) {
      console.error('Error generating embedding with OpenAI:', error);
      throw error;
    }
  }
  async transcribeAudio(options: AITranscriptionOptions): Promise<string> {
    try {
      const base64Data = options.audioBase64.split(',')[1] || options.audioBase64;
      const buffer = Buffer.from(base64Data, 'base64');
      const file = await toFile(buffer, 'audio.m4a', { type: 'audio/m4a' });
      
      const transcription = await this.openai.audio.transcriptions.create({
        file,
        model: 'whisper-1',
      });
      return transcription.text;
    } catch (error) {
      console.error('Error transcribing audio:', error);
      throw error;
    }
  }

  async generateSpeech(options: AISpeechOptions): Promise<string> {
    try {
      const mp3 = await this.openai.audio.speech.create({
        model: "tts-1",
        voice: options.voice || "nova",
        input: options.input,
      });
      const buffer = Buffer.from(await mp3.arrayBuffer());
      return `data:audio/mp3;base64,${buffer.toString('base64')}`;
    } catch (error) {
      console.error('Error generating speech:', error);
      throw error;
    }
  }
}
