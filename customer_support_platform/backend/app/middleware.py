"""
Production middleware:
1. Sliding-window rate limiting per client IP to prevent brute-force attacks and AI abuse.
2. HTTP Security headers (OWASP standards).
3. Centralized error handling to prevent sensitive data/traceback leakage.
"""

from __future__ import annotations

import logging
import time
from collections import defaultdict
from threading import Lock

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger("app.security")


class RateLimiter:
    def __init__(self):
        self._requests: dict[str, list[float]] = defaultdict(list)
        self._lock = Lock()

    def is_allowed(self, key: str, limit: int, window: float = 60.0) -> bool:
        now = time.time()
        cutoff = now - window
        with self._lock:
            history = self._requests[key]
            # Prune timestamps outside the window
            self._requests[key] = [t for t in history if t > cutoff]
            if len(self._requests[key]) >= limit:
                return False
            self._requests[key].append(now)
            return True

    def reset(self) -> None:
        with self._lock:
            self._requests.clear()


_limiter = RateLimiter()


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        # Determine client IP (respecting forwarded headers safely if present)
        forwarded = request.headers.get("X-Forwarded-For")
        client_ip = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else "unknown")

        path = request.url.path
        method = request.method

        # 1. Auth endpoints rate limit: 15 req/minute
        if path in {"/api/v1/auth/login", "/api/v1/auth/register"} and method == "POST":
            key = f"auth:{client_ip}"
            if not _limiter.is_allowed(key, limit=15, window=60.0):
                logger.warning("Rate limit exceeded for auth from IP %s", client_ip)
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too many requests. Please try again later."},
                    headers={"Retry-After": "60"},
                )

        # 2. AI endpoints rate limit: 30 req/minute
        elif "/conversations/" in path and "/messages" in path and method == "POST":
            key = f"ai:{client_ip}"
            if not _limiter.is_allowed(key, limit=30, window=60.0):
                logger.warning("Rate limit exceeded for AI chat from IP %s", client_ip)
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too many messages sent. Please slow down."},
                    headers={"Retry-After": "60"},
                )

        return await call_next(request)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        return response


def setup_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(Exception)
    async def generic_exception_handler(request: Request, exc: Exception):
        logger.exception("Unhandled server exception at %s %s: %s", request.method, request.url.path, exc)
        return JSONResponse(
            status_code=500,
            content={"detail": "An internal server error occurred. Please contact support."},
        )
