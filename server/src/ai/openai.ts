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
        model: 'gpt-4o-mini',
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
      // Prioritize OpenRouter Fish Audio S2.1 Pro Free if key is configured
      if (process.env.OPENROUTER_API_KEY) {
        try {
          const res = await fetch('https://openrouter.ai/api/v1/audio/speech', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              model: 'fish-audio/s2.1-pro-free:free',
              input: options.input,
              response_format: 'mp3',
            }),
          });

          if (res.ok) {
            const arrayBuffer = await res.arrayBuffer();
            const buffer = Buffer.from(arrayBuffer);
            return `data:audio/mp3;base64,${buffer.toString('base64')}`;
          } else {
            console.error('OpenRouter TTS response not ok:', res.status, await res.text());
          }
        } catch (err) {
          console.error('OpenRouter TTS error, falling back to OpenAI TTS:', err);
        }
      }

      // Fallback to OpenAI TTS
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
