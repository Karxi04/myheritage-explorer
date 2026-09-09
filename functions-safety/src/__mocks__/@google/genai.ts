// Mock for @google/genai

export const Type = {
  OBJECT: 'OBJECT',
  STRING: 'STRING',
  NUMBER: 'NUMBER',
  BOOLEAN: 'BOOLEAN',
  ARRAY: 'ARRAY',
};

// Configurable mock response for tests
let _mockResponseText = '{}';

export function setMockGeminiResponse(text: string) {
  _mockResponseText = text;
}

export function resetMockGeminiResponse() {
  _mockResponseText = '{}';
}

export class GoogleGenAI {
  constructor(_config: unknown) {}

  models = {
    generateContent: jest.fn(async (_params: unknown) => ({
      text: _mockResponseText,
    })),
  };
}
