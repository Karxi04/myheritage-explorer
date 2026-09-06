// Mock for firebase-functions/v2/firestore
export const onDocumentCreated = jest.fn(
  (_options: unknown, handler: unknown) => handler,
);
