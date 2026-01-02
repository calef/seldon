# Seldon

Shared infrastructure for HTTP, URL helpers, and structured logging used by Mayhem and Chio.

## Usage

Add this gem to your `Gemfile` and require `seldon`:

```ruby
gem 'seldon', path: '../seldon'
```

Then include the modules you need:

```ruby
require 'seldon'

logger = Seldon::Logging.build_logger(env_var: 'LOG_LEVEL')
client = Seldon::Support::HttpClient.new
```
