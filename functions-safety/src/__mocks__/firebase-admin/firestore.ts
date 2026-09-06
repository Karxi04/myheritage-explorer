// Mock for firebase-admin/firestore

export const FieldValue = {
  serverTimestamp: jest.fn(() => '__SERVER_TIMESTAMP__'),
  arrayUnion: jest.fn((...items: unknown[]) => ({ arrayUnion: items })),
  arrayRemove: jest.fn((...items: unknown[]) => ({ arrayRemove: items })),
  increment: jest.fn((n: number) => ({ increment: n })),
  delete: jest.fn(() => ({ delete: true })),
};

// Mock Firestore document reference
class MockDocRef {
  public id: string;
  public updates: Record<string, unknown>[] = [];

  constructor(id = 'mockId') {
    this.id = id;
  }

  async update(data: Record<string, unknown>) {
    this.updates.push(data);
    return this;
  }

  async get() {
    return { exists: false, data: () => null };
  }
}

export const mockDocRef = new MockDocRef();

// Expose a way for tests to reset and configure
export function resetMockDocRef() {
  mockDocRef.updates = [];
}

export const getFirestore = jest.fn(() => ({
  collection: jest.fn().mockReturnThis(),
  doc: jest.fn().mockReturnThis(),
}));
