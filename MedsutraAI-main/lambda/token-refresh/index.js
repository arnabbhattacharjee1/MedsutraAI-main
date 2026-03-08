/**
 * Token Refresh Lambda Function
 * Handles automatic token refresh using Cognito refresh tokens
 * 
 * Requirements:
 * - 13.2: Automatic session timeout after 15 minutes (ID tokens expire in 15 min)
 * - 20.1: Secure session with unique session identifier
 */

const {
  CognitoIdentityProviderClient,
  InitiateAuthCommand
} = require('@aws-sdk/client-cognito-identity-provider');

// Environment variables
const COGNITO_USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;
const COGNITO_CLIENT_ID = process.env.COGNITO_CLIENT_ID;
const COGNITO_REGION = process.env.COGNITO_REGION || 'us-east-1';

// Cognito client
const cognitoClient = new CognitoIdentityProviderClient({
  region: COGNITO_REGION
});

/**
 * Refresh tokens using refresh token
 */
async function refreshTokens(refreshToken) {
  const command = new InitiateAuthCommand({
    AuthFlow: 'REFRESH_TOKEN_AUTH',
    ClientId: COGNITO_CLIENT_ID,
    AuthParameters: {
      REFRESH_TOKEN: refreshToken
    }
  });

  const response = await cognitoClient.send(command);
  return response.AuthenticationResult;
}

/**
 * Lambda handler
 */
exports.handler = async (event) => {
  console.log('Token refresh request:', JSON.stringify(event, null, 2));

  // CORS headers
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*', // Configure this properly in production
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'POST,OPTIONS'
  };

  // Handle OPTIONS request for CORS
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers,
      body: ''
    };
  }

  try {
    // Parse request body
    const body = JSON.parse(event.body || '{}');
    const { refreshToken } = body;

    if (!refreshToken) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: 'Bad Request',
          message: 'Missing refreshToken in request body'
        })
      };
    }

    // Refresh tokens
    const authResult = await refreshTokens(refreshToken);

    console.log('Tokens refreshed successfully');

    // Return new tokens
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        idToken: authResult.IdToken,
        accessToken: authResult.AccessToken,
        expiresIn: authResult.ExpiresIn, // Typically 3600 seconds (1 hour) but configured to 900 (15 min)
        tokenType: authResult.TokenType
      })
    };

  } catch (error) {
    console.error('Token refresh failed:', error);

    // Determine error type
    let statusCode = 500;
    let errorMessage = 'Internal server error';

    if (error.name === 'NotAuthorizedException') {
      statusCode = 401;
      errorMessage = 'Invalid or expired refresh token';
    } else if (error.name === 'UserNotFoundException') {
      statusCode = 404;
      errorMessage = 'User not found';
    } else if (error.name === 'TooManyRequestsException') {
      statusCode = 429;
      errorMessage = 'Too many requests';
    }

    return {
      statusCode,
      headers,
      body: JSON.stringify({
        error: error.name || 'Error',
        message: errorMessage
      })
    };
  }
};
