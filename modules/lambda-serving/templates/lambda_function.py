import json
import boto3
import os
from typing import Dict, Any

def lambda_handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    AWS Lambda function for ML model serving
    
    Expected API Gateway event structure:
    {
        "pathParameters": {"model_name": "model-name"},
        "body": "{\"input_data\": [...]}",
        "headers": {...}
    }
    """
    
    try:
        # Extract model name from path parameters
        model_name = event.get('pathParameters', {}).get('model_name')
        if not model_name:
            return create_response(400, {"error": "Model name is required"})
        
        # Parse request body
        if event.get('body'):
            body = json.loads(event['body'])
        else:
            return create_response(400, {"error": "Request body is required"})
        
        input_data = body.get('input_data')
        if input_data is None:
            return create_response(400, {"error": "input_data is required in request body"})
        
        # Load model and make prediction
        prediction = predict_with_model(model_name, input_data)
        
        return create_response(200, {
            "model_name": model_name,
            "prediction": prediction,
            "status": "success"
        })
        
    except json.JSONDecodeError:
        return create_response(400, {"error": "Invalid JSON in request body"})
    except Exception as e:
        print(f"Error processing request: {str(e)}")
        return create_response(500, {"error": "Internal server error"})

def predict_with_model(model_name: str, input_data: Any) -> Any:
    """
    Load model from S3 and make prediction
    
    This is a template function - implement your specific model loading
    and prediction logic here.
    """
    
    # Example implementation - replace with your actual model logic
    s3_client = boto3.client('s3')
    project_name = os.environ.get('PROJECT_NAME', 'ellen-young-yt')
    environment = os.environ.get('ENVIRONMENT', 'dev')
    
    # Example: Load model artifacts from S3
    bucket_name = f"{project_name}-{environment}-artifacts"
    model_key = f"models/{model_name}/model.pkl"
    
    try:
        # This is a placeholder - implement your model loading logic
        # response = s3_client.get_object(Bucket=bucket_name, Key=model_key)
        # model_data = response['Body'].read()
        # model = pickle.loads(model_data)
        # prediction = model.predict(input_data)
        
        # For now, return a mock prediction
        prediction = {
            "result": "mock_prediction",
            "confidence": 0.95,
            "input_shape": len(input_data) if isinstance(input_data, list) else "unknown"
        }
        
        return prediction
        
    except Exception as e:
        print(f"Error loading model {model_name}: {str(e)}")
        raise Exception(f"Failed to load model {model_name}")

def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create properly formatted API Gateway response"""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "POST,OPTIONS"
        },
        "body": json.dumps(body)
    }