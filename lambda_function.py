import json

def handler(event, context):
    """
    A simple ETL Lambda to test the CodePipeline deployment.
    Extracts input, Transforms it to uppercase, and Loads a response.
    """
    # Extract
    input_text = event.get('text', 'default text')
    
    # Transform
    transformed_text = input_text.upper()

    # Load (return output)
    return {
        'statusCode': 200,
        'body': json.dumps({
            'original': input_text,
            'transformed': transformed_text
        })
    }
