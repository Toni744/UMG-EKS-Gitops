#!/usr/bin/env python3
"""
Example: Access AWS SSM Parameter Store from the umgapi app

The service account has IRSA binding, so no credentials are needed.
AWS SDK automatically uses the pod's IAM role.
"""

import boto3
from fastapi import FastAPI

app = FastAPI()

# Initialize SSM client
ssm = boto3.client('ssm', region_name='us-east-1')


def get_secret(param_name: str, decrypt: bool = True) -> str:
    """
    Retrieve a secret from SSM Parameter Store
    
    Args:
        param_name: Full parameter name (e.g., '/umgapi/db_password')
        decrypt: Whether to decrypt SecureString parameters
    
    Returns:
        Parameter value
    """
    try:
        response = ssm.get_parameter(
            Name=param_name,
            WithDecryption=decrypt
        )
        return response['Parameter']['Value']
    except ssm.exceptions.ParameterNotFound:
        raise ValueError(f"Parameter {param_name} not found")


# Load secrets at startup
try:
    DB_PASSWORD = get_secret('/umgapi/db_password')
    API_KEY = get_secret('/umgapi/api_key')
    print("Loaded secrets from SSM Parameter Store")
except Exception as e:
    print(f" Warning: Could not load secrets: {e}")
    DB_PASSWORD = "default_password"
    API_KEY = "default_key"


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.get("/api/test")
def test_api():
    # Use your secrets
    return {
        "message": "Using secrets from SSM!",
        "has_db_password": bool(DB_PASSWORD),
        "has_api_key": bool(API_KEY)
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
