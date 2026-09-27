# coderabbit-vdp-lab-b

TYPHON2_PR2 change: normal readme update for report-render test.

## Rate limiting utility

`ratelimit_core_ext.py` is a standalone, standard-library token bucket.
`RateLimiter(max_requests, window_seconds, *, max_clients=10000, clock=time.monotonic)`
accepts positive integer capacity and client count and a positive finite window
in seconds (booleans are rejected). The refill rate must be representable as a
positive finite float. Direct construction never reads the filesystem.

- `check(client_id)` consumes a token and returns immutable `RateLimitResult`:
  `allowed`, `remaining` whole tokens, and `retry_after` seconds (zero on success).
- `allow(client_id)` consumes a token and returns just the boolean decision.
- `reset(client_id)` removes one client's state; reserve it for administration.

Keys must be nonempty strings of at most 256 characters, with no control
characters or whitespace-only values. Keys are not trimmed or case folded.
Derive keys from a trusted source, such as an authenticated user ID or a remote
address established by trusted proxy configuration. Never use unverified request
parameters or unverified `X-Forwarded-For` values. Arbitrary key creation can
bypass per-client limits.

`create_rate_limiter()` reads `config/ratelimit_policy_ext.json` once per call,
relative to the module directory. Its optional keys are `max_requests`,
`window_seconds`, and `max_clients`; built-in defaults are 60, 60, and 10000.
Precedence is explicit keyword arguments, then file values, then built-in
defaults. `clock` can only be supplied in code. `load_policy(path)` returns the
keys present after checking JSON structure; constructor rules check values.
An absent default file uses built-in defaults; an absent explicit `policy_path`
raises `FileNotFoundError`. Invalid existing files raise errors, even when a
keyword argument overrides an invalid value, and never fall back to defaults.
Files must be UTF-8 JSON objects of at most 64 KiB with no duplicate or unknown
keys or non-finite constants. The module never writes policy files. Operators
must restrict write access to the policy because it controls the limits.

State is thread-safe within one process and is not shared across processes or
hosts. Reuse one limiter across requests. When `max_clients` is reached, fully
refilled buckets are removed first, then the least recently used client if
needed. Evicted clients restart with a full bucket. New keys at capacity can
require an O(max_clients) idle scan; normal accesses take constant work.

Framework-neutral example (create the limiter once at startup):

```python
import math
from ratelimit_core_ext import create_rate_limiter

limiter = create_rate_limiter()

def handle_request(trusted_client_id):
    result = limiter.check(trusted_client_id)
    if not result.allowed:
        return 429, {"Retry-After": str(math.ceil(result.retry_after))}, "Too many requests"
    return 200, {}, "OK"
```

Run the deterministic behavior, validation, policy, and abuse tests with
`python -m unittest discover -s tests`.
