1) What this service does | Service starts after HTTP hits it
	
	• Client sends ECG image + metadata over HTTPS | client is establishing encrypted TLS connection with ALB 
	
	• HTTPS terminates at ALB | ALB decrypts the traffic(https) and reads it
	
	• ALB forwards request over HTTP
	
	• Our service receives it
	
	• Service validates, stores, and later serves data

2) What it accepts

	What the service accepts
	
    • HTTPS request
	
	• ECG image (file)
	
	• Metadata
	 – patient_name
	 – MRN
	 – DOB
	 – timestamp

3) What it returns
	
	• status: stored
	
	• record_id: abc123
	
4) What it does not do

	• It does not handle authentication screens

