# auth_utils.py
import os
import base64
import hashlib
import urllib.parse
import requests

def generate_code_verifier():
    return base64.urlsafe_b64encode(os.urandom(64)).decode('utf-8').rstrip('=')

def generate_code_challenge(verifier):
    digest = hashlib.sha256(verifier.encode()).digest()
    return base64.urlsafe_b64encode(digest).decode('utf-8').rstrip('=')

def build_auth_url(client_id, redirect_uri, scope, code_challenge):
    params = {
        'client_id': client_id,
        'response_type': 'code',
        'redirect_uri': redirect_uri,
        'scope': scope,
        'code_challenge_method': 'S256',
        'code_challenge': code_challenge
    }
    return f"https://accounts.spotify.com/authorize?{urllib.parse.urlencode(params)}"

def exchange_code_for_token(code, verifier, client_id, redirect_uri):
    payload = {
        'client_id': client_id,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirect_uri,
        'code_verifier': verifier
    }
    r = requests.post("https://accounts.spotify.com/api/token", data=payload)
    r.raise_for_status()
    return r.json()["access_token"]
