# AGENTS.md - Agent Guidelines for NI Installer

This file provides guidelines for agents operating in this repository.

## Project Overview

- **Project**: NI LabVIEW Linux Installer
- **Language**: Bash scripts
- **Main script**: `install-labview.sh` - Automates installation of LabVIEW Community Edition and NI drivers on Ubuntu
- **Test framework**: None (manual testing only)
- **Linting**: ShellCheck, MarkdownLint

---

## Build/Lint/Test Commands

### Linting

```bash
# Run shellcheck on all shell scripts
shellcheck install-labview.sh

# Check for bash syntax errors
bash -n install-labview.sh

# Run markdownlint on README
markdownlint README.md
```

### Running a Single Test

There are no automated tests in this project. Test manually by:

```bash
# Dry-run test (script loads but doesn't install)
bash -c 'source install-labview.sh --help'

# Test config loading
bash -c 'source install-labview.sh; echo "VERSION: ${VERSION[year]}"'

# Test specific command parsing
./install-labview.sh --version 2025 --quarter Q2 --edition pro --help
```

### CI Workflows

- **ShellCheck**: Runs on PRs when `.sh` files change
- **MarkdownLint**: Runs on PRs when `.md` files change

---

## Code Style Guidelines

### Shell Script Conventions

1. **Shebang**: Use `#!/usr/bin/env bash`
2. **Error handling**: Always use `set -euo pipefail`
3. **Quotes**: Always quote variables: `"$VAR"` not `$VAR`
4. **Exit codes**: Explicitly handle failures with `|| return 1` or `|| exit 1`

### Naming Conventions

- **Variables**: UPPER_SNAKE_CASE for globals, lower_snake_case for locals
- **Functions**: snake_case (e.g., `load_config`, `check_nala`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `OUT_DIR`, `PKG_MGR`)
- **Config file**: `packages.config` (INI-style format)

### Formatting

- **Indentation**: 4 spaces (no tabs)
- **Line length**: Keep under 100 characters
- **Function placement**: Main logic at bottom, functions defined above
- **Blank lines**: Single blank line between function definitions

### Imports/Dependencies

- **Package manager detection**: Check for `nala` first, fallback to `apt`
- **External tools**: Minimize dependencies; use pure bash where possible
- **Config file loading**: Parse INI-style config with pure bash (no jq/yq)

### Error Handling

- Use `echo "Error: ..." >&2` for errors
- Exit with code 1 on fatal errors
- Validate required config values before operations
- Check file existence before reading/writing

### Config File Format

The project uses a custom INI-style format in `packages.config`:

```ini
[version]
year=2026
quarter=Q1
lv_version=26.1.0
edition=community

[prerequisites]
python3
apt-mirror

[labview]
ni-labview-${year}-desktop
ni-labview-${year}-vicompare

[drivers]
ni-visa
ni-daqmx
```

- Section names in brackets `[section]`
- Package names support `${year}` placeholder substitution
- Lines starting with `#` are comments
- Blank lines are ignored

---

## CLI Interface

The script uses POSIX-style argument parsing:

```bash
./install-labview.sh [OPTIONS] COMMAND

Commands:
    install_all       Install LabVIEW, drivers, and prerequisites
    install_lv        Install LabVIEW Community Edition
    install_drivers   Install NI drivers (VISA, DAQmx)
    prerequisites     Install required system dependencies

Options:
    -h, --help        Show help
    --cleanup         Remove downloaded zip files after installation
    --force           Force re-download even if files exist
    --config FILE     Path to config file
    --version YEAR    Override version year (e.g., 2026)
    --quarter Q#      Override quarter (e.g., Q1)
    --edition EDITION Override edition (community or pro)
```

---

## Working with This Codebase

### Adding New Packages

1. Edit `packages.config` under appropriate section (`[prerequisites]`, `[labview]`, `[drivers]`)
2. Use `${year}` placeholder for year-dependent package names
3. Test: `source install-labview.sh && get_packages <section>`

### Adding New Configuration Options

1. Add to `[version]` section in `packages.config`
2. Parse in `load_config()` function
3. Add CLI argument in argument parsing block
4. Add validation in `validate_config()` if required

### URL Patterns

LabVIEW download URLs follow this pattern:
```
https://download.ni.com/support/softlib/labview/labview_development_system/{YEAR}_{QUARTER}/ni-labview-{YEAR}-{EDITION}-{LV_VERSION}_linux.zip
```

Driver URLs:
```
https://download.ni.com/support/softlib/MasterRepository/LinuxDrivers{YEAR}{QUARTER}/NILinux{YEAR}{QUARTER}DeviceDrivers.zip
```

---

## Common Tasks

### Testing Config Changes
```bash
bash -c 'source install-labview.sh; echo "Packages:"; get_packages prerequisites'
```

### Testing URL Building
```bash
./install-labview.sh --version 2025 --quarter Q2 --edition pro --help
# URLs are built but not displayed; add debug echo to build_urls() to verify
```

### Running Full Lint Suite
```bash
shellcheck install-labview.sh
bash -n install-labview.sh
```

### Git Operations

When creating commits, use the `/commit` skill for proper git workflow:

```bash
# The skill handles:
# - Checking git status, diff, and recent commits
# - Matching repo's commit message style
# - Proper staging and committing
# - Never amending or skipping hooks
```

### Creating Pull Requests

When opening a PR, use the `/create-pr` skill which handles:
- Checking branch status and diff
- Searching for PR templates
- Analyzing commits
- Creating PR with proper title and body

---

## Important Notes

- This is a bash scripts project, not a compiled language
- No automated test suite exists - validate changes manually
- Always run `shellcheck` before committing
- The script requires root/sudo for package installation
- NI download URLs may change; validate with NI documentation