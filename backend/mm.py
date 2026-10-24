from google import genai
import os
from dotenv import load_dotenv

load_dotenv("key.env")

# Initialize the new client
client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY"))

print("--- Available Models for your Key ---")
try:
    # simple list without complex filtering
    for m in client.models.list():
        print(f"Found: {m.name}")
except Exception as e:
    print(f"Error: {e}")