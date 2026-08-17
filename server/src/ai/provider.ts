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
}
