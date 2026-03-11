# NI LabVIEW Linux Installer

A bash script for automating the installation of LabVIEW Community Edition and NI hardware drivers on Linux (Ubuntu-based distributions).

## Overview

This project provides an automated way to install:
- **LabVIEW Community Edition 2026** (version 26.1.0)
- **NI Drivers** including VISA, DAQmx, and various device drivers

## Supported Ubuntu Versions

- Ubuntu 20.04 (Focal)
- Ubuntu 22.04 (Jammy)
- Ubuntu 24.04 (Noble)
- Ubuntu 24.10 (Oracular)
- Ubuntu 25.04 (Plucky)

## Prerequisites

- Ubuntu-based Linux distribution
- `nala` package manager (the script will install it as a prerequisite)
- Root/sudo access
- Internet connection for downloading packages from NI

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/gdellis/labview-linux-install.git
cd labview-linux-install
```

### 2. Run the installer

#### Install everything (LabVIEW + drivers + prerequisites)

```bash
./install-labview.sh install_all
```

#### Install only prerequisites

```bash
./install-labview.sh prerequisites
```

#### Install only LabVIEW

```bash
./install-labview.sh install_lv
```

#### Install only drivers

```bash
./install-labview.sh install_drivers
```

## Command Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `--cleanup` | Remove downloaded zip files after installation |
| `--force` | Force re-download even if files exist |

## Downloaded Files

By default, downloaded files are stored in:
```
~/Downloads/NI-Downloads/
```

This includes:
- LabVIEW installation zip
- NI Linux Device Drivers zip

## What Gets Installed

### LabVIEW Packages
- ni-labview-2026-desktop
- ni-labview-vicompare
- ni-labview-vimerge
- ni-hwcfg-utility

### Driver Packages (partial list)
- ni-visa - NI-VISA runtime
- ni-daqmx - NI-DAQmx
- ni-serial - NI-Serial
- And 500+ additional NI packages

## Usage Examples

### Full installation with cleanup

```bash
./install-labview.sh --cleanup install_all
```

### Reinstall with fresh downloads

```bash
./install-labview.sh --force install_all
```

## Troubleshooting

### Package not found errors

If you encounter "package not found" errors, ensure:
1. Your Ubuntu version is supported (20.04+)
2. You have an active internet connection
3. The NI download servers are accessible

### DKMS errors

After installation, run:
```bash
sudo dkms autoinstall
```

### For more help

Visit: https://www.ni.com/en/support/downloads.html

## License

This is a community project. LabVIEW installation requires acceptance of NI's license terms.

## Credits

- Original project: https://github.com/gdellis/labview-linux-install
- LabVIEW is a trademark of National Instruments (NI)