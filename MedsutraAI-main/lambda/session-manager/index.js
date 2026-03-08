/**
 * Session Manager Lambda Function
 * Handles session creation, validation, update, and invalidation
 * 
 * Requirements:
 * - 13.3: Automatic session timeout after 15 minutes of inactivity
 * - 20.1: Secure session with unique session identifier
 * - 20.2: Invalidate session after 15 minutes of inactivity
 * - 20.3: Redirect to authentication page when session expires
 * - 20.4: Immediately invalidate session on logout
 * - 20.5: Prevent concurrent sessions for same user account
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  UpdateCommand,
  DeleteCommand,
  QueryCommand
} = require('@aws-sdk/lib-dynamodb');
const { randomUUID } = require('crypto');

// Environment variables
const SESSIONS_TABLE = process.env.SESSIONS_TABLE;
const SESSION_TIMEOUT_MINUTES = parseInt(process.env.SESSION_TIMEOUT_MINUTES || '15');
const AWS_REGION = process.env.AWS_REGION || 'us-east-1';

// DynamoDB client
const dynamoClient = new DynamoDBClient({ region: AWS_REGION });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

/**
 * CORS headers
 */
const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'POST,GET,PUT,DELETE,OPTIONS'
};

/**
 * Create a new session
 * Requirement 20.1: Secure session with unique session identifier
 * Requirement 20.5: Prevent concurrent sessions for same user
 */
async function createSession(userId, userEmail, userGroups) {
  // Check for existing active sessions (Requirement 20.5)
  const existingSessions = await getUserSessions(userId);
  
  // Invalidate all existing sessions for this user
  for (const session of existingSessions) {
    await invalidateSession(session.session_id);
  }

  // Generate unique session ID
  const sessionId = randomUUID();
  const now = Date.now();
  const expiresAt = now + (SESSION_TIMEOUT_MINUTES * 60 * 1000);
  const ttl = Math.floor(expiresAt / 1000); // TTL in seconds for DynamoDB

  const sessionItem = {
    session_id: sessionId,
    user_id: userId,
    user_email: userEmail,
    user_groups: userGroups || [],
    created_at: now,
    last_activity: now,
    expires_at: expiresAt,
    ttl: ttl,
    is_active: true
  };

  await docClient.send(new PutCommand({
    TableName: SESSIONS_TABLE,
    Item: sessionItem
  }));

  console.log('Session created:', {
    sessionId,
    userId,
    expiresAt: new Date(expiresAt).toISOString()
  });

  return {
    sessionId,
    expiresAt,
    expiresIn: SESSION_TIMEOUT_MINUTES * 60
  };
}

/**
 * Get user sessions by user_id
 */
async function getUserSessions(userId) {
  const result = await docClient.send(new QueryCommand({
    TableName: SESSIONS_TABLE,
    IndexName: 'UserIdIndex',
    KeyConditionExpression: 'user_id = :userId',
    ExpressionAttributeValues: {
      ':userId': userId
    }
  }));

  return result.Items || [];
}

/**
 * Validate session
 * Requirement 20.2: Invalidate session after 15 minutes of inactivity
 */
async function validateSession(sessionId) {
  const result = await docClient.send(new GetCommand({
    TableName: SESSIONS_TABLE,
    Key: { session_id: sessionId }
  }));

  if (!result.Item) {
    return {
      valid: false,
      reason: 'Session not found'
    };
  }

  const session = result.Item;
  const now = Date.now();

  // Check if session is active
  if (!session.is_active) {
    return {
      valid: false,
      reason: 'Session is inactive'
    };
  }

  // Check if session has expired (Requirement 20.2)
  if (session.expires_at < now) {
    // Invalidate expired session
    await invalidateSession(sessionId);
    return {
      valid: false,
      reason: 'Session expired due to inactivity'
    };
  }

  return {
    valid: true,
    session: {
      sessionId: session.session_id,
      userId: session.user_id,
      userEmail: session.user_email,
      userGroups: session.user_groups,
      lastActivity: session.last_activity,
      expiresAt: session.expires_at
    }
  };
}

/**
 * Update session activity
 * Requirement 13.3: Automatic session timeout after 15 minutes of inactivity
 */
async function updateSessionActivity(sessionId) {
  const now = Date.now();
  const expiresAt = now + (SESSION_TIMEOUT_MINUTES * 60 * 1000);
  const ttl = Math.floor(expiresAt / 1000);

  try {
    await docClient.send(new UpdateCommand({
      TableName: SESSIONS_TABLE,
      Key: { session_id: sessionId },
      UpdateExpression: 'SET last_activity = :now, expires_at = :expiresAt, #ttl = :ttl',
      ExpressionAttributeNames: {
        '#ttl': 'ttl'
      },
      ExpressionAttributeValues: {
        ':now': now,
        ':expiresAt': expiresAt,
        ':ttl': ttl
      },
      ConditionExpression: 'attribute_exists(session_id) AND is_active = :true',
      ExpressionAttributeValues: {
        ':now': now,
        ':expiresAt': expiresAt,
        ':ttl': ttl,
        ':true': true
      }
    }));

    console.log('Session activity updated:', {
      sessionId,
      expiresAt: new Date(expiresAt).toISOString()
    });

    return {
      success: true,
      expiresAt,
      expiresIn: SESSION_TIMEOUT_MINUTES * 60
    };
  } catch (error) {
    if (error.name === 'ConditionalCheckFailedException') {
      return {
        success: false,
        reason: 'Session not found or inactive'
      };
    }
    throw error;
  }
}

/**
 * Invalidate session
 * Requirement 20.4: Immediately invalidate session on logout
 */
async function invalidateSession(sessionId) {
  try {
    await docClient.send(new UpdateCommand({
      TableName: SESSIONS_TABLE,
      Key: { session_id: sessionId },
      UpdateExpression: 'SET is_active = :false',
      ExpressionAttributeValues: {
        ':false': false
      },
      ConditionExpression: 'attribute_exists(session_id)'
    }));

    console.log('Session invalidated:', sessionId);

    return {
      success: true,
      message: 'Session invalidated successfully'
    };
  } catch (error) {
    if (error.name === 'ConditionalCheckFailedException') {
      return {
        success: false,
        reason: 'Session not found'
      };
    }
    throw error;
  }
}

/**
 * Lambda handler
 */
exports.handler = async (event) => {
  console.log('Session manager request:', JSON.stringify(event, null, 2));

  // Handle OPTIONS request for CORS
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: ''
    };
  }

  try {
    const path = event.path || event.resource;
    const method = event.httpMethod;
    const body = event.body ? JSON.parse(event.body) : {};

    // Extract user context from authorizer (if available)
    const userContext = event.requestContext?.authorizer || {};

    // Route handling
    if (path.includes('/sessions') && method === 'POST') {
      // Create session
      const { userId, userEmail, userGroups } = body;

      if (!userId) {
        return {
          statusCode: 400,
          headers: CORS_HEADERS,
          body: JSON.stringify({
            error: 'Bad Request',
            message: 'Missing userId in request body'
          })
        };
      }

      const result = await createSession(userId, userEmail, userGroups);

      return {
        statusCode: 201,
        headers: CORS_HEADERS,
        body: JSON.stringify(result)
      };
    }

    if (path.includes('/sessions/validate') && method === 'POST') {
      // Validate session
      const { sessionId } = body;

      if (!sessionId) {
        return {
          statusCode: 400,
          headers: CORS_HEADERS,
          body: JSON.stringify({
            error: 'Bad Request',
            message: 'Missing sessionId in request body'
          })
        };
      }

      const result = await validateSession(sessionId);

      if (!result.valid) {
        return {
          statusCode: 401,
          headers: CORS_HEADERS,
          body: JSON.stringify({
            valid: false,
            reason: result.reason
          })
        };
      }

      return {
        statusCode: 200,
        headers: CORS_HEADERS,
        body: JSON.stringify({
          valid: true,
          session: result.session
        })
      };
    }

    if (path.includes('/sessions/activity') && method === 'PUT') {
      // Update session activity
      const { sessionId } = body;

      if (!sessionId) {
        return {
          statusCode: 400,
          headers: CORS_HEADERS,
          body: JSON.stringify({
            error: 'Bad Request',
            message: 'Missing sessionId in request body'
          })
        };
      }

      const result = await updateSessionActivity(sessionId);

      if (!result.success) {
        return {
          statusCode: 404,
          headers: CORS_HEADERS,
          body: JSON.stringify({
            error: 'Not Found',
            message: result.reason
          })
        };
      }

      return {
        statusCode: 200,
        headers: CORS_HEADERS,
        body: JSON.stringify(result)
      };
    }

    if (path.includes('/sessions') && method === 'DELETE') {
      // Invalidate session (logout)
      const { sessionId } = body;

      if (!sessionId) {
        return {
          statusCode: 400,
          headers: CORS_HEADERS,
          body: JSON.stringify({
            error: 'Bad Request',
            message: 'Missing sessionId in request body'
          })
        };
      }

      const result = await invalidateSession(sessionId);

      if (!result.success) {
        return {
          statusCode: 404,
          headers: CORS_HEADERS,
          body: JSON.stringify({
            error: 'Not Found',
            message: result.reason
          })
        };
      }

      return {
        statusCode: 200,
        headers: CORS_HEADERS,
        body: JSON.stringify(result)
      };
    }

    // Unknown route
    return {
      statusCode: 404,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        error: 'Not Found',
        message: 'Unknown endpoint'
      })
    };

  } catch (error) {
    console.error('Session manager error:', error);

    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        error: 'Internal Server Error',
        message: error.message
      })
    };
  }
};
