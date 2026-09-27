import concurrent.futures
import json
import math
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch

import ratelimit_core_ext as rl


class FakeClock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now

    def advance(self, seconds):
        self.now += seconds


class LimiterTests(unittest.TestCase):
    def setUp(self):
        self.clock = FakeClock()

    def limiter(self, capacity=2, window=10, **kwargs):
        return rl.RateLimiter(capacity, window, clock=self.clock, **kwargs)

    def test_capacity_retry_fractional_refill_and_cap(self):
        limiter = self.limiter()
        self.assertEqual(limiter.check("alice"), (True, 1, 0))
        self.assertEqual(limiter.check("alice"), (True, 0, 0))
        denied = limiter.check("alice")
        self.assertEqual(denied, (False, 0, 5))
        with self.assertRaises(AttributeError):
            denied.allowed = True
        self.clock.advance(2)
        denied = limiter.check("alice")
        self.assertAlmostEqual(denied.retry_after, 3)
        self.clock.advance(denied.retry_after)
        self.assertTrue(limiter.allow("alice"))
        self.assertFalse(limiter.allow("alice"))
        self.clock.advance(100)
        self.assertEqual(limiter.check("alice").remaining, 1)
        self.assertTrue(limiter.allow("alice"))
        self.assertFalse(limiter.allow("alice"))

    def test_independent_keys_and_reset(self):
        limiter = self.limiter(1)
        for key in ("alice", "Alice", " alice ", "bob"):
            self.assertTrue(limiter.allow(key))
            self.assertFalse(limiter.allow(key))
        limiter.reset("alice")
        limiter.reset("missing")
        self.assertTrue(limiter.allow("alice"))
        self.assertFalse(limiter.allow("bob"))

    def test_constructor_validation(self):
        for name in ("max_requests", "max_clients", "window_seconds"):
            cases = [(True, TypeError), (False, TypeError), (None, TypeError),
                     ("1", TypeError), (0, ValueError), (-1, ValueError)]
            if name == "window_seconds":
                cases += [(float("nan"), ValueError), (float("inf"), ValueError),
                          (-float("inf"), ValueError), (10 ** 400, ValueError)]
            else:
                cases += [(1.5, TypeError), (float("nan"), TypeError),
                          (float("inf"), TypeError)]
            for value, error in cases:
                with self.subTest(name=name, value=value):
                    args = dict(max_requests=1, window_seconds=1, max_clients=1)
                    args[name] = value
                    with self.assertRaisesRegex(error, name):
                        rl.RateLimiter(**args)
        with self.assertRaisesRegex(TypeError, "clock"):
            rl.RateLimiter(1, 1, clock=None)
        for capacity, window in ((10 ** 400, 1), (1, 5e-324)):
            with self.assertRaisesRegex(ValueError, "max_requests / window_seconds"):
                self.limiter(capacity, window)

    def test_client_validation_all_methods_no_state_or_key_leak(self):
        limiter = self.limiter()
        cases = [(None, TypeError), (b"secret", TypeError), (42, TypeError),
                 ([], TypeError), ("", ValueError), ("   ", ValueError),
                 ("s" * 257, ValueError)]
        cases += [("secret" + chr(c) + "key", ValueError)
                  for c in list(range(32)) + list(range(127, 160))]
        for method in (limiter.check, limiter.allow, limiter.reset):
            for key, error in cases:
                with self.subTest(method=method.__name__, key=repr(key)):
                    with self.assertRaises(error) as caught:
                        method(key)
                    if isinstance(key, str) and key:
                        self.assertNotIn(key, str(caught.exception))
                    self.assertEqual(len(limiter._clients), 0)
        self.assertTrue(limiter.allow("x" * 256))
        self.assertTrue(limiter.allow("用户"))

    def test_key_flooding_is_bounded(self):
        limiter = self.limiter(max_clients=3)
        for index in range(1000):
            self.assertTrue(limiter.allow(str(index)))
            self.assertLessEqual(len(limiter._clients), 3)

    def test_idle_entries_removed_before_older_active_entry(self):
        limiter = self.limiter(2, 10, max_clients=2)
        limiter.allow("active")
        limiter.allow("active")
        limiter.allow("idle")
        self.clock.advance(5)
        limiter.allow("new")
        self.assertEqual(list(limiter._clients), ["active", "new"])
        self.assertEqual(limiter.check("active").remaining, 0)

    def test_lru_access_includes_denials_and_evicted_client_restarts(self):
        limiter = self.limiter(1, max_clients=2)
        limiter.allow("a")
        limiter.allow("b")
        self.assertFalse(limiter.allow("a"))
        limiter.allow("c")
        self.assertEqual(list(limiter._clients), ["a", "c"])
        self.assertTrue(limiter.allow("b"))

    def test_concurrent_burst(self):
        limiter = self.limiter(17)
        barrier = threading.Barrier(16)

        def burst(_):
            barrier.wait(timeout=5)
            return sum(limiter.allow("shared") for _ in range(20))

        with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
            self.assertEqual(sum(pool.map(burst, range(16))), 17)

    def test_backward_clock_does_not_mint_tokens(self):
        self.clock.now = 10
        limiter = self.limiter(1, 10)
        limiter.allow("a")
        self.clock.now = 5
        self.assertEqual(limiter.check("a").retry_after, 10)
        self.clock.now = 10
        self.assertFalse(limiter.allow("a"))
        self.clock.now = 20
        self.assertTrue(limiter.allow("a"))

    def test_invalid_clock_does_not_mutate_state(self):
        for value, error in ((math.nan, ValueError), (math.inf, ValueError),
                             (True, TypeError), ("1", TypeError)):
            with self.subTest(value=value):
                limiter = rl.RateLimiter(1, 1, clock=lambda: value)
                with self.assertRaises(error):
                    limiter.allow("secret")
                self.assertFalse(limiter._clients)

    def test_clock_and_string_hooks_are_outside_lock(self):
        limiter = self.limiter()

        def clock():
            self.assertTrue(limiter._lock.acquire(blocking=False))
            limiter._lock.release()
            limiter.reset("other")
            return 0

        class Key(str):
            def __hash__(self):
                raise AssertionError("subclass hashing must not run")

        limiter._clock = clock
        self.assertTrue(limiter.allow(Key("trusted")))
        limiter.reset(Key("trusted"))

    def test_extreme_finite_window_has_finite_retry(self):
        window = float.fromhex("0x1.fffffffffffffp+1023")
        limiter = self.limiter(1, window)
        self.assertTrue(limiter.allow("a"))
        denied = limiter.check("a")
        self.assertTrue(math.isfinite(denied.retry_after))
        self.assertEqual(denied.retry_after, window)
        self.clock.advance(denied.retry_after)
        self.assertTrue(limiter.allow("a"))

    def test_large_integer_capacity_consumes_exactly(self):
        limiter = self.limiter(2 ** 60)
        self.assertEqual(limiter.check("a").remaining, 2 ** 60 - 1)
        self.assertEqual(limiter.check("a").remaining, 2 ** 60 - 2)


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "policy.json"
        self.clock = FakeClock()

    def write(self, data):
        self.path.write_text(data, encoding="utf-8")

    def test_committed_policy_matches_defaults(self):
        self.assertEqual(rl.load_policy(rl.DEFAULT_POLICY_PATH), dict(
            max_requests=rl.DEFAULT_MAX_REQUESTS,
            window_seconds=rl.DEFAULT_WINDOW_SECONDS, max_clients=rl.DEFAULT_MAX_CLIENTS))
        self.assertTrue(rl.create_rate_limiter(clock=self.clock).allow("a"))
        self.assertEqual(rl.DEFAULT_POLICY_PATH, Path(rl.__file__).resolve().parent /
                         "config/ratelimit_policy_ext.json")

    def test_precedence_and_partial_defaults(self):
        self.write('{"max_requests": 2, "window_seconds": 10}')
        limiter = rl.create_rate_limiter(self.path, max_requests=1, clock=self.clock)
        self.assertTrue(limiter.allow("a"))
        self.assertEqual(limiter.check("a").retry_after, 10)
        self.assertEqual(limiter._max_clients, rl.DEFAULT_MAX_CLIENTS)
        self.assertEqual(rl.load_policy(self.path), {"max_requests": 2, "window_seconds": 10})
        limiter = rl.create_rate_limiter(self.path, clock=self.clock)
        self.assertEqual(limiter.check("a").remaining, 1)

    def test_missing_default_and_explicit_paths(self):
        with patch.object(rl, "DEFAULT_POLICY_PATH", self.path):
            limiter = rl.create_rate_limiter(clock=self.clock)
            self.assertEqual(limiter.check("a").remaining, rl.DEFAULT_MAX_REQUESTS - 1)
            with self.assertRaises(FileNotFoundError):
                rl.create_rate_limiter(self.path)
        self.assertFalse(self.path.exists())

    def test_existing_invalid_default_never_falls_back(self):
        self.write("invalid")
        with patch.object(rl, "DEFAULT_POLICY_PATH", self.path):
            with self.assertRaises(ValueError):
                rl.create_rate_limiter()

    def test_explicit_none_is_validated(self):
        self.write("{}")
        for key in ("max_requests", "window_seconds", "max_clients", "clock"):
            with self.subTest(key=key), self.assertRaises(TypeError):
                rl.create_rate_limiter(self.path, **{key: None})

    def test_hostile_json_rejected(self):
        cases = ["{", "[]", "null", "true", "1", '"string"',
                 '{"clock": 1}', '{"max_requests": 1, "max_requests": 2}',
                 '{"window_seconds": NaN}', '{"window_seconds": Infinity}',
                 '{"window_seconds": -Infinity}',
                 " " * (rl.MAX_POLICY_FILE_BYTES + 1), "[" * 2000]
        for data in cases:
            with self.subTest(data=data[:80]):
                self.write(data)
                with self.assertRaises(ValueError):
                    rl.load_policy(self.path)
                with self.assertRaises(ValueError):
                    rl.create_rate_limiter(self.path)
        self.path.write_bytes(b"\xff")
        with self.assertRaises(ValueError):
            rl.create_rate_limiter(self.path)

    def test_unknown_key_names_path_and_key(self):
        self.write('{"unexpected": 1}')
        with self.assertRaises(ValueError) as caught:
            rl.load_policy(self.path)
        self.assertIn(str(self.path), str(caught.exception))
        self.assertIn("unexpected", str(caught.exception))

    def test_policy_numeric_values_and_overridden_invalid_values(self):
        for key in ("max_requests", "window_seconds", "max_clients"):
            for value in (True, 0, -1, None, "1", [], {}):
                with self.subTest(key=key, value=value):
                    self.write(json.dumps({key: value}))
                    with self.assertRaises((TypeError, ValueError)):
                        rl.create_rate_limiter(self.path)
                    with self.assertRaises((TypeError, ValueError)):
                        rl.create_rate_limiter(self.path, **{key: 1})
        self.write('{"window_seconds": 1e999}')
        with self.assertRaises(ValueError):
            rl.create_rate_limiter(self.path)

    def test_size_limit_is_bytes_and_boundary_is_accepted(self):
        self.write("{}" + " " * (rl.MAX_POLICY_FILE_BYTES - 2))
        self.assertEqual(rl.load_policy(self.path), {})
        self.write('{"' + "é" * (rl.MAX_POLICY_FILE_BYTES // 2) + '": 1}')
        with self.assertRaisesRegex(ValueError, "MAX_POLICY_FILE_BYTES"):
            rl.load_policy(self.path)

    def test_factory_reads_once_and_constructor_never_reads(self):
        self.write("{}")
        with patch.object(rl, "load_policy", wraps=rl.load_policy) as reader:
            rl.RateLimiter(1, 1)
            reader.assert_not_called()
            rl.create_rate_limiter(self.path)
            reader.assert_called_once_with(self.path)

    def test_permissions_and_directory_errors_propagate(self):
        with patch.object(rl, "load_policy", side_effect=PermissionError):
            with self.assertRaises(PermissionError):
                rl.create_rate_limiter()
        with self.assertRaises(IsADirectoryError):
            rl.create_rate_limiter(self.directory.name)


if __name__ == "__main__":
    unittest.main()
