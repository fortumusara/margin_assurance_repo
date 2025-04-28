/my-lambda-project
│
├── /src                      # All Lambda function code here
│   ├── handler.py            # Main Lambda handler file
│   ├── utils.py              # Utility functions
│   └── __init__.py
│
├── /deploy                   # Deployment-related files
│   ├── buildspec.yml         # The buildspec.yml file (this is what CodeBuild uses)
│   ├── appspec.yml           # CodeDeploy application configuration
│   ├── create-deployment.json # Script for triggering CodeDeploy
│   └── lambda-package.zip    # Generated Lambda package (from CodeBuild)
│
├── /tests                    # Unit and integration tests
│   ├── test_handler.py       # Test Lambda function handler
│   ├── test_utils.py         # Test utility functions
│   └── __init__.py
│
├── requirements.txt          # Python dependencies
└── README.md                 # Project documentation
