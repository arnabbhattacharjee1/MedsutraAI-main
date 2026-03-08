"""
ReportService Lambda Function
Task 4.4: Implement ReportService Lambda (Python 3.11)

Handles file upload, validation, S3 storage, and OCR processing
Integrates with Amazon Textract for scanned image OCR

Requirements:
- 4.1: Accept PDF format files
- 4.2: Accept DOCX format files
- 4.3: Accept scanned image files
- 4.4: Accept DICOM format files
- 4.6: Apply OCR to extract text from scanned images
- 18.1: Validate file format
- 18.2: Validate file size (max 50MB)
- 18.3: Reject unsupported formats
- 18.4: Reject oversized files
- 22.2: Process files within 5 seconds for <10MB files
"""

import json
import os
import base64
import uuid
import boto3
import psycopg2
from datetime import datetime
from typing import Dict, Any, Tuple, Optional

# Environment variables
DB_HOST = os.environ['DB_HOST']
DB_PORT = os.environ.get('DB_PORT', '5432')
DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
DB_SSL_ENABLED = os.environ.get('DB_SSL_ENABLED', 'true').lower() == 'true'

S3_BUCKET = os.environ['S3_BUCKET']
KMS_KEY_ID = os.environ['KMS_KEY_ID']

# AWS clients
s3_client = boto3.client('s3')
textract_client = boto3.client('textract')

# Constants
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB
SUPPORTED_FORMATS = {
    'pdf': 'application/pdf',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'dicom': 'application/dicom'
}

IMAGE_FORMATS = ['jpg', 'jpeg', 'png']
OCR_FORMATS = IMAGE_FORMATS + ['pdf']


def validate_file(file_name: str, file_size: int, content_type: str) -> Tuple[bool, Optional[str], Optional[str]]:
    """
    Validate file format and size
    
    Returns:
        Tuple of (is_valid, error_message, file_format)
    """
    # Validate file size
    if file_size > MAX_FILE_SIZE:
        return False, f'File size exceeds maximum limit of 50MB. Received: {file_size / (1024 * 1024):.2f}MB', None
    
    if file_size <= 0:
        return False, 'File size must be greater than 0', None
    
    # Extract file extension
    file_extension = file_name.lower().split('.')[-1] if '.' in file_name else ''
    
    # Validate file format
    if file_extension not in SUPPORTED_FORMATS:
        return False, f'Unsupported file format: {file_extension}. Supported formats: {", ".join(SUPPORTED_FORMATS.keys())}', None
    
    # Validate content type matches extension
    expected_content_type = SUPPORTED_FORMATS[file_extension]
    if content_type and content_type != expected_content_type:
        print(f'Warning: Content-Type mismatch. Expected: {expected_content_type}, Received: {content_type}')
    
    return True, None, file_extension


def upload_to_s3(file_content: bytes, file_name: str, content_type: str, patient_id: str) -> Tuple[str, str]:
    """
    Upload file to S3 with KMS encryption
    
    Returns:
        Tuple of (s3_key, s3_version_id)
    """
    # Generate unique S3 key
    timestamp = datetime.utcnow().strftime('%Y/%m/%d')
    unique_id = str(uuid.uuid4())
    s3_key = f'medical-reports/{patient_id}/{timestamp}/{unique_id}_{file_name}'
    
    # Upload to S3 with KMS encryption
    response = s3_client.put_object(
        Bucket=S3_BUCKET,
        Key=s3_key,
        Body=file_content,
        ContentType=content_type,
        ServerSideEncryption='aws:kms',
        SSEKMSKeyId=KMS_KEY_ID,
        Metadata={
            'patient-id': patient_id,
            'upload-timestamp': datetime.utcnow().isoformat(),
            'original-filename': file_name
        }
    )
    
    s3_version_id = response.get('VersionId', '')
    
    print(f'File uploaded to S3: s3://{S3_BUCKET}/{s3_key}')
    return s3_key, s3_version_id


def process_ocr(s3_key: str, file_format: str) -> Tuple[Optional[str], Optional[float]]:
    """
    Process OCR using Amazon Textract for images and PDFs
    
    Returns:
        Tuple of (extracted_text, confidence_score)
    """
    if file_format not in OCR_FORMATS:
        return None, None
    
    try:
        print(f'Starting OCR processing for: {s3_key}')
        
        # Call Textract
        response = textract_client.detect_document_text(
            Document={
                'S3Object': {
                    'Bucket': S3_BUCKET,
                    'Name': s3_key
                }
            }
        )
        
        # Extract text and calculate average confidence
        extracted_text = []
        confidences = []
        
        for block in response.get('Blocks', []):
            if block['BlockType'] == 'LINE':
                text = block.get('Text', '')
                confidence = block.get('Confidence', 0)
                
                if text:
                    extracted_text.append(text)
                    confidences.append(confidence)
        
        if not extracted_text:
            print('No text extracted from document')
            return None, None
        
        full_text = '\n'.join(extracted_text)
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0
        
        print(f'OCR completed. Extracted {len(extracted_text)} lines with avg confidence: {avg_confidence:.2f}%')
        return full_text, avg_confidence
        
    except Exception as e:
        print(f'OCR processing failed: {str(e)}')
        return None, None


def create_report_metadata(
    patient_id: str,
    report_type: str,
    report_title: str,
    report_description: str,
    s3_key: str,
    s3_version_id: str,
    file_format: str,
    file_size: int,
    uploaded_by: str,
    ocr_text: Optional[str],
    ocr_confidence: Optional[float],
    report_date: Optional[str]
) -> str:
    """
    Create report metadata in RDS
    
    Returns:
        report_id (UUID)
    """
    connection = None
    cursor = None
    
    try:
        # Connect to database
        connection = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            sslmode='require' if DB_SSL_ENABLED else 'prefer',
            connect_timeout=5
        )
        cursor = connection.cursor()
        
        print('Database connected successfully')
        
        # Insert report metadata
        query = """
            INSERT INTO reports (
                patient_id,
                report_type,
                report_title,
                report_description,
                s3_bucket,
                s3_key,
                s3_version_id,
                file_format,
                file_size_bytes,
                report_date,
                uploaded_by,
                ocr_processed,
                ocr_text,
                ocr_confidence
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            ) RETURNING report_id
        """
        
        params = (
            patient_id,
            report_type,
            report_title,
            report_description,
            S3_BUCKET,
            s3_key,
            s3_version_id,
            file_format,
            file_size,
            report_date,
            uploaded_by,
            ocr_text is not None,
            ocr_text,
            ocr_confidence
        )
        
        cursor.execute(query, params)
        report_id = cursor.fetchone()[0]
        connection.commit()
        
        print(f'Report metadata created: {report_id}')
        return str(report_id)
        
    except Exception as e:
        if connection:
            connection.rollback()
        print(f'Database error: {str(e)}')
        raise
        
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()
        print('Database connection closed')


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for report upload
    """
    print(f'Event: {json.dumps(event)}')
    
    try:
        # Extract user context from authorizer
        user_id = event.get('requestContext', {}).get('authorizer', {}).get('userId', 'unknown')
        user_groups = event.get('requestContext', {}).get('authorizer', {}).get('groups', '[]')
        user_groups = json.loads(user_groups) if isinstance(user_groups, str) else user_groups
        
        print(f'User context: userId={user_id}, groups={user_groups}')
        
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        
        # Extract required fields
        patient_id = body.get('patientId')
        file_name = body.get('fileName')
        file_content_base64 = body.get('fileContent')
        content_type = body.get('contentType', '')
        report_type = body.get('reportType', 'other')
        report_title = body.get('reportTitle', file_name)
        report_description = body.get('reportDescription', '')
        report_date = body.get('reportDate')  # Optional: actual date of the medical report
        
        # Validate required fields
        if not patient_id:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required field',
                    'message': 'patientId is required'
                })
            }
        
        if not file_name:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required field',
                    'message': 'fileName is required'
                })
            }
        
        if not file_content_base64:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required field',
                    'message': 'fileContent is required'
                })
            }
        
        # Decode file content
        try:
            file_content = base64.b64decode(file_content_base64)
        except Exception as e:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Invalid file content',
                    'message': 'fileContent must be base64 encoded'
                })
            }
        
        file_size = len(file_content)
        
        # Validate file
        is_valid, error_message, file_format = validate_file(file_name, file_size, content_type)
        if not is_valid:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'File validation failed',
                    'message': error_message
                })
            }
        
        # Upload to S3
        s3_key, s3_version_id = upload_to_s3(file_content, file_name, content_type, patient_id)
        
        # Process OCR if applicable
        ocr_text, ocr_confidence = process_ocr(s3_key, file_format)
        
        # Create report metadata in RDS
        report_id = create_report_metadata(
            patient_id=patient_id,
            report_type=report_type,
            report_title=report_title,
            report_description=report_description,
            s3_key=s3_key,
            s3_version_id=s3_version_id,
            file_format=file_format,
            file_size=file_size,
            uploaded_by=user_id,
            ocr_text=ocr_text,
            ocr_confidence=ocr_confidence,
            report_date=report_date
        )
        
        # Success response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Report uploaded successfully',
                'reportId': report_id,
                'patientId': patient_id,
                'fileName': file_name,
                'fileSize': file_size,
                'fileFormat': file_format,
                's3Key': s3_key,
                'ocrProcessed': ocr_text is not None,
                'ocrConfidence': ocr_confidence
            })
        }
        
    except Exception as e:
        print(f'Handler error: {str(e)}')
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error',
                'message': 'Failed to process report upload',
                'details': str(e) if os.environ.get('NODE_ENV') == 'development' else None
            })
        }
