/**
 * Unit tests for Session Manager Lambda
 */

// Mock AWS SDK
const mockSend = jest.fn();
jest.mock('@aws-sdk/client-dynamodb', () => ({
  DynamoDBClient: jest.fn(() => ({}))
}));
jest.mock('@aws-sdk/lib-dynamodb', () => ({
  DynamoDBDocumentClient: {
    from: jest.fn(() => ({
      send: mockSend
    }))
  },
  PutCommand: jest.fn((params) => ({ name: 'PutCommand', params })),
  GetCommand: jest.fn((params) => ({ name: 'GetCommand', params })),
  UpdateCommand: jest.fn((params) => ({ name: 'UpdateCommand', params })),
  DeleteCommand: jest.fn((params) => ({ name: 'DeleteCommand', params })),
  QueryCommand: jest.fn((params) => ({ name: 'QueryCommand', params }))
}));

// Mock crypto
jest.mock('crypto', () => ({
  randomUUID: jest.fn(() => 'test-session-id-12345')
}));

// Set environment variables
process.env.SESSIONS_TABLE = 'test-sessions-table';
process.env.SESSION_TIMEOUT_MINUTES = '15';
process.env.AWS_REGION = 'us-east-1';

const { handler } = require('./index');

describe('Session Manager Lambda', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Reset Date.now to a fixed value for consistent testing
    jest.spyOn(Date, 'now').mockReturnValue(1000000000);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('Create Session', () => {
    test('should create a new session successfully', async () => {
      // Mock: No existing sessions
      mockSend.mockResolvedValueOnce({ Items: [] });
      // Mock: Session created
      mockSend.mockResolvedValueOnce({});

      const event = {
        httpMethod: 'POST',
        path: '/sessions',
        body: JSON.stringify({
          userId: 'user-123',
          userEmail: 'test@example.com',
          userGroups: ['Doctor']
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(201);
      expect(body.sessionId).toBe('test-session-id-12345');
      expect(body.expiresIn).toBe(900); // 15 minutes in seconds
      expect(mockSend).toHaveBeenCalledTimes(2);
    });

    test('should invalidate existing sessions before creating new one (Requirement 20.5)', async () => {
      // Mock: Existing active session
      mockSend.mockResolvedValueOnce({
        Items: [
          {
            session_id: 'old-session-id',
            user_id: 'user-123',
            is_active: true
          }
        ]
      });
      // Mock: Invalidate old session
      mockSend.mockResolvedValueOnce({});
      // Mock: Create new session
      mockSend.mockResolvedValueOnce({});

      const event = {
        httpMethod: 'POST',
        path: '/sessions',
        body: JSON.stringify({
          userId: 'user-123',
          userEmail: 'test@example.com',
          userGroups: ['Doctor']
        })
      };

      const response = await handler(event);

      expect(response.statusCode).toBe(201);
      expect(mockSend).toHaveBeenCalledTimes(3); // Query + Invalidate + Create
    });

    test('should return 400 if userId is missing', async () => {
      const event = {
        httpMethod: 'POST',
        path: '/sessions',
        body: JSON.stringify({
          userEmail: 'test@example.com'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(400);
      expect(body.error).toBe('Bad Request');
      expect(body.message).toContain('userId');
    });
  });

  describe('Validate Session', () => {
    test('should validate an active session successfully', async () => {
      const now = Date.now();
      const expiresAt = now + (15 * 60 * 1000);

      mockSend.mockResolvedValueOnce({
        Item: {
          session_id: 'test-session-id',
          user_id: 'user-123',
          user_email: 'test@example.com',
          user_groups: ['Doctor'],
          created_at: now - 60000,
          last_activity: now - 60000,
          expires_at: expiresAt,
          is_active: true
        }
      });

      const event = {
        httpMethod: 'POST',
        path: '/sessions/validate',
        body: JSON.stringify({
          sessionId: 'test-session-id'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(200);
      expect(body.valid).toBe(true);
      expect(body.session.userId).toBe('user-123');
    });

    test('should return 401 for expired session (Requirement 20.2)', async () => {
      const now = Date.now();
      const expiredTime = now - 1000; // Expired 1 second ago

      mockSend.mockResolvedValueOnce({
        Item: {
          session_id: 'test-session-id',
          user_id: 'user-123',
          expires_at: expiredTime,
          is_active: true
        }
      });
      // Mock: Invalidate expired session
      mockSend.mockResolvedValueOnce({});

      const event = {
        httpMethod: 'POST',
        path: '/sessions/validate',
        body: JSON.stringify({
          sessionId: 'test-session-id'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(401);
      expect(body.valid).toBe(false);
      expect(body.reason).toContain('expired');
    });

    test('should return 401 for non-existent session', async () => {
      mockSend.mockResolvedValueOnce({ Item: null });

      const event = {
        httpMethod: 'POST',
        path: '/sessions/validate',
        body: JSON.stringify({
          sessionId: 'non-existent-session'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(401);
      expect(body.valid).toBe(false);
      expect(body.reason).toContain('not found');
    });

    test('should return 401 for inactive session', async () => {
      mockSend.mockResolvedValueOnce({
        Item: {
          session_id: 'test-session-id',
          user_id: 'user-123',
          expires_at: Date.now() + 100000,
          is_active: false
        }
      });

      const event = {
        httpMethod: 'POST',
        path: '/sessions/validate',
        body: JSON.stringify({
          sessionId: 'test-session-id'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(401);
      expect(body.valid).toBe(false);
      expect(body.reason).toContain('inactive');
    });

    test('should return 400 if sessionId is missing', async () => {
      const event = {
        httpMethod: 'POST',
        path: '/sessions/validate',
        body: JSON.stringify({})
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(400);
      expect(body.error).toBe('Bad Request');
    });
  });

  describe('Update Session Activity', () => {
    test('should update session activity and extend expiration (Requirement 13.3)', async () => {
      mockSend.mockResolvedValueOnce({});

      const event = {
        httpMethod: 'PUT',
        path: '/sessions/activity',
        body: JSON.stringify({
          sessionId: 'test-session-id'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(200);
      expect(body.success).toBe(true);
      expect(body.expiresIn).toBe(900); // 15 minutes
      expect(mockSend).toHaveBeenCalledTimes(1);
    });

    test('should return 404 for non-existent or inactive session', async () => {
      mockSend.mockRejectedValueOnce({
        name: 'ConditionalCheckFailedException'
      });

      const event = {
        httpMethod: 'PUT',
        path: '/sessions/activity',
        body: JSON.stringify({
          sessionId: 'non-existent-session'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(404);
      expect(body.error).toBe('Not Found');
    });

    test('should return 400 if sessionId is missing', async () => {
      const event = {
        httpMethod: 'PUT',
        path: '/sessions/activity',
        body: JSON.stringify({})
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(400);
      expect(body.error).toBe('Bad Request');
    });
  });

  describe('Invalidate Session (Logout)', () => {
    test('should invalidate session successfully (Requirement 20.4)', async () => {
      mockSend.mockResolvedValueOnce({});

      const event = {
        httpMethod: 'DELETE',
        path: '/sessions',
        body: JSON.stringify({
          sessionId: 'test-session-id'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(200);
      expect(body.success).toBe(true);
      expect(body.message).toContain('invalidated');
      expect(mockSend).toHaveBeenCalledTimes(1);
    });

    test('should return 404 for non-existent session', async () => {
      mockSend.mockRejectedValueOnce({
        name: 'ConditionalCheckFailedException'
      });

      const event = {
        httpMethod: 'DELETE',
        path: '/sessions',
        body: JSON.stringify({
          sessionId: 'non-existent-session'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(404);
      expect(body.error).toBe('Not Found');
    });

    test('should return 400 if sessionId is missing', async () => {
      const event = {
        httpMethod: 'DELETE',
        path: '/sessions',
        body: JSON.stringify({})
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(400);
      expect(body.error).toBe('Bad Request');
    });
  });

  describe('CORS and Error Handling', () => {
    test('should handle OPTIONS request for CORS', async () => {
      const event = {
        httpMethod: 'OPTIONS',
        path: '/sessions'
      };

      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      expect(response.headers['Access-Control-Allow-Origin']).toBe('*');
      expect(response.body).toBe('');
    });

    test('should return 404 for unknown endpoint', async () => {
      const event = {
        httpMethod: 'GET',
        path: '/unknown',
        body: '{}'
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(404);
      expect(body.error).toBe('Not Found');
    });

    test('should handle internal errors gracefully', async () => {
      mockSend.mockRejectedValueOnce(new Error('DynamoDB error'));

      const event = {
        httpMethod: 'POST',
        path: '/sessions/validate',
        body: JSON.stringify({
          sessionId: 'test-session-id'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(response.statusCode).toBe(500);
      expect(body.error).toBe('Internal Server Error');
    });
  });

  describe('Session Timeout Configuration', () => {
    test('should use configured timeout value', async () => {
      // Mock: No existing sessions
      mockSend.mockResolvedValueOnce({ Items: [] });
      // Mock: Session created
      mockSend.mockResolvedValueOnce({});

      const event = {
        httpMethod: 'POST',
        path: '/sessions',
        body: JSON.stringify({
          userId: 'user-123',
          userEmail: 'test@example.com'
        })
      };

      const response = await handler(event);
      const body = JSON.parse(response.body);

      expect(body.expiresIn).toBe(900); // 15 minutes * 60 seconds
    });
  });
});
