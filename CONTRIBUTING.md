# Contributing to LiteLLM Stack

Thanks for considering contributing! Here's how to help.

## Getting Started

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/your-username/litellm-stack.git`
3. **Create a branch**: `git checkout -b feature/your-feature-name`

## Development Workflow

### Before You Start

Make sure the stack runs on your machine:

```bash
docker compose up -d
make health  # Should show all services healthy
```

### Making Changes

1. **Test locally** before committing

   ```bash
   docker compose up -d
   docker compose logs -f  # Monitor for errors
   ```

2. **Run checks**

   ```bash
   tox -e ruff       # Python linting
   tox -e mypy       # Type checking
   tox -e mdlint     # Markdown linting
   tox -e shellcheck # Shell script validation
   ```

3. **Test Python examples** (if modified)

   ```bash
   pip install -r requirements.txt
   python example/test_openai.py
   ```

### Code Style

- **Python**: Follow PEP 8, enforce via `tox -e ruff`
- **Bash**: Use `tox -e shellcheck` and `tox -e shfmt`
- **Markdown**: Use `tox -e mdlint`
- **Docker**: One service per container, document environment variables

### Commit Messages

Use clear, imperative commit messages:

```
Good:
fix: Handle GPU memory errors gracefully
feat: Add Claude model routing support
docs: Update README with new examples

Avoid:
Fixed stuff
Updated code
WIP
```

## What to Contribute

### Good PR Ideas

- Bug fixes with test cases
- Documentation improvements
- Performance optimizations
- New model support (with examples)
- Shell/Python script improvements
- Hardware-specific setup guides

### Not Accepting

- Personal environment configs
- Non-reproducible issues without minimal test case
- Changes that break existing behavior without migration path

## Pull Request Process

1. **Update** README.md if you change user-facing behavior
2. **Add tests** if applicable
3. **Clean up** before submitting (run linters)
4. **Describe** what your PR does, why it's needed
5. **Reference** any related issues

Example PR description:

```
## Summary
Fixes GPU layer auto-detection for RTX 40 series cards

## Testing
- Tested on RTX 4080
- docker compose up && make health (all green)
- python example/test_openai.py (successful)

## Changes
- Updated OLLAMA_NUM_GPU detection in setup_models.sh
- Added layer count mapping for newer GPU architectures
```

## Questions?

- Check existing GitHub issues
- Start a discussion if unsure
- Test locally first (saves review cycles)

Thanks for contributing! 🚀
