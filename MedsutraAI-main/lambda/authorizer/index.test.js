/**
 * Unit tests for JWT Lambda Authorizer
 */

const jwt = require('jsonwebtoken');
const { handler } = require('./index');

// Mock environment variables
process.env.COGNITO_USER_POOL_ID = 'us-east-1_TEST123';
process.env.COGNITO_REGION = 'us-east-1';

// Mock jwks-rsa
jest.mock('jwks-rsa', () => {
  return jest.fn(() => ({
    getSigningKey: jest.fn((kid, callback) => {
      // Return a mock public key
      callback(null, {
        publicKey: 'mock-public-key',
        rsaPublicKey: 'mock-rsa-public-key'
      });
    })
  }));
});

// Mock jsonwebtoken
jest.mock('jsonwebtoken');

describe('JWT Lambda Authorizer', () => {
  const mockEvent = {
    type: 'TOKEN',
    authorizationToken: 'Bearer mock-token',
    methodArn: 'arn:aws:execute-api:us-east-1:123456789012:abcdef123/prod/GET/patients'
  };

  const mockDecodedToken = {
    sub: 'user-123',
    email: 'test@example.com',
    'cognito:username': 'testuser',
    'cognito:groups': ['Doctor'],
    exp: Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
    iss: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TEST123'
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Successful Authorization', () => {
    test('should return Allow policy for valid token', async () => {
      // Mock successful token verification
      jwt.verify.mockImplementation((token, getKey, options, callback) => {
        callback(null, mockDecodedToken);
      });

      const result = await handler(mockEvent);

      expect(result).toHaveProperty('principalId', 'user-123');
      expect(result).toHaveProperty('policyDocument');
      expect(result.policyDocument.Statement[0].Effect).toBe('Allow');
      expect(result.policyDocument.Statement[0].Resource).toBe(mockEvent.methodArn);
      expect(result).toHaveProperty('context');
      expect(result.context.userId).toBe('user-123');
      expect(result.context.email).toBe('test@example.com');
      expect(result.context.groups).toBe(JSON.stringify(['Doctor']));
    });

    test('should extract user information correctly', async () => {
      jwt.verify.mockImplementation((token, getKey, options, callback) => {
        callback(null, mockDecodedToken);
      });

      const result = await handler(mockEvent);

      expect(result.context.userId).toBe('user-123');
      expect(result.context.email).toBe('test@example.com');
      expect(result.context.username).toBe('testuser');
      expect(JSON.parse(result.context.groups)).toEqual(['Doctor']);
    });

    test('should handle token without groups', async () => {
      const tokenWithoutGroups = { ...mockDecodedToken };
      delete tokenWithoutGroups['cognito:groups'];

      jwt.verify.mockImplementation((token, getKey, options, callback) => {
        callback(null, tokenWithoutGroups);
      });

      const result = await handler(mockEvent);

      expect(result.context.userId).toBe('user-123');
      expect(JSON.parse(result.context.groups)).toEqual([]);
    });
  });

  describe('Failed Authorization', () => {
    test('should throw Unauthorized for missing Authorization header', async () => {
      const eventWithoutAuth = { ...mockEvent, authorizationToken: undefined };

      await expect(handler(eventWithoutAuth)).rejects.toThrow('Unauthorized');
    });

    test('should throw Unauthorized for invalid Authorization header format', async () => {
      const eventWithInvalidAuth = { ...mockEvent, authorizationToken: 'InvalidFormat' };

      await expect(handler(eventWithInvalidAuth)).rejects.toThrow('Unauthorized');
    });

    test('should throw Unauthorized for expired token', async () => {
      const expiredToken = {
        ...mockDecodedToken,
        exp: Math.floor(Date.now() / 1000) - 3600 // 1 hour ago
      };

      jwt.verify.mockImplementation((token, getKey, options, callback) => {
        callback(null, expiredToken);
      });

      await expect(handler(mockEvent)).rejects.toThrow('Unauthorized');
    });

    test('should throw Unauthorized for invalid token signature', async () => {
      jwt.verify.mockImplementation((token, getKey, options, callback) => {
        callback(new Error('invalid signature'));
      });

      await expect(handler(mockEvent)).rejects.toThrow('Unauthorized');
    });

    test('should throw Unauthorized for token verification error', async () => {
      jwt.verify.mockImplementation((token, getKey, options, callback) => {
        callback(new Error('Token verification failed'));
      });

      await expect(handler(mockEvent)).rejects.toThrow('Unauthorized');
    });
  });

  describe('Token Expiration Validation', () => {
    test('should validate token expiration time (Requirement 13.2)', async () => {
      // Token expires in 15 minutes (900 seconds)
      const tokenExpiring15Min = {
        ...mockDecodedToken,
        exp: Math.floor(Date.now() / 1000) + 900
      };

      jwt.verify.mockImplementation((token, getKey, options, callback) => {
        callback(null, tokenExpiring15Min);
      });

      const result = await handler(mockEvent);

      expect(result.principalId).toBe('user-123');
      expect(result.context.tokenExp).toBe(tokenExpiring15Min.exp.toString());
    });

    test('should reject token that is already expired', async () => {
      const expiredToken = {
        ...mockDecodedToken,
        exp: Math.floor(Date.now() / 1000) - 1 // 1 second ago
      };

      jwt.verify.mockImplementation((token, getKey, options, callback) => {
        callback(null, expiredToken);
      });

      await expect(handler(mockEvent)).rejects.toThrow('Unauthorized');
    });
  });

  describe('Session Identifier Validation', () => {
    test('should extract unique session identifier from sub claim (Requirement 20.1)', async () => {
      jwt.verify.mockImplementation((token, getKey, options, callback) => {
        callback(null, mockDecodedToken);
      });

      const result = await handler(mockEvent);

      // Verify unique session identifier (sub claim) is used as principalId
      expect(result.principalId).toBe('user-123');
      expect(result.context.userId).toBe('user-123');
    });
  });

  describe('Multiple User Groups', () => {
    test('should handle multiple user groups', async () => {
      const tokenWithMultipleGroups = {
        ...mockDecodedToken,
        'cognito:groups': ['Doctor', 'Oncologist', 'Admin']
      };

      jwt.verify.mockImplementation((token, getKey, options, callback) => {
        callback(null, tokenWithMultipleGroups);
      });

      const result = await handler(mockEvent);

      expect(JSON.parse(result.context.groups)).toEqual(['Doctor', 'Oncologist', 'Admin']);
    });
  });
});
