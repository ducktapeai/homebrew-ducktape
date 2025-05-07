# Homebrew Tap for DuckTape

This is the official Homebrew tap for DuckTape, an AI-powered terminal tool for Apple Calendar, Reminders, and Notes.

## Installation

Install DuckTape via Homebrew with a single command:

```bash
brew install ducktapeai/ducktape/ducktape
```

Or, you can add the tap first and then install:

```bash
# Add the tap
brew tap ducktapeai/ducktape

# Install DuckTape
brew install ducktape
```

## Updating DuckTape

To update to the latest version:

```bash
brew upgrade ducktapeai/ducktape/ducktape
```

## System Requirements

- **macOS**: DuckTape only works on macOS
- **Apple Calendar, Reminders, and Notes**: These apps should be properly configured
- **Rust**: Installed automatically as a build dependency

## Post-Installation Setup

After installation, you'll need to:

1. **Set up API Keys**: For AI functionality, export an API key for your preferred provider:
   ```bash
   # Choose one:
   export OPENAI_API_KEY='your-openai-api-key-here'
   export XAI_API_KEY='your-xai-api-key-here'
   export DEEPSEEK_API_KEY='your-deepseek-api-key-here'
   ```

2. **Configure DuckTape**: Run DuckTape once to generate the default configuration:
   ```bash
   ducktape
   ```

## Troubleshooting

If you encounter issues during installation:

- Make sure you're running on macOS
- Verify your internet connection
- Ensure you have sufficient permissions
- Try running `brew doctor` to check for any Homebrew issues
- For issues with the formula, please [open an issue](https://github.com/ducktapeai/ducktape/issues)

## Usage

After installation, you can run DuckTape in three ways:

1. **Interactive Hybrid Mode**: 
   ```bash
   ducktape
   ```

2. **Direct CLI Commands**:
   ```bash
   ducktape calendar list
   ```

3. **Natural Language via AI Subcommand**:
   ```bash
   ducktape ai "schedule a meeting tomorrow at 10am"
   ```

For more information, see the [main DuckTape repository](https://github.com/ducktapeai/ducktape) or [documentation](https://ducktapeai.com/docs/).

## Versioning

DuckTape follows semantic versioning. The current version is specified in the formula file.

## Contributing

Contributions are welcome! Please follow the guidelines in the [CONTRIBUTING.md](https://github.com/ducktapeai/ducktape/blob/main/CONTRIBUTING.md) file of the main repository.