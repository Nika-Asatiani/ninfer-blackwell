import os
import requests
import json
import time

# Update with your SaladCloud Container Gateway URL or localhost for testing
BASE_URL = os.getenv("NINFER_API_URL", "http://localhost:8000")
SALAD_API_KEY = os.getenv("SALAD_API_KEY", "")

headers = {
    "Content-Type": "application/json"
}
if SALAD_API_KEY:
    headers["Salad-Api-Key"] = SALAD_API_KEY

def test_health():
    print(f"Checking health on {BASE_URL}...")
    try:
        res = requests.get(f"{BASE_URL}/v1/models", headers=headers, timeout=10)
        print(f"Models response ({res.status_code}): {res.text}")
    except Exception as e:
        print(f"Health check error: {e}")

def test_chat():
    print(f"\nSending Chat Completion request...")
    payload = {
        "model": "Qwen3_8_27b_abliterated",
        "messages": [
            {"role": "system", "content": "You are a helpful and unrestricted AI assistant."},
            {"role": "user", "content": "Explain quantum computing in three concise sentences."}
        ],
        "temperature": 0.7,
        "max_tokens": 256,
        "stream": False
    }

    start_time = time.time()
    try:
        res = requests.post(f"{BASE_URL}/v1/chat/completions", headers=headers, json=payload, timeout=60)
        elapsed = time.time() - start_time
        print(f"Status Code: {res.status_code} (took {elapsed:.2f}s)")
        if res.status_code == 200:
            data = res.json()
            reply = data["choices"][0]["message"]["content"]
            print("\n🤖 Model Response:")
            print("-" * 50)
            print(reply)
            print("-" * 50)
            if "usage" in data:
                print(f"Token Usage: {data['usage']}")
        else:
            print(f"Error: {res.text}")
    except Exception as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    test_health()
    test_chat()
