# auth_utils.py
import os
import base64
import hashlib
import requests
import urllib.parse

def generate_code_verifier():
    return base64.urlsafe_b64encode(os.urandom(64)).decode("utf-8").rstrip("=")

def generate_code_challenge(verifier):
    digest = hashlib.sha256(verifier.encode()).digest()
    return base64.urlsafe_b64encode(digest).decode("utf-8").rstrip("=")

def build_auth_url(client_id, redirect_uri, scope, code_challenge):
    params = {
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": redirect_uri,
        "code_challenge_method": "S256",
        "code_challenge": code_challenge,
        "scope": scope,
    }
    return f"https://accounts.spotify.com/authorize?{urllib.parse.urlencode(params)}"

def exchange_code_for_token(code, verifier, client_id, redirect_uri):
    payload = {
        "client_id": client_id,
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "code_verifier": verifier,
    }
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    response = requests.post("https://accounts.spotify.com/api/token", data=payload, headers=headers)
    if response.status_code == 200:
        return response.json()["access_token"]
    else:
        raise Exception(f"Token exchange failed: {response.text}")
