# Change Notes

## [0.3.0] - 2026-01-02

- Introduced targeted specs for `HttpTransport` (requests, connection building, base URL handling) and expanded the URL normalizer tests so query filtering, decoding, and tracking prefix logic are covered.
- Updated helpers to return deterministic data in tests (e.g., `SimpleCov` plus fallback `stub` so the suite runs even if `minitest/mock` is unavailable) and improved coverage instrumentation/export.

## [0.2.0] - 2026-01-01

- Added RuboCop, RuboCop Minitest, Rake, and SimpleCov to the development bundle so linting, testing, and coverage tooling can run consistently for downstream apps.
- Instrumented the test helper with SimpleCov (plus a fallback `stub` helper) and added targeted specs for the logging and encoding helpers to keep the shared utilities well-covered.
- Added GitHub workflow scaffolding, developer guidelines, and supporting scripts so consuming repositories can build and validate the gem reliably.
