# Import FastAPI framework for building APIs
from fastapi import FastAPI, UploadFile, File, Form

# Optional is used to mark fields that are not mandatory
from typing import Optional

# Create FastAPI application instance
# This object is referenced in the Dockerfile when starting uvicorn (main:app)
app = FastAPI()

# Health check endpoint used by ALB
# If this endpoint returns 200 OK, the service is considered healthy
@app.get("/health")
def health():
    return {"status": "ok"}

# Endpoint to receive ECG data from clients
# Accepts file upload along with patient metadata via form fields
@app.post("/ecg")
def upload_ecg(

    # Uploaded ECG file
    ecg_file: UploadFile = File(...),

    # Mandatory patient identifier
    mrn: str = Form(...),

    # Optional metadata fields
    patient_name: Optional[str] = Form(None),
    dob: Optional[str] = Form(None),

    # Timestamp of ECG capture (required)
    timestamp: str = Form(...)
):
    # In real systems this would store the ECG file and metadata
    # For this project it returns a dummy response
    return {
        "status": "stored",
        "record_id": "dummy-id-123"
    }
