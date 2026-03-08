"""
AWS Lambda Function for MedSutra AI Chat API
Python 3.13
Handles chat requests and integrates with Amazon Bedrock Nova 2 Lite model
"""

import json
import boto3
import os
from datetime import datetime
from typing import Dict, List, Any

# Initialize AWS clients
bedrock_runtime = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
s3_client = boto3.client('s3')

# Configuration
BEDROCK_MODEL_ID = "us.amazon.nova-lite-v1:0"  # Nova 2 Lite model
S3_BUCKET = os.environ.get('CONVERSATION_BUCKET', 'medsutra-conversations')
MAX_TOKENS = 2000
TEMPERATURE = 0.7

# System prompt for medical AI assistant
SYSTEM_PROMPT = """You are MedSutra AI, an expert medical AI assistant specializing in oncology and cancer detection for the Indian healthcare system. 

Your role:
- Provide accurate, evidence-based information about cancer detection, diagnosis, and treatment
- Explain medical concepts in clear, understandable language
- Support both healthcare providers and patients
- Be culturally sensitive to Indian healthcare context
- Always emphasize that AI is a support tool and human medical professionals make final decisions

Guidelines:
- Be professional, compassionate, and supportive
- Cite medical evidence when possible
- Acknowledge limitations and uncertainties
- Recommend consulting healthcare professionals for personalized advice
- Use simple language for patients, technical language for healthcare providers when appropriate

IMPORTANT: You are an AI assistant, not a replacement for medical professionals. Always recommend consulting qualified healthcare providers for diagnosis and treatment decisions."""


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler function
    
    Args:
        event: API Gateway event containing the request
        context: Lambda context object
        
    Returns:
        API Gateway response with AI-generated response
    """
    
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        user_message = body.get('message', '')
        conversation_history = body.get('conversation_history', [])
        
        if not user_message:
            return create_response(400, {'error': 'Message is required'})
        
        # Generate conversation ID
        conversation_id = body.get('conversation_id', generate_conversation_id())
        
        # Prepare messages for Bedrock
        messages = prepare_messages(conversation_history, user_message)
        
        # Call Amazon Bedrock Nova 2 Lite
        ai_response = invoke_bedrock(messages)
        
        # Save conversation to S3
        save_conversation_to_s3(conversation_id, user_message, ai_response, conversation_history)
        
        # Return response
        return create_response(200, {
            'response': ai_response,
            'conversation_id': conversation_id,
            'timestamp': datetime.utcnow().isoformat(),
            'model': BEDROCK_MODEL_ID
        })
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })


def prepare_messages(conversation_history: List[Dict], current_message: str) -> List[Dict]:
    """
    Prepare messages in the format required by Bedrock
    
    Args:
        conversation_history: Previous conversation messages
        current_message: Current user message
        
    Returns:
        List of formatted messages
    """
    messages = []
    
    # Add conversation history (limit to last 10 messages for context)
    for msg in conversation_history[-10:]:
        messages.append({
            "role": msg.get('role', 'user'),
            "content": [{"text": msg.get('content', '')}]
        })
    
    # Add current message
    messages.append({
        "role": "user",
        "content": [{"text": current_message}]
    })
    
    return messages


def invoke_bedrock(messages: List[Dict]) -> str:
    """
    Invoke Amazon Bedrock Nova 2 Lite model
    
    Args:
        messages: Formatted conversation messages
        
    Returns:
        AI-generated response text
    """
    
    try:
        # Prepare request for Bedrock Converse API
        request_body = {
            "modelId": BEDROCK_MODEL_ID,
            "messages": messages,
            "system": [{"text": SYSTEM_PROMPT}],
            "inferenceConfig": {
                "maxTokens": MAX_TOKENS,
                "temperature": TEMPERATURE,
                "topP": 0.9
            }
        }
        
        # Invoke Bedrock
        response = bedrock_runtime.converse(**request_body)
        
        # Extract response text
        output_message = response['output']['message']
        response_text = output_message['content'][0]['text']
        
        return response_text
        
    except Exception as e:
        print(f"Bedrock invocation error: {str(e)}")
        raise Exception(f"Failed to generate AI response: {str(e)}")


def save_conversation_to_s3(conversation_id: str, user_message: str, 
                            ai_response: str, history: List[Dict]) -> None:
    """
    Save conversation to S3 as JSON
    
    Args:
        conversation_id: Unique conversation identifier
        user_message: User's message
        ai_response: AI's response
        history: Previous conversation history
    """
    
    try:
        # Prepare conversation data
        conversation_data = {
            'conversation_id': conversation_id,
            'timestamp': datetime.utcnow().isoformat(),
            'messages': history + [
                {
                    'role': 'user',
                    'content': user_message,
                    'timestamp': datetime.utcnow().isoformat()
                },
                {
                    'role': 'assistant',
                    'content': ai_response,
                    'timestamp': datetime.utcnow().isoformat()
                }
            ],
            'model': BEDROCK_MODEL_ID
        }
        
        # Save to S3
        s3_key = f"conversations/{conversation_id}.json"
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=json.dumps(conversation_data, indent=2),
            ContentType='application/json'
        )
        
        print(f"Conversation saved to S3: {s3_key}")
        
    except Exception as e:
        print(f"Error saving to S3: {str(e)}")
        # Don't fail the request if S3 save fails


def generate_conversation_id() -> str:
    """Generate a unique conversation ID"""
    from uuid import uuid4
    return f"conv_{datetime.utcnow().strftime('%Y%m%d')}_{uuid4().hex[:12]}"


def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create API Gateway response
    
    Args:
        status_code: HTTP status code
        body: Response body dictionary
        
    Returns:
        Formatted API Gateway response
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',  # Configure for your domain in production
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'POST, OPTIONS'
        },
        'body': json.dumps(body)
    }
