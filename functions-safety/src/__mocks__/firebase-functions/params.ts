// Mock for firebase-functions/params
export const defineSecret = jest.fn((name: string) => ({
  value: () => `mock-secret-${name}`,
}));
export const defineString = jest.fn((name: string) => ({
  value: () => `mock-string-${name}`,
}));
