"""Shared HTTP client for the Woven Word conference-citation pipeline.

Fetches only the Scripture Citation Index's public web pages
(scriptures.byu.edu), sequentially, at ordinary-use pacing: one
request at a time, ~1.1s + jitter between requests, honest
identification, exponential backoff on 5xx, and a long cool-down if
the site ever answers 429. No access control is circumvented; every
URL fetched is a page the site's own frontend requests.
"""
import random
import time
import urllib.request
import urllib.error

BASE = "https://scriptures.byu.edu"
UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126 Safari/537.36 "
      "WovenWord-Studio-Pipeline/1.0 (citation-facts harvest; "
      "contact tysonscadden@gmail.com)")

_last = [0.0]


def get(path, min_delay=1.0):
    """GET a path on the SCI site with pacing + retries. Returns text."""
    url = path if path.startswith("http") else BASE + path
    attempt = 0
    while True:
        attempt += 1
        wait = _last[0] + min_delay + random.uniform(0.0, 0.5) - time.time()
        if wait > 0:
            time.sleep(wait)
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        try:
            with urllib.request.urlopen(req, timeout=90) as resp:
                body = resp.read().decode("utf-8", errors="replace")
            _last[0] = time.time()
            return body
        except urllib.error.HTTPError as e:
            _last[0] = time.time()
            if e.code == 429:
                if attempt > 3:
                    raise
                time.sleep(60)
                continue
            if e.code in (500, 502, 503, 504) and attempt <= 4:
                time.sleep(2 ** attempt)
                continue
            if e.code == 404:
                return ""
            raise
        except urllib.error.URLError:
            if attempt <= 6:
                time.sleep(3 * attempt)
                continue
            raise
