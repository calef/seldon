# Change Notes

## [0.7.0] - 2026-01-21

- Added conditional request support with `if_modified_since:` and `if_none_match:` parameters to `HttpClient#fetch`.
- Returns `{ not_modified: true }` when server responds with HTTP 304 Not Modified, enabling bandwidth savings.
- New `NotModifiedError` class for internal 304 handling.

## [0.6.0] - 2026-01-21

- Added HTTP 503 Service Unavailable handling with Retry-After header support, matching existing 429 behavior.
- Added configurable jitter to exponential backoff (default ±25%) to prevent thundering herd on recovery.
- Added optional `from_email:` parameter to `HttpClient` for setting the HTTP From header (RFC 7231) to provide abuse contacts.
- New `service_unavailable_delay:` parameter (default 60s) for configuring default 503 retry delay.
- New `retry_jitter:` parameter (default 0.25) for configuring backoff jitter factor.

## [0.5.0] - 2026-01-21

- Added optional `referer:` parameter to `HttpClient#fetch` and `#response_for` for setting the HTTP Referer header on requests.
- Referer is automatically updated to the redirecting URL when following redirects.

## [0.4.0] - 2026-01-21

- Added `CookieJar` class for managing HTTP cookies per RFC 6265, with support for domain/path matching, Secure/HttpOnly attributes, and expiration handling.
- `HttpClient` now accepts an optional `cookie_jar` parameter to enable automatic cookie storage and transmission across requests and redirects.
- Cookies are persisted via `to_h`/`load` methods for session persistence.

## [0.3.1] - 2026-01-06

- Bumped Bundler to 4.0.3 and refreshed the lockfile, including the Minitest 6.0.1 update.

## [0.3.0] - 2026-01-02

- Introduced targeted specs for `HttpTransport` (requests, connection building, base URL handling) and expanded the URL normalizer tests so query filtering, decoding, and tracking prefix logic are covered.
- Updated helpers to return deterministic data in tests (e.g., `SimpleCov` plus fallback `stub` so the suite runs even if `minitest/mock` is unavailable) and improved coverage instrumentation/export.

## [0.2.0] - 2026-01-01

- Added RuboCop, RuboCop Minitest, Rake, and SimpleCov to the development bundle so linting, testing, and coverage tooling can run consistently for downstream apps.
- Instrumented the test helper with SimpleCov (plus a fallback `stub` helper) and added targeted specs for the logging and encoding helpers to keep the shared utilities well-covered.
- Added GitHub workflow scaffolding, developer guidelines, and supporting scripts so consuming repositories can build and validate the gem reliably.
