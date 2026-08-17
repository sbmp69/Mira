export interface MessageContext {
  role: 'system' | 'user' | 'assistant';
  content: string | any[];
}

export interface AIGenerationOptions {
  messages: MessageContext[];
  temperature?: number;
  maxTokens?: number;
  // Can add stop sequences, etc. here
}

export interface AIEmbeddingOptions {
  input: string;
}

export interface AITranscriptionOptions {
  audioBase64: string; // m4a or mp3 base64
}

export interface AISpeechOptions {
  input: string; // Text to synthesize
  voice?: 'alloy' | 'echo' | 'fable' | 'onyx' | 'nova' | 'shimmer';
}

export interface AIProvider {
  /**
   * Generates a response based on a chat history.
   * Can return a string or stream (we'll stick to string for now for simplicity, 
   * but streaming is important for the real app).
   */
  generateChat(options: AIGenerationOptions): Promise<string>;
  
  /**
   * Generates an embedding vector for a given text input.
   * Useful for storing memories.
   */
  generateEmbedding(options: AIEmbeddingOptions): Promise<number[]>;

  /**
   * Transcribes audio base64 to text (Speech to Text)
   */
  transcribeAudio(options: AITranscriptionOptions): Promise<string>;

  /**
   * Generates speech from text (Text to Speech)
   * Returns base64 mp3 string
   */
  generateSpeech(options: AISpeechOptions): Promise<string>;
}
