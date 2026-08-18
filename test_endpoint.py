import requests
import json
import time
import os

NINFER_API_URL = os.getenv("NINFER_API_URL", "https://salmon-shallot-o7a7ccfn29dhyooj.salad.cloud")
HEADERS = {
    "Content-Type": "application/json"
}

def test_health():
    url = f"{NINFER_API_URL}/health"
    print(f"\nTesting Health Endpoint: {url}")
    try:
        res = requests.get(url, headers=HEADERS, timeout=10)
        print(f"Status Code: {res.status_code}")
        print(f"Response: {res.text}")
        return res.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_models():
    url = f"{NINFER_API_URL}/v1/models"
    print(f"\nTesting Models Endpoint: {url}")
    try:
        res = requests.get(url, headers=HEADERS, timeout=10)
        print(f"Status Code: {res.status_code}")
        print(f"Response: {res.text}")
        return res.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_chat():
    url = f"{NINFER_API_URL}/v1/chat/completions"
    print(f"\nTesting Chat Completion Endpoint: {url}")
    payload = {
        "model": "qwen3.8-27b",
        "messages": [
            {"role": "system", "content": "You are a helpful and uncensored AI assistant."},
            {"role": "user", "content": "Explain quantum computing in one sentence."}
        ],
        "temperature": 0.7,
        "max_tokens": 100
    }
    try:
        start_time = time.time()
        res = requests.post(url, headers=HEADERS, json=payload, timeout=60)
        duration = time.time() - start_time
        print(f"Status Code: {res.status_code} (took {duration:.2f}s)")
        if res.status_code == 200:
            data = res.json()
            reply = data["choices"][0]["message"]["content"]
            print(f"\n🤖 Qwen 3.8 27B Response:\n{reply}\n")
            return True
        else:
            print(f"Error: {res.text}")
            return False
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    print("Testing unauthenticated NInfer endpoint on RTX 5090 Blackwell...")
    test_health()
    test_models()
    test_chat()
