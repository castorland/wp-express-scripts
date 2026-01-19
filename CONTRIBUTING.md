# Contributing to WP Express Scripts

Thank you for your interest in contributing! This guide will help you get started.

## 📋 Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Commit Messages](#commit-messages)
- [Pull Requests](#pull-requests)

## 🚀 Getting Started

### Prerequisites

- Git
- Bash shell
- Docker & Docker Compose
- Composer
- Basic understanding of WordPress and Bedrock

### Setup

1. **Clone the repository**
   ```bash
   cd "WP Express/scripts"
   git status  # Should show this is a git repo
   ```

2. **Review existing documentation**
   - Read `README.md`
   - Check `NEW-PROJECT-USAGE.md`
   - Review `TROUBLESHOOTING.md`

3. **Test the current script**
   ```bash
   ./new-project.sh test-contribution --use-localhost
   ```

## 🔄 Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/descriptive-name
# or
git checkout -b fix/issue-description
# or
git checkout -b docs/documentation-update
```

Branch naming conventions:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions
- `chore/` - Maintenance tasks

### 2. Make Your Changes

- Keep changes focused and atomic
- Test thoroughly on both architectures if possible (Apple Silicon & Intel)
- Update documentation as needed
- Add comments for complex logic

### 3. Test Your Changes

```bash
# Test basic functionality
./new-project.sh test-feature --use-localhost

# Test HTTPS mode
./new-project.sh test-https

# Test with Redis
./new-project.sh test-redis --redis

# Test error handling
./new-project.sh test-errors --domain invalid@domain
```

### 4. Commit Your Changes

```bash
git add .
git commit -m "feat: add support for custom SSL certificates"
```

See [Commit Messages](#commit-messages) for conventions.

### 5. Push and Create PR

```bash
git push origin feature/descriptive-name
```

Then create a Pull Request on GitHub/GitLab.

## 📝 Coding Standards

### Bash Style Guide

**File Structure:**
```bash
#!/bin/bash
set -eo pipefail

# Configuration
CONSTANT="value"

# Functions
function_name() {
    local var="value"
    # ... function code
}

# Main Script
# ... main code
```

**Naming Conventions:**
- Variables: `lowercase_with_underscores` or `UPPERCASE_CONSTANTS`
- Functions: `lowercase_with_underscores`
- Use descriptive names

**Best Practices:**
```bash
# ✅ Good
if [ -f "$file" ]; then
    echo "File exists"
fi

# ✅ Good - use quotes
local domain="${CLIENT_NAME}.local"

# ✅ Good - check exit codes
if docker-compose up -d; then
    print_success "Started"
else
    print_error "Failed"
    exit 1
fi

# ❌ Bad - unquoted variables
if [ -f $file ]; then
    echo File exists
fi

# ❌ Bad - not checking exit codes
docker-compose up -d
print_success "Started"
```

**Error Handling:**
```bash
# Always use set -eo pipefail
set -eo pipefail

# Check for required commands
command -v docker >/dev/null 2>&1 || {
    echo "Docker is required"
    exit 1
}

# Validate user input
if [ -z "$CLIENT_NAME" ]; then
    print_error "Client name is required"
    exit 1
fi
```

**Output:**
```bash
# Use helper functions
print_success "Operation successful"
print_error "Operation failed"
print_warning "This is a warning"
print_info "Informational message"

# Use progress indicators
print_header "Step 1/5: Cloning Repository"
```

## 🧪 Testing

### Manual Testing Checklist

Before submitting a PR, test these scenarios:

- [ ] **Basic creation**: `./new-project.sh test-basic`
- [ ] **With Redis**: `./new-project.sh test-redis --redis`
- [ ] **Localhost mode**: `./new-project.sh test-local --use-localhost`
- [ ] **Custom domain**: `./new-project.sh test-custom --domain custom.test`
- [ ] **Custom port**: `./new-project.sh test-port --port 8080`
- [ ] **No install**: `./new-project.sh test-no-install --no-install`
- [ ] **No start**: `./new-project.sh test-no-start --no-start`
- [ ] **Error handling**: Test with invalid inputs
- [ ] **Cleanup**: Ensure proper cleanup on failure

### Test on Both Architectures

If possible, test on:
- [ ] Apple Silicon (M1/M2/M3)
- [ ] Intel (x86_64)

### Clean Up Test Projects

```bash
# Stop and remove test projects
cd ../clients/test-*
docker-compose down -v
cd ../..
rm -rf clients/test-*

# Remove from hosts file
sudo sed -i.bak '/test-.*.local/d' /etc/hosts
```

## 💬 Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, no logic change)
- **refactor**: Code refactoring
- **test**: Test additions or changes
- **chore**: Maintenance tasks

### Examples

```bash
# Feature
git commit -m "feat: add support for custom SSL certificates"

# Bug fix
git commit -m "fix: resolve WP-CLI path issue in containers"

# Documentation
git commit -m "docs: update installation requirements"

# With body
git commit -m "feat: add multi-site support

- Add --multisite flag
- Configure wp-config.php for multisite
- Update documentation

Closes #123"
```

### Scope (Optional)

```bash
git commit -m "feat(ssl): add Let's Encrypt support"
git commit -m "fix(docker): correct port mapping for HTTPS"
git commit -m "docs(readme): add troubleshooting section"
```

## 🔀 Pull Requests

### PR Title

Use the same format as commit messages:
```
feat: add support for custom SSL certificates
fix: resolve database connection timeout
docs: improve installation guide
```

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Documentation update
- [ ] Refactoring
- [ ] Other (please describe)

## Testing
- [ ] Tested on Apple Silicon
- [ ] Tested on Intel
- [ ] Tested with Redis
- [ ] Tested error handling
- [ ] Updated documentation

## Screenshots (if applicable)
Add screenshots or terminal output

## Related Issues
Closes #123
Related to #456

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Tests pass
```

### PR Review Process

1. **Self-review**: Review your own changes before requesting review
2. **Documentation**: Ensure all documentation is updated
3. **Testing**: Provide test results
4. **Respond to feedback**: Address review comments promptly
5. **Merge**: Maintainer will merge after approval

## 🐛 Reporting Bugs

### Bug Report Template

```markdown
## Description
Clear description of the bug

## Steps to Reproduce
1. Run command: `./new-project.sh test --redis`
2. See error at step X
3. ...

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- OS: macOS Sonoma 14.2
- Architecture: Apple Silicon M2
- Docker version: 24.0.7
- Composer version: 2.6.5

## Error Messages
```
Paste error messages here
```

## Additional Context
Any other relevant information
```

## 💡 Suggesting Features

### Feature Request Template

```markdown
## Feature Description
Clear description of the feature

## Problem it Solves
What problem does this solve?

## Proposed Solution
How would you implement this?

## Alternatives Considered
What other approaches did you consider?

## Additional Context
Any mockups, examples, or references
```

## 📞 Getting Help

- Check existing documentation first
- Search for similar issues
- Ask in team chat
- Create a GitHub issue

## 🎯 Development Tips

### Debugging

```bash
# Enable verbose output
set -x

# Test individual functions
source new-project.sh
generate_salts  # Test function directly

# Check syntax
bash -n new-project.sh

# Use echo for debugging
echo "DEBUG: CLIENT_NAME=${CLIENT_NAME}"
```

### Common Pitfalls

1. **Unquoted variables** - Always quote: `"${VAR}"`
2. **Not checking exit codes** - Use `if cmd; then` or `cmd || exit 1`
3. **Local outside functions** - Use `local` only inside functions
4. **Path issues** - Always use full paths or `cd` properly
5. **Testing on one architecture** - Test on both if possible

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for contributing to WP Express!** 🚀
