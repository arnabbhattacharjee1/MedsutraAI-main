"""
Unit Tests for ReportService Lambda
Task 4.7: Write unit tests for Lambda functions
"""

import json
import base64
import pytest
from unittest.mock import Mock, patch, MagicMock
from lambda_function import (
    validate_file,
    upload_to_s3,
    process_ocr,
    create_report_metadata,
    lambda_handler,
    MAX_FILE_SIZE
)


class TestFileValidation:
    """Test file validation logic"""
    
    def test_valid_pdf_file(self):
        """Test validation of valid PDF file"""
        is_valid, error, file_format = validate_file(
            'report.pdf',
            1024 * 1024,  # 1 MB
            'application/pdf'
        )
        assert is_valid is True
        assert error is None
        assert file_format == 'pdf'
    
    def test_valid_docx_file(self):
        """Test validation of valid DOCX file"""
        is_valid, error, file_format = validate_file(
            'report.docx',
            2 * 1024 * 1024,  # 2 MB
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        )
        assert is_valid is True
        assert error is None
        assert file_format == 'docx'
    
    def test_valid_image_files(self):
        """Test validation of valid image files"""
        for ext, content_type in [('jpg', 'image/jpeg'), ('jpeg', 'image/jpeg'), ('png', 'image/png')]:
            is_valid, error, file_format = validate_file(
                f'scan.{ext}',
                5 * 1024 * 1024,  # 5 MB
                content_type
            )
            assert is_valid is True
            assert error is None
            assert file_format in ['jpg', 'jpeg', 'png']
    
    def test_valid_dicom_file(self):
        """Test validation of valid DICOM file"""
        is_valid, error, file_format = validate_file(
            'imaging.dicom',
            10 * 1024 * 1024,  # 10 MB
            'application/dicom'
        )
        assert is_valid is True
        assert error is None
        assert file_format == 'dicom'
    
    def test_file_too_large(self):
        """Test rejection of oversized file"""
        is_valid, error, file_format = validate_file(
            'large.pdf',
            51 * 1024 * 1024,  # 51 MB (exceeds 50 MB limit)
            'application/pdf'
        )
        assert is_valid is False
        assert 'exceeds maximum limit' in error
        assert file_format is None
    
    def test_file_zero_size(self):
        """Test rejection of zero-size file"""
        is_valid, error, file_format = validate_file(
            'empty.pdf',
            0,
            'application/pdf'
        )
        assert is_valid is False
        assert 'must be greater than 0' in error
        assert file_format is None
    
    def test_unsupported_format(self):
        """Test rejection of unsupported file format"""
        is_valid, error, file_format = validate_file(
            'document.txt',
            1024,
            'text/plain'
        )
        assert is_valid is False
        assert 'Unsupported file format' in error
        assert file_format is None
    
    def test_no_file_extension(self):
        """Test rejection of file without extension"""
        is_valid, error, file_format = validate_file(
            'noextension',
            1024,
            'application/octet-stream'
        )
        assert is_valid is False
        assert 'Unsupported file format' in error


class TestS3Upload:
    """Test S3 upload functionality"""
    
    @patch('lambda_function.s3_client')
    def test_successful_upload(self, mock_s3):
        """Test successful S3 upload with KMS encryption"""
        mock_s3.put_object.return_value = {
            'VersionId': 'version-123'
        }
        
        file_content = b'test file content'
        file_name = 'test.pdf'
        content_type = 'application/pdf'
        patient_id = '123e4567-e89b-12d3-a456-426614174000'
        
        s3_key, s3_version_id = upload_to_s3(
            file_content,
            file_name,
            content_type,
            patient_id
        )
        
        assert s3_key.startswith(f'medical-reports/{patient_id}/')
        assert s3_key.endswith(f'_{file_name}')
        assert s3_version_id == 'version-123'
        
        # Verify S3 put_object was called with correct parameters
        mock_s3.put_object.assert_called_once()
        call_args = mock_s3.put_object.call_args[1]
        assert call_args['Body'] == file_content
        assert call_args['ContentType'] == content_type
        assert call_args['ServerSideEncryption'] == 'aws:kms'
        assert 'SSEKMSKeyId' in call_args


class TestOCRProcessing:
    """Test OCR processing with Textract"""
    
    @patch('lambda_function.textract_client')
    def test_successful_ocr_processing(self, mock_textract):
        """Test successful OCR text extraction"""
        mock_textract.detect_document_text.return_value = {
            'Blocks': [
                {
                    'BlockType': 'LINE',
                    'Text': 'Patient Name: John Doe',
                    'Confidence': 99.5
                },
                {
                    'BlockType': 'LINE',
                    'Text': 'Date: 2024-01-15',
                    'Confidence': 98.2
                },
                {
                    'BlockType': 'WORD',
                    'Text': 'Diagnosis',
                    'Confidence': 97.0
                }
            ]
        }
        
        s3_key = 'medical-reports/patient-123/2024/01/15/test.pdf'
        ocr_text, ocr_confidence = process_ocr(s3_key, 'pdf')
        
        assert ocr_text is not None
        assert 'Patient Name: John Doe' in ocr_text
        assert 'Date: 2024-01-15' in ocr_text
        assert ocr_confidence > 95.0
        
        mock_textract.detect_document_text.assert_called_once()
    
    @patch('lambda_function.textract_client')
    def test_ocr_no_text_found(self, mock_textract):
        """Test OCR when no text is found"""
        mock_textract.detect_document_text.return_value = {
            'Blocks': []
        }
        
        s3_key = 'medical-reports/patient-123/2024/01/15/blank.pdf'
        ocr_text, ocr_confidence = process_ocr(s3_key, 'pdf')
        
        assert ocr_text is None
        assert ocr_confidence is None
    
    def test_ocr_unsupported_format(self):
        """Test OCR skipped for unsupported formats"""
        s3_key = 'medical-reports/patient-123/2024/01/15/report.docx'
        ocr_text, ocr_confidence = process_ocr(s3_key, 'docx')
        
        assert ocr_text is None
        assert ocr_confidence is None
    
    @patch('lambda_function.textract_client')
    def test_ocr_processing_error(self, mock_textract):
        """Test OCR error handling"""
        mock_textract.detect_document_text.side_effect = Exception('Textract error')
        
        s3_key = 'medical-reports/patient-123/2024/01/15/test.pdf'
        ocr_text, ocr_confidence = process_ocr(s3_key, 'pdf')
        
        assert ocr_text is None
        assert ocr_confidence is None


class TestDatabaseOperations:
    """Test database operations"""
    
    @patch('lambda_function.psycopg2')
    def test_create_report_metadata_success(self, mock_psycopg2):
        """Test successful report metadata creation"""
        mock_connection = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = ['report-uuid-123']
        mock_connection.cursor.return_value = mock_cursor
        mock_psycopg2.connect.return_value = mock_connection
        
        report_id = create_report_metadata(
            patient_id='patient-123',
            report_type='lab',
            report_title='Blood Test Results',
            report_description='Complete blood count',
            s3_key='medical-reports/patient-123/2024/01/15/test.pdf',
            s3_version_id='version-123',
            file_format='pdf',
            file_size=1024000,
            uploaded_by='user-123',
            ocr_text='Test results...',
            ocr_confidence=95.5,
            report_date='2024-01-15'
        )
        
        assert report_id == 'report-uuid-123'
        mock_cursor.execute.assert_called_once()
        mock_connection.commit.assert_called_once()
        mock_cursor.close.assert_called_once()
        mock_connection.close.assert_called_once()
    
    @patch('lambda_function.psycopg2')
    def test_create_report_metadata_error(self, mock_psycopg2):
        """Test database error handling"""
        mock_connection = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.execute.side_effect = Exception('Database error')
        mock_connection.cursor.return_value = mock_cursor
        mock_psycopg2.connect.return_value = mock_connection
        
        with pytest.raises(Exception):
            create_report_metadata(
                patient_id='patient-123',
                report_type='lab',
                report_title='Test',
                report_description='Test',
                s3_key='test.pdf',
                s3_version_id='v1',
                file_format='pdf',
                file_size=1024,
                uploaded_by='user-123',
                ocr_text=None,
                ocr_confidence=None,
                report_date=None
            )
        
        mock_connection.rollback.assert_called_once()


class TestLambdaHandler:
    """Test Lambda handler end-to-end"""
    
    @patch('lambda_function.create_report_metadata')
    @patch('lambda_function.process_ocr')
    @patch('lambda_function.upload_to_s3')
    def test_successful_upload(self, mock_upload, mock_ocr, mock_create_metadata):
        """Test successful file upload flow"""
        mock_upload.return_value = ('s3-key-123', 'version-123')
        mock_ocr.return_value = ('Extracted text', 95.5)
        mock_create_metadata.return_value = 'report-uuid-123'
        
        file_content = b'test pdf content'
        file_content_base64 = base64.b64encode(file_content).decode('utf-8')
        
        event = {
            'requestContext': {
                'authorizer': {
                    'userId': 'user-123',
                    'groups': '["Doctor"]'
                }
            },
            'body': json.dumps({
                'patientId': 'patient-123',
                'fileName': 'test.pdf',
                'fileContent': file_content_base64,
                'contentType': 'application/pdf',
                'reportType': 'lab',
                'reportTitle': 'Blood Test',
                'reportDescription': 'CBC results'
            })
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 200
        body = json.loads(response['body'])
        assert body['reportId'] == 'report-uuid-123'
        assert body['patientId'] == 'patient-123'
        assert body['ocrProcessed'] is True
        
        mock_upload.assert_called_once()
        mock_ocr.assert_called_once()
        mock_create_metadata.assert_called_once()
    
    def test_missing_patient_id(self):
        """Test error when patientId is missing"""
        event = {
            'requestContext': {
                'authorizer': {
                    'userId': 'user-123',
                    'groups': '[]'
                }
            },
            'body': json.dumps({
                'fileName': 'test.pdf',
                'fileContent': 'base64content'
            })
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'patientId is required' in body['message']
    
    def test_missing_file_name(self):
        """Test error when fileName is missing"""
        event = {
            'requestContext': {
                'authorizer': {
                    'userId': 'user-123',
                    'groups': '[]'
                }
            },
            'body': json.dumps({
                'patientId': 'patient-123',
                'fileContent': 'base64content'
            })
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'fileName is required' in body['message']
    
    def test_invalid_base64_content(self):
        """Test error when fileContent is not valid base64"""
        event = {
            'requestContext': {
                'authorizer': {
                    'userId': 'user-123',
                    'groups': '[]'
                }
            },
            'body': json.dumps({
                'patientId': 'patient-123',
                'fileName': 'test.pdf',
                'fileContent': 'not-valid-base64!!!'
            })
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'base64 encoded' in body['message']
    
    def test_file_too_large(self):
        """Test error when file exceeds size limit"""
        # Create a file larger than 50MB
        large_content = b'x' * (51 * 1024 * 1024)
        large_content_base64 = base64.b64encode(large_content).decode('utf-8')
        
        event = {
            'requestContext': {
                'authorizer': {
                    'userId': 'user-123',
                    'groups': '[]'
                }
            },
            'body': json.dumps({
                'patientId': 'patient-123',
                'fileName': 'large.pdf',
                'fileContent': large_content_base64,
                'contentType': 'application/pdf'
            })
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'exceeds maximum limit' in body['message']
    
    def test_unsupported_file_format(self):
        """Test error when file format is unsupported"""
        file_content = b'test content'
        file_content_base64 = base64.b64encode(file_content).decode('utf-8')
        
        event = {
            'requestContext': {
                'authorizer': {
                    'userId': 'user-123',
                    'groups': '[]'
                }
            },
            'body': json.dumps({
                'patientId': 'patient-123',
                'fileName': 'document.txt',
                'fileContent': file_content_base64,
                'contentType': 'text/plain'
            })
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'Unsupported file format' in body['message']


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
