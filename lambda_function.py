import json

def lambda_handler(event, context):
    print("Hello, World!")
    print("Event details:", json.dumps(event, indent=2))
    return {
        'statusCode': 200,
        'body': json.dumps('Hello, World!')
    }