import requests
import sys
import os

# ElevenLabs Music Generation Script
# Usage: python generate_music.py "YOUR_API_KEY" "YOUR_PROMPT" "FILENAME"

if len(sys.argv) < 4:
    print("Usage: python generate_music.py <API_KEY> <PROMPT> <FILENAME>")
    sys.exit(1)

api_key = sys.argv[1]
prompt = sys.argv[2]
filename = sys.argv[3]

url = "https://api.elevenlabs.io/v1/text-to-music"

headers = {
    "xi-api-key": api_key,
    "Content-Type": "application/json"
}

data = {
    "text": prompt,
}

print(f"Generating music for: {prompt}...")

response = requests.post(url, headers=headers, json=data)

if response.status_code == 200:
    with open(f"{filename}.mp3", "wb") as f:
        f.write(response.content)
    print(f"Success! Saved to {filename}.mp3")
else:
    print(f"Error: {response.status_code}")
    print(response.text)
