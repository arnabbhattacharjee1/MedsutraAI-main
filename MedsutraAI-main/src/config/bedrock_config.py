"""
Amazon Bedrock Configuration Module

Task 7.3: Configure Amazon Bedrock access
Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8

This module provides configuration and utilities for accessing Amazon Bedrock
foundation models for clinical summarization, translation, and embeddings.
"""

import json
import logging
import os
from dataclasses import dataclass
from typing import Dict, Optional, Any
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


@dataclass
class ModelConfig:
    """Configuration for a specific Bedrock model"""
    model_id: str
    max_tokens: Optional[int] = None
    temperature: Optional[float] = None
    top_p: Optional[float] = None
    dimensions: Optional[int] = None  # For embedding models


@dataclass
class BedrockConfig:
    """Complete Bedrock configuration"""
    clinical_summarization: ModelConfig
    explainability: ModelConfig
    translation: ModelConfig
    embeddings: ModelConfig
    region: str
    log_group: str
    requests_per_minute: int
    tokens_per_minute: int


class BedrockConfigManager:
    """Manages Amazon Bedrock configuration and client initialization"""
    
    def __init__(
        self,
        region: Optional[str] = None,
        ssm_parameter_name: Optional[str] = None
    ):
        """
        Initialize Bedrock configuration manager
        
        Args:
            region: AWS region (defaults to environment variable or us-east-1)
            ssm_parameter_name: SSM parameter containing configuration
        """
        self.region = region or os.getenv('AWS_REGION', 'us-east-1')
        self.ssm_parameter_name = ssm_parameter_name or self._get_default_parameter_name()
        
        self._config: Optional[BedrockConfig] = None
        self._bedrock_runtime_client: Optional[Any] = None
        self._bedrock_client: Optional[Any] = None
        
    def _get_default_parameter_name(self) -> str:
        """Get default SSM parameter name from environment"""
        project_name = os.getenv('PROJECT_NAME', 'cancer-detection-platform')
        environment = os.getenv('ENVIRONMENT', 'mvp')
        return f"/{project_name}/{environment}/bedrock/config"
    
    def load_config(self) -> BedrockConfig:
        """
        Load Bedrock configuration from SSM Parameter Store
        
        Returns:
            BedrockConfig object with all model configurations
            
        Raises:
            ClientError: If SSM parameter cannot be retrieved
            ValueError: If configuration is invalid
        """
        if self._config:
            return self._config
        
        try:
            ssm_client = boto3.client('ssm', region_name=self.region)
            response = ssm_client.get_parameter(
                Name=self.ssm_parameter_name,
                WithDecryption=False
            )
            
            config_data = json.loads(response['Parameter']['Value'])
            
            # Parse model configurations
            models = config_data['models']
            
            self._config = BedrockConfig(
                clinical_summarization=ModelConfig(
                    model_id=models['clinical_summarization']['model_id'],
                    max_tokens=models['clinical_summarization']['max_tokens'],
                    temperature=models['clinical_summarization']['temperature'],
                    top_p=models['clinical_summarization']['top_p']
                ),
                explainability=ModelConfig(
                    model_id=models['explainability']['model_id'],
                    max_tokens=models['explainability']['max_tokens'],
                    temperature=models['explainability']['temperature'],
                    top_p=models['explainability']['top_p']
                ),
                translation=ModelConfig(
                    model_id=models['translation']['model_id'],
                    max_tokens=models['translation']['max_tokens'],
                    temperature=models['translation']['temperature'],
                    top_p=models['translation']['top_p']
                ),
                embeddings=ModelConfig(
                    model_id=models['embeddings']['model_id'],
                    dimensions=models['embeddings']['dimensions']
                ),
                region=config_data['region'],
                log_group=config_data['logging']['log_group'],
                requests_per_minute=config_data['rate_limits']['requests_per_minute'],
                tokens_per_minute=config_data['rate_limits']['tokens_per_minute']
            )
            
            logger.info(f"Loaded Bedrock configuration from {self.ssm_parameter_name}")
            return self._config
            
        except ClientError as e:
            logger.error(f"Failed to load Bedrock configuration: {e}")
            raise
        except (KeyError, json.JSONDecodeError) as e:
            logger.error(f"Invalid Bedrock configuration format: {e}")
            raise ValueError(f"Invalid configuration format: {e}")
    
    def get_runtime_client(self):
        """
        Get or create Bedrock Runtime client for model invocation
        
        Returns:
            boto3 bedrock-runtime client
        """
        if not self._bedrock_runtime_client:
            self._bedrock_runtime_client = boto3.client(
                'bedrock-runtime',
                region_name=self.region
            )
            logger.info(f"Initialized Bedrock Runtime client for region {self.region}")
        
        return self._bedrock_runtime_client
    
    def get_bedrock_client(self):
        """
        Get or create Bedrock client for model management
        
        Returns:
            boto3 bedrock client
        """
        if not self._bedrock_client:
            self._bedrock_client = boto3.client(
                'bedrock',
                region_name=self.region
            )
            logger.info(f"Initialized Bedrock client for region {self.region}")
        
        return self._bedrock_client
    
    def invoke_claude(
        self,
        prompt: str,
        model_type: str = 'clinical_summarization',
        system_prompt: Optional[str] = None,
        **kwargs
    ) -> str:
        """
        Invoke Claude model with given prompt
        
        Args:
            prompt: User prompt/question
            model_type: Type of model config to use (clinical_summarization, explainability, translation)
            system_prompt: Optional system prompt
            **kwargs: Additional parameters to override config
            
        Returns:
            Model response text
            
        Raises:
            ValueError: If model_type is invalid
            ClientError: If invocation fails
        """
        config = self.load_config()
        
        # Get model config based on type
        model_configs = {
            'clinical_summarization': config.clinical_summarization,
            'explainability': config.explainability,
            'translation': config.translation
        }
        
        if model_type not in model_configs:
            raise ValueError(f"Invalid model_type: {model_type}")
        
        model_config = model_configs[model_type]
        
        # Build request body
        messages = [{"role": "user", "content": prompt}]
        
        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": kwargs.get('max_tokens', model_config.max_tokens),
            "temperature": kwargs.get('temperature', model_config.temperature),
            "top_p": kwargs.get('top_p', model_config.top_p),
            "messages": messages
        }
        
        if system_prompt:
            body["system"] = system_prompt
        
        try:
            client = self.get_runtime_client()
            response = client.invoke_model(
                modelId=model_config.model_id,
                body=json.dumps(body)
            )
            
            response_body = json.loads(response['body'].read())
            return response_body['content'][0]['text']
            
        except ClientError as e:
            logger.error(f"Failed to invoke Claude model: {e}")
            raise
    
    def generate_embeddings(self, text: str) -> list:
        """
        Generate embeddings using Titan Embeddings model
        
        Args:
            text: Text to generate embeddings for
            
        Returns:
            List of embedding values (1024-dimensional vector)
            
        Raises:
            ClientError: If invocation fails
        """
        config = self.load_config()
        
        body = json.dumps({
            "inputText": text
        })
        
        try:
            client = self.get_runtime_client()
            response = client.invoke_model(
                modelId=config.embeddings.model_id,
                body=body
            )
            
            response_body = json.loads(response['body'].read())
            return response_body['embedding']
            
        except ClientError as e:
            logger.error(f"Failed to generate embeddings: {e}")
            raise
    
    def list_available_models(self) -> list:
        """
        List all available foundation models
        
        Returns:
            List of model summaries
        """
        try:
            client = self.get_bedrock_client()
            response = client.list_foundation_models()
            return response['modelSummaries']
        except ClientError as e:
            logger.error(f"Failed to list models: {e}")
            raise
    
    def get_model_info(self, model_id: str) -> Dict[str, Any]:
        """
        Get detailed information about a specific model
        
        Args:
            model_id: Model identifier
            
        Returns:
            Model details dictionary
        """
        try:
            client = self.get_bedrock_client()
            response = client.get_foundation_model(modelIdentifier=model_id)
            return response['modelDetails']
        except ClientError as e:
            logger.error(f"Failed to get model info: {e}")
            raise


# Singleton instance for easy access
_bedrock_manager: Optional[BedrockConfigManager] = None


def get_bedrock_manager() -> BedrockConfigManager:
    """
    Get singleton instance of BedrockConfigManager
    
    Returns:
        BedrockConfigManager instance
    """
    global _bedrock_manager
    if _bedrock_manager is None:
        _bedrock_manager = BedrockConfigManager()
    return _bedrock_manager


# Convenience functions
def invoke_clinical_summarization(prompt: str, system_prompt: Optional[str] = None) -> str:
    """Invoke Claude for clinical summarization"""
    manager = get_bedrock_manager()
    return manager.invoke_claude(prompt, 'clinical_summarization', system_prompt)


def invoke_explainability(prompt: str, system_prompt: Optional[str] = None) -> str:
    """Invoke Claude for explainability"""
    manager = get_bedrock_manager()
    return manager.invoke_claude(prompt, 'explainability', system_prompt)


def invoke_translation(prompt: str, system_prompt: Optional[str] = None) -> str:
    """Invoke Claude for translation"""
    manager = get_bedrock_manager()
    return manager.invoke_claude(prompt, 'translation', system_prompt)


def generate_embeddings(text: str) -> list:
    """Generate embeddings using Titan"""
    manager = get_bedrock_manager()
    return manager.generate_embeddings(text)
