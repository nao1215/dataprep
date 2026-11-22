# Contributing Guide

## Introduction

Thank you for considering contributing to the dataprep project! This document explains how to contribute. We welcome all forms of contributions, including code contributions, documentation improvements, bug reports, and feature suggestions.

## Setting Up Development Environment

### Prerequisites

- [Gleam](https://gleam.run/) 1.14 or later (`.mise.toml` pins the version CI uses for formatting)
- [Erlang/OTP](https://www.erlang.org/) 27 or later
- [just](https://just.systems/) (task runner)
- [mise](https://mise.jdx.dev/) (recommended for managing Gleam and Erlang versions)

### Cloning the Project

```bash
git clone https://github.com/nao1215/dataprep.git
cd dataprep
```

### Installing Tools

```bash
mise install       # install Gleam and Erlang
gleam deps download
```

### Verification

```bash
just ci
```

## Development Workflow

### Branch Strategy

- `main` branch is the latest stable version
- Create new branches from `main` for new features or bug fixes
- Branch naming examples:
  - `feature/add-float-rules` - New feature
  - `fix/issue-123` - Bug fix
  - `docs/update-readme` - Documentation update

### Coding Standards

This project follows these standards:

1. Follow the [Gleam conventions](https://gleam.run/documentation/conventions-patterns-anti-patterns/).
2. Keep the public API small. Everything public lives in the single `dataprep` module; helpers stay private.
3. Write pure functions. The library has no processes and no FFI.
4. Give every public function a doc comment with its behaviour, failure conditions and an example.
5. A validator returns the value it was given unchanged; transformations belong in the caller's code or the standard library.

### Writing Tests

Tests live under `test/` and call the public API.

1. Check short-circuit behaviour with `panic` sentinels.
2. Test boundaries: empty strings, whitespace, zero, negative values and long lists on both targets.

```bash
just test     # run all tests
just check    # format check, typecheck, build, test
```

### Design Boundaries

The following do not belong in this library:

- Domain-specific rules (email, URL, UUID, phone number)
- Decoding of dynamic data such as JSON; use `gleam/dynamic/decode`
- Schema abstractions or string-based DSLs

## Using AI Assistants (LLMs)

We actively encourage the use of AI coding assistants to improve productivity and code quality. Tools like Claude Code, GitHub Copilot, and Cursor are welcome for:

- Writing boilerplate code
- Generating comprehensive test cases
- Improving documentation
- Refactoring existing code

### Guidelines for AI-Assisted Development

1. **Review all generated code**: Always review and understand AI-generated code before committing
2. **Maintain consistency**: Ensure AI-generated code follows our coding standards in CLAUDE.md
3. **Test thoroughly**: AI-generated code must pass `just ci`

## Creating Pull Requests

### Preparation

1. **Check or Create Issues**
   - Check if there are existing issues
   - For major changes, discuss the approach in an issue first

2. **Write Tests**
   - Always add tests for new features
   - For bug fixes, create tests that reproduce the bug

3. **Quality Check**
   ```bash
   just ci
   ```

### Submitting Pull Request

1. Create a Pull Request from your forked repository to the main repository
2. PR title should briefly describe the changes
3. Include the following in PR description:
   - Purpose and content of changes
   - Related issue number (if any)
   - Test method

### About CI/CD

GitHub Actions automatically checks the following items:

- **Format check**: `gleam format --check`
- **Lint**: `gleam build --warnings-as-errors`
- **Build**: `gleam build`
- **Test**: `gleam test`

Merging is not possible unless all checks pass.

## Bug Reports

When you find a bug, please create an issue with the following information:

1. **Environment Information**
   - OS and version
   - Gleam version
   - Erlang/OTP version
   - dataprep version

2. **Reproduction Steps**
   - Minimal code example to reproduce the bug

3. **Expected and Actual Behavior**

4. **Error Messages or Stack Traces** (if any)

## Contributing Outside of Coding

The following activities are also greatly welcomed:

- **Give a GitHub Star**: Show your interest in the project
- **Promote the Project**: Introduce it in blogs, social media, study groups, etc.
- **Become a GitHub Sponsor**: Support available at [https://github.com/sponsors/nao1215](https://github.com/sponsors/nao1215)
- **Documentation Improvements**: Fix typos, improve clarity of explanations
- **Feature Suggestions**: Share new combinator ideas in issues

## License

Contributions to this project are considered to be released under the project's license (MIT License).

---

Thank you again for considering contributing! We sincerely look forward to your participation.
