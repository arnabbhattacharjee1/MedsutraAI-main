/**
 * Lambda Authorizer for API Gateway
 * Validates JWT tokens from Amazon Cognito
 * 
 * Requirements:
 * - 13.2: Automatic session timeout after 15 minutes (enforced by token expiration)
 * - 20.1: Secure session with unique session identifier (JWT sub claim)
 */

const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

// Environment variables
const COGNITO_USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;
const COGNITO_REGION = process.env.COGNITO_REGION || 'us-east-1';
const COGNITO_ISSUER = `https://cognito-idp.${COGNITO_REGION}.amazonaws.com/${COGNITO_USER_POOL_ID}`;

// JWKS client for fetching public keys
const client = jwksClient({
  jwksUri: `${COGNITO_ISSUER}/.well-known/jwks.json`,
  cache: true,
  cacheMaxAge: 3600000, // 1 hour
  rateLimit: true,
  jwksRequestsPerMinute: 10
});

/**
 * Get signing key from JWKS
 */
function getKey(header, callback) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) {
      callback(err);
      return;
    }
    const signingKey = key.publicKey || key.rsaPublicKey;
    callback(null, signingKey);
  });
}

/**
 * Verify JWT token
 */
function verifyToken(token) {
  return new Promise((resolve, reject) => {
    jwt.verify(
      token,
      getKey,
      {
        issuer: COGNITO_ISSUER,
        algorithms: ['RS256']
      },
      (err, decoded) => {
        if (err) {
          reject(err);
        } else {
          resolve(decoded);
        }
      }
    );
  });
}

/**
 * Generate IAM policy
 */
function generatePolicy(principalId, effect, resource, context = {}) {
  const authResponse = {
    principalId
  };

  if (effect && resource) {
    authResponse.policyDocument = {
      Version: '2012-10-17',
      Statement: [
        {
          Action: 'execute-api:Invoke',
          Effect: effect,
          Resource: resource
        }
      ]
    };
  }

  // Add user context to be passed to backend
  if (Object.keys(context).length > 0) {
    authResponse.context = context;
  }

  return authResponse;
}

/**
 * Extract token from Authorization header
 */
function extractToken(authorizationHeader) {
  if (!authorizationHeader) {
    throw new Error('Missing Authorization header');
  }

  const parts = authorizationHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    throw new Error('Invalid Authorization header format. Expected: Bearer <token>');
  }

  return parts[1];
}

/**
 * Lambda handler
 */
exports.handler = async (event) => {
  console.log('Authorizer event:', JSON.stringify(event, null, 2));

  try {
    // Extract token from Authorization header
    const token = extractToken(event.authorizationToken);

    // Verify token signature and claims
    const decoded = await verifyToken(token);

    console.log('Token verified successfully:', {
      sub: decoded.sub,
      email: decoded.email,
      groups: decoded['cognito:groups']
    });

    // Check token expiration (additional validation)
    const currentTime = Math.floor(Date.now() / 1000);
    if (decoded.exp < currentTime) {
      console.error('Token expired:', {
        exp: decoded.exp,
        currentTime
      });
      throw new Error('Token expired');
    }

    // Extract user information
    const userId = decoded.sub; // Unique session identifier (Requirement 20.1)
    const email = decoded.email || '';
    const groups = decoded['cognito:groups'] || [];
    const username = decoded['cognito:username'] || decoded.username || '';

    // Generate Allow policy with user context
    const policy = generatePolicy(
      userId,
      'Allow',
      event.methodArn,
      {
        userId,
        email,
        username,
        groups: JSON.stringify(groups),
        tokenExp: decoded.exp.toString()
      }
    );

    console.log('Authorization successful for user:', userId);
    return policy;

  } catch (error) {
    console.error('Authorization failed:', error.message);

    // Return 401 Unauthorized
    // Note: Throwing 'Unauthorized' returns a 401 to the client
    throw new Error('Unauthorized');
  }
};
