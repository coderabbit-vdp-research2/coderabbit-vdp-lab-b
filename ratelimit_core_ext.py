"""Thread-safe, per-process token buckets using only the standard library.

Callers must supply trusted client keys, never unverified request parameters or
forwarded headers. State is not shared across processes or hosts. At capacity,
fully refilled buckets are pruned before least-recently-used eviction; an evicted
client restarts with a full bucket. Arbitrary key creation can bypass limits.
"""

from collections import OrderedDict, namedtuple
import json
import math
from pathlib import Path
import threading
import time

DEFAULT_MAX_REQUESTS = 60
DEFAULT_WINDOW_SECONDS = 60
DEFAULT_MAX_CLIENTS = 10000
MAX_CLIENT_KEY_LENGTH = 256
MAX_POLICY_FILE_BYTES = 64 * 1024
DEFAULT_POLICY_PATH = Path(__file__).resolve().parent / "config/ratelimit_policy_ext.json"
_UNSET = object()
_POLICY_KEYS = {"max_requests", "window_seconds", "max_clients"}

RateLimitResult = namedtuple("RateLimitResult", "allowed remaining retry_after")
RateLimitResult.__doc__ = (
    "Immutable decision: allowed, remaining whole tokens, retry_after seconds (0 if allowed)."
)
_Bucket = namedtuple("_Bucket", "tokens fraction updated")


def _positive_integer(name, value):
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{name} must be a positive int (not bool)")
    value = int(value)
    if value <= 0:
        raise ValueError(f"{name} must be greater than zero")
    return value


def _finite_number(name, value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise TypeError(f"{name} must be a finite int or float (not bool)")
    try:
        value = float(value)
    except OverflowError:
        raise ValueError(f"{name} must be representable as a finite float") from None
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


def _validate_client_id(client_id):
    if not isinstance(client_id, str):
        raise TypeError("client_id must be a str")
    # Strip subclass hooks before any dictionary operations under the lock.
    client_id = str.__str__(client_id)
    if len(client_id) > MAX_CLIENT_KEY_LENGTH:
        raise ValueError("client_id exceeds the maximum key length")
    if not client_id or client_id.isspace():
        raise ValueError("client_id must not be empty or whitespace-only")
    if any(ord(char) < 32 or 127 <= ord(char) <= 159 for char in client_id):
        raise ValueError("client_id must not contain control characters")
    return client_id


class RateLimiter:
    """Limit trusted client keys within one process using one state lock.

    max_requests and max_clients must be positive integers; window_seconds must
    be positive and finite. max_clients defaults to 10000. The computed refill
    rate must be representable as a positive finite float. clock is a callable
    returning finite monotonic seconds, defaulting to time.monotonic. It is
    invoked outside the lock; regressing or reordered samples cannot add credit.
    Direct construction never reads a policy file.
    """

    def __init__(self, max_requests, window_seconds, *,
                 max_clients=DEFAULT_MAX_CLIENTS, clock=time.monotonic):
        self._capacity = _positive_integer("max_requests", max_requests)
        self._max_clients = _positive_integer("max_clients", max_clients)
        self._window = _finite_number("window_seconds", window_seconds)
        if self._window <= 0:
            raise ValueError("window_seconds must be greater than zero")
        if not callable(clock):
            raise TypeError("clock must be callable")
        try:
            self._rate = self._capacity / self._window
        except OverflowError:
            raise ValueError("max_requests / window_seconds must be finite") from None
        if not math.isfinite(self._rate) or self._rate <= 0:
            raise ValueError("max_requests / window_seconds must be positive and finite")
        self._clock = clock
        self._lock = threading.Lock()
        self._clients = OrderedDict()

    def _refill(self, bucket, now):
        # Called only under the state lock. Keep whole tokens as integers so even
        # capacities above float's integer precision consume exactly one token.
        now = max(now, bucket.updated)
        elapsed = now - bucket.updated
        if elapsed >= self._window:
            return _Bucket(self._capacity, 0.0, now)
        credit = bucket.fraction + elapsed * self._rate
        if credit >= self._capacity - bucket.tokens:
            return _Bucket(self._capacity, 0.0, now)
        whole = math.floor(credit)
        return _Bucket(bucket.tokens + whole, credit - whole, now)

    def check(self, client_id):
        """Consume one token for a trusted key and return a RateLimitResult.

        remaining counts whole tokens. A denial consumes nothing; retry_after is
        the seconds until a token is available. Invalid input raises an error.
        """
        client_id = _validate_client_id(client_id)
        now = _finite_number("clock result", self._clock())
        with self._lock:
            if client_id in self._clients:
                bucket = self._refill(self._clients[client_id], now)
            else:
                if len(self._clients) >= self._max_clients:
                    idle = [key for key, state in self._clients.items()
                            if self._refill(state, now).tokens == self._capacity]
                    for key in idle:
                        del self._clients[key]
                    if len(self._clients) >= self._max_clients:
                        self._clients.popitem(last=False)
                bucket = _Bucket(self._capacity, 0.0, now)
            allowed = bucket.tokens >= 1
            tokens = bucket.tokens - int(allowed)
            retry_after = (0.0 if allowed else
                           (1.0 - bucket.fraction) * (self._window / self._capacity))
            self._clients[client_id] = _Bucket(tokens, bucket.fraction, bucket.updated)
            self._clients.move_to_end(client_id)
            return RateLimitResult(allowed, tokens, retry_after)

    def allow(self, client_id):
        """Consume one token for a trusted key and return only the boolean decision."""
        return self.check(client_id).allowed

    def reset(self, client_id):
        """Remove a trusted client's state; reserve this operation for administration."""
        client_id = _validate_client_id(client_id)
        with self._lock:
            self._clients.pop(client_id, None)


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate policy key: {key!r}")
        result[key] = value
    return result


def _reject_constant(value):
    raise ValueError(f"non-finite JSON constant: {value}")


def load_policy(path):
    """Read one UTF-8 JSON object, bounded to 64 KiB, without writing any files.

    Reject malformed JSON, duplicate/unknown keys, and non-finite constants.
    Return only present keys; constructor rules validate numeric values.
    File and permission errors propagate to the caller.
    """
    path = Path(path)
    with path.open("rb") as policy_file:
        data = policy_file.read(MAX_POLICY_FILE_BYTES + 1)
    if len(data) > MAX_POLICY_FILE_BYTES:
        raise ValueError(f"policy {path}: file exceeds MAX_POLICY_FILE_BYTES")
    try:
        policy = json.loads(data.decode("utf-8"), object_pairs_hook=_unique_object,
                            parse_constant=_reject_constant)
    except (ValueError, RecursionError) as error:
        raise ValueError(f"policy {path}: invalid JSON ({error})") from None
    if not isinstance(policy, dict):
        raise ValueError(f"policy {path}: top-level value must be an object")
    for key in policy:
        if key not in _POLICY_KEYS:
            raise ValueError(f"policy {path}: unknown key {key!r}")
    return policy


def create_rate_limiter(policy_path=None, *, max_requests=_UNSET,
                        window_seconds=_UNSET, max_clients=_UNSET, clock=_UNSET):
    """Read policy once and construct a limiter: explicit > file > defaults.

    A missing default path uses built-in defaults. A missing explicit path or
    invalid existing policy raises an error. File values use the constructor's
    validation rules, including when explicit arguments override them.
    """
    values = dict(max_requests=DEFAULT_MAX_REQUESTS,
                  window_seconds=DEFAULT_WINDOW_SECONDS, max_clients=DEFAULT_MAX_CLIENTS)
    try:
        policy = load_policy(DEFAULT_POLICY_PATH if policy_path is None else policy_path)
    except FileNotFoundError:
        if policy_path is not None:
            raise
        policy = {}
    values.update(policy)
    # Validate the file even when an explicit override would mask an invalid value.
    if policy:
        RateLimiter(**values)
    overrides = dict(max_requests=max_requests, window_seconds=window_seconds,
                     max_clients=max_clients, clock=clock)
    values.update({key: value for key, value in overrides.items() if value is not _UNSET})
    return RateLimiter(**values)
