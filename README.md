<p align="center">
  <img src="assets/zirp-logo.png" alt="Zirp Logo" width="150" height="150">
</p>

# Zirp

Zirp is a powerful Ruby client gem for interacting with the Zirp multi-platform content distribution system. It provides a simple and intuitive interface for managing content and publishing it to various platforms like Slack, Email, Twitter, LinkedIn, and more.

> **⚠️ BETA STATUS**: This project is currently in beta and not yet ready for production use. APIs and functionality may change without notice.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add zirp

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install zirp

## Features

- **Content Management**: Create, update, and delete content across multiple platforms
- **AI-Powered Generation**: Generate content using LLM integration
- **Multi-Platform Publishing**: Publish content to Slack, Email, Twitter, LinkedIn, Notion, and more
- **Preview Mode**: Preview how content will appear on different platforms before publishing
- **Platform Management**: Add, configure, and validate platform credentials
- **CLI Interface**: Command-line tools for content and platform management
- **API Authentication**: Secure API key authentication

## Usage

### Configuration

```ruby
require 'zirp'

Zirp.configure do |config|
  config.api_key = 'your_api_key'
  config.endpoint = 'https://api.zirp.example.com'
  config.timeout = 30 # seconds
end
```

### Client Usage

```ruby
# Initialize client
client = Zirp::Client.new

# List contents
contents = client.contents.list

# Create content
content = client.contents.create(
  title: "Announcing Our New Feature",
  body: "We're excited to announce...",
  metadata: { tags: ["announcement", "feature"] }
)

# Generate content with AI
content = client.contents.generate(
  id: content.id,
  prompt_template: "Write an announcement for {{product_name}}",
  context: { product_name: "Zirp" }
)

# Preview content on platforms
previews = client.contents.preview(id: content.id)

# Publish content to platforms
result = client.contents.publish(
  id: content.id,
  platform_ids: [1, 2, 3]
)

# List platforms
platforms = client.platforms.list

# Validate platform credentials
valid = client.platforms.validate_credentials(id: 1)
```

### CLI Usage

```bash
# Configure API key
$ zirp configure --api-key=your_api_key

# List contents
$ zirp contents list

# Create content
$ zirp contents create --title="Announcement" --body="Hello world"

# Generate content with AI
$ zirp contents generate --id=1 --prompt="Write an announcement"

# Preview content
$ zirp contents preview --id=1

# Publish content
$ zirp contents publish --id=1 --platforms=1,2,3

# List platforms
$ zirp platforms list

# Validate platform credentials
$ zirp platforms validate --id=1
```

## Development

### Setup

```bash
# Clone the repository
git clone https://github.com/your-username/zirp_rb.git
cd zirp_rb

# Install dependencies
bundle install

# Run tests
rake spec
```

### Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a new Pull Request

## License

MIT
