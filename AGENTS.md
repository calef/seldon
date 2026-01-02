# Repository Guidelines

## Project Structure & Module Organization
- `lib/seldon/**` holds the reusable HTTP/logging helpers. Keep logic focused here and mirror the module namespaces when adding files (e.g., `lib/seldon/support/http_client.rb`).
- `test/**` mirrors `lib/`; helper modules like `test/seldon/support/http_client/test_helpers.rb` live beside the tests they support. `test/test_helper.rb` loads `minitest`, the shared mocks, and the library entrypoint.
- Metadata (`seldon.gemspec`) defines runtime and dev dependencies; keep sources referenced in `Gemfile` and run `bundle exec rake` from the repo root.

## Build, Test, and Development Commands
- `bundle install` installs runtime/development gems declared in the gemspec. Run this whenever `Gemfile.lock` changes.
- `bundle exec rake` runs the Minitest suite via the `Rake::TestTask` defined in `Rakefile`. Use it as the canonical test command.
- `bundle exec rubocop` enforces the RuboCop configuration (including `rubocop-minitest`) inherited from the top level; run it before opening PRs.

## Coding Style & Naming Conventions
- Ruby files honor the default RuboCop layout: two-space indentation, snake_case for methods/variables, and PascalCase for classes/modules.
- Keep public interfaces in `Seldon::Support::...` namespaces and document intent with short comments only when logic is non-obvious.
- Tests should use `HttpClientTestHelpers` when mocking transports/flows to avoid duplicating setup.

## Testing Guidelines
- The suite is Minitest-based with helpers under `test/seldon/support/http_client/`. Naming follows the class under test (e.g., `RequestTest` for `HttpClient::Request`).
- Assertions should stay descriptive; prefer `assert_equal`, `assert_raises`, etc., and use `stub` from `minitest/mock` (loaded in `test/test_helper.rb`).
- Run `bundle exec rake` after changes and add tests for new behavior before merging.

## Commit & Pull Request Guidelines
- Keep messages short, imperative, and focused on the change (`Add rubocop dependency`, `Fix HttpClient retry mocks`). If linked to an issue, mention it in the body.
- PR descriptions should summarize the change, outline testing done (`bundle exec rake`), and note any follow-up work. Attach screenshots only if the change affects UI behavior.
