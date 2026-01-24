Base
• Protocol: HTTP
• Format: JSON
• Auth: IAM role (keyless)
• Runtime: Python
• Containerized

Endpoints

POST /ai
Purpose
• Accepts text
• Calls AWS Bedrock
• Returns AI response

Request
• Body
– text: string

Response
• Body
– response: string
– model: string

Status codes
• 200 success
• 400 invalid input
• 500 internal error

GET /health
Purpose
• Health check for ALB / service

Response
• Body
– status: ok

Status codes
• 200 healthy

Non-goals (important)
• No auth at API layer
• No session state
• No database
• No retries logic
• No prompt engineering
