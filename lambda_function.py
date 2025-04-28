import json

def lambda_handler(event, context):
    # Simple ETL simulation: Extract, Transform, Load
    print("Extracting event...")
    extracted_data = event.get("data", {})

    print("Transforming data...")
    transformed_data = {k: str(v).upper() for k, v in extracted_data.items()}

    print("Loading data...")
    result = {
        "message": "ETL operation successful",
        "transformed_data": transformed_data
    }

    return {
        "statusCode": 200,
        "body": json.dumps(result)
    }
