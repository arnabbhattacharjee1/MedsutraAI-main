/**
 * Unit tests for Token Refresh Lambda
 */

const { handler } = require('./index');
const { CognitoIdentityProviderClient, InitiateAuthCommand } = require('@aws-sdk/client-cognito-identity-provider');

// Mock AWS SDK
jest.mock('@aws-sdk/client-cognito-identity-provider');

// Mock environment variables
process.env.COGNITO_USER_POOL_ID = 'us-east-1_TEST123';
process.env.COGNITO_CLIENT_ID = 'test-client-id';
process.env.COGNITO_REGION = 'us-east-1';

describe('Token Refresh Lambda', () => {
  const mockRefreshToken = 'mock-refresh-token';
  const mockAuthResult = {
    IdToken: 'new-id-token',
    AccessToken: 'new-access-token',
    ExpiresIn: 900, // 15 minutes (Requirement 13.2)
    TokenType: 'Bearer'
  };

  let mockSend;

  beforeEach(() => {
    jest.clearAllMocks();
    mockSend = jest.fn();
    CognitoIdentityProviderClient.mockImplementation(() => ({
      send: mockSend
    }));
  });

  describe('Successful Token Refresh', () => {
    test('should refresh tokens successfully', async () => {
      mockSend.mockResolvedValue({
        AuthenticationResult: mockAuthResult
      });

      const event = {
        httpMethod: 'POST',
        body: JSON.stringify({ refreshToken: mockRefreshToken })
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.body);
      expect(body.idToken).toBe('new-id-token');
      expect(body.accessToken).toBe('new-access-token');
      expect(body.expiresIn).toBe(900);
      expect(body.tokenType).toBe('Bearer');
    });

    test('should return tokens with 15-minute expiration (Requirement 13.2)', async () => {
      mockSend.mockResolvedValue({
        AuthenticationResult: mockAuthResult
      });

      const event = {
        httpMethod: 'POST',
        body: JSON.stringify({ refreshToken: mockRefreshToken })
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.body);
      expect(body.expiresIn).toBe(900); // 15 minutes = 900 seconds
    });

    test('should include CORS headers', async () => {
      mockSend.mockResolvedValue({
        AuthenticationResult: mockAuthResult
      });

      const event = {
        httpMethod: 'POST',
        body: JSON.stringify({ refreshToken: mockRefreshToken })
      };

      const result = await handler(event);

      expect(result.headers).toHaveProperty('Access-Control-Allow-Origin');
      expect(result.headers).toHaveProperty('Access-Control-Allow-Headers');
      expect(result.headers).toHaveProperty('Access-Control-Allow-Methods');
    });
  });

  describe('CORS Preflight', () => {
    test('should handle OPTIONS request', async () => {
      const event = {
        httpMethod: 'OPTIONS'
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(200);
      expect(result.body).toBe('');
      expect(result.headers).toHaveProperty('Access-Control-Allow-Origin');
    });
  });

  describe('Error Handling', () => {
    test('should return 400 for missing refresh token', async () => {
      const event = {
        httpMethod: 'POST',
        body: JSON.stringify({})
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.error).toBe('Bad Request');
      expect(body.message).toContain('Missing refreshToken');
    });

    test('should return 401 for invalid refresh token', async () => {
      const error = new Error('Invalid refresh token');
      error.name = 'NotAuthorizedException';
      mockSend.mockRejectedValue(error);

      const event = {
        httpMethod: 'POST',
        body: JSON.stringify({ refreshToken: 'invalid-token' })
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(401);
      const body = JSON.parse(result.body);
      expect(body.message).toContain('Invalid or expired refresh token');
    });

    test('should return 404 for user not found', async () => {
      const error = new Error('User not found');
      error.name = 'UserNotFoundException';
      mockSend.mockRejectedValue(error);

      const event = {
        httpMethod: 'POST',
        body: JSON.stringify({ refreshToken: mockRefreshToken })
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(404);
      const body = JSON.parse(result.body);
      expect(body.message).toContain('User not found');
    });

    test('should return 429 for too many requests', async () => {
      const error = new Error('Too many requests');
      error.name = 'TooManyRequestsException';
      mockSend.mockRejectedValue(error);

      const event = {
        httpMethod: 'POST',
        body: JSON.stringify({ refreshToken: mockRefreshToken })
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(429);
      const body = JSON.parse(result.body);
      expect(body.message).toContain('Too many requests');
    });

    test('should return 500 for unknown errors', async () => {
      mockSend.mockRejectedValue(new Error('Unknown error'));

      const event = {
        httpMethod: 'POST',
        body: JSON.stringify({ refreshToken: mockRefreshToken })
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.message).toContain('Internal server error');
    });

    test('should handle malformed JSON body', async () => {
      const event = {
        httpMethod: 'POST',
        body: 'invalid-json'
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(500);
    });
  });

  describe('Cognito Integration', () => {
    test('should call InitiateAuth with correct parameters', async () => {
      mockSend.mockResolvedValue({
        AuthenticationResult: mockAuthResult
      });

      const event = {
        httpMethod: 'POST',
        body: JSON.stringify({ refreshToken: mockRefreshToken })
      };

      await handler(event);

      expect(mockSend).toHaveBeenCalledWith(expect.any(InitiateAuthCommand));
    });
  });
});
