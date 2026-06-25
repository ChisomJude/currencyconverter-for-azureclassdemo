"""
Unit tests for the pure conversion logic in app.py.

These deliberately do NOT call the real exchange-rate API — that's the
whole point of separating `convert()` from `get_exchange_rate()`. Fast,
deterministic, no network access needed. Run with:

    pytest
"""

import pytest

from app import convert


def test_convert_basic():
    assert convert(100, 1.08) == 108.0


def test_convert_zero_amount():
    assert convert(0, 1.5) == 0.0


def test_convert_rounding():
    # 33.333 * 1.0 = 33.333 -> rounds to 33.33
    assert convert(33.333, 1.0) == 33.33


def test_convert_large_amount():
    assert convert(1_000_000, 0.0012) == 1200.0


@pytest.mark.parametrize(
    "amount,rate,expected",
    [
        (50, 2.0, 100.0),
        (1, 1.0, 1.0),
        (200, 0.5, 100.0),
    ],
)
def test_convert_parametrized(amount, rate, expected):
    assert convert(amount, rate) == expected
