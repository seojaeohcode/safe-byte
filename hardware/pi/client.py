"""Cart capability client. No user password, cloud secret, or durable profile storage."""
import httpx
from urllib.parse import urlparse


class CartClient:
    def __init__(self, base_url, transport=None):
        parsed = urlparse(base_url)
        if parsed.scheme != 'https' and not (parsed.scheme == 'http' and parsed.hostname in ('127.0.0.1', 'localhost', '::1')):
            raise ValueError("Cart requires HTTPS (localhost is allowed for development)")
        self.http = httpx.Client(base_url=base_url.rstrip('/'), timeout=60, transport=transport)
        self.token = None
        self.session = None
        self.revision = 0

    def pair(self, code):
        revision = self.revision
        response = self.http.post('/api/v1/devices/redeem', json={'code':code})
        response.raise_for_status()
        if revision != self.revision:
            raise ValueError('Pairing cancelled')
        self.token = response.json()['token']
        return self.check()

    def clear(self):
        self.revision += 1
        self.token = self.session = None

    def check(self):
        if not self.token:
            raise ValueError('Pair the cart first')
        token = self.token
        response = self.http.get('/api/v1/devices/session', headers={'Authorization':'Bearer '+token})
        if self.token != token:
            raise ValueError('Session cancelled')
        if response.status_code in (400,401,403):
            self.clear()
        response.raise_for_status()
        self.session = response.json()
        return self.session

    def analyze(self, jpeg):
        self.check()
        response = self.http.post('/api/v1/devices/analyze', headers={'Authorization':'Bearer '+self.token},
                                  files={'file':('cart-label.jpg',jpeg,'image/jpeg')})
        if response.status_code in (400,401,403):
            # Local profile is erased even if a session was closed while OCR ran.
            self.clear()
        response.raise_for_status()
        return response.json()

    def close(self):
        self.clear()
        self.http.close()
