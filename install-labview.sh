#!/usr/bin/env bash
set -euo pipefail

SAVE_DIR="$PWD"
OUT_DIR="$HOME/Downloads/NI-Downloads"
CLEANUP=false

LV_URL="https://download.ni.com/support/softlib/labview/labview_development_system/2026_Q1/ni-labview-2026-community-26.1.0_linux.zip"
DRIVERS_URL="https://download.ni.com/support/softlib/MasterRepository/LinuxDrivers2026Q1/NILinux2026Q1DeviceDrivers.zip"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] COMMAND

Commands:
    install_all       Install LabVIEW, drivers, and prerequisites
    install_lv        Install LabVIEW Community Edition
    install_drivers   Install NI drivers (VISA, DAQmx)
    prerequisites     Install required system dependencies

Options:
    -h, --help        Show this help message
    --cleanup         Remove downloaded zip files after installation
    --force           Force re-download even if files exist

EOF
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

test -d "$OUT_DIR" || mkdir -p "$OUT_DIR"

cd "$OUT_DIR" || exit

cleanup() {
    cd "$SAVE_DIR" || exit
}
trap cleanup EXIT

prerequisites() {
    sudo nala update
    sudo nala install -y \
        python3 \
        apt-mirror \
        dpkg-dev \
        ttf-mscorefonts-installer \
        fontconfig \
        xfonts-75dpi-transcoded \
        xfonts-100dpi-transcoded
}

get_base_version() {
    # shellcheck disable=SC1091
    . "/etc/os-release"
    case "$UBUNTU_CODENAME" in
    focal) UBUNTU_VERSION="20.04" ;;
    jammy) UBUNTU_VERSION="22.04" ;;
    noble) UBUNTU_VERSION="24.04" ;;
    oracular) UBUNTU_VERSION="24.10" ;;
    plucky) UBUNTU_VERSION="25.04" ;;
    *) UBUNTU_VERSION="unknown" ;;
    esac
    echo $UBUNTU_VERSION
}

install-repo() {
    local url="$1"
    local pkg_type="$2"
    local dest="${3:-"$OUT_DIR"}"
    local version
    local zip_file
    local deb_file
    local -a deb_files

    version=$(get_base_version | sed 's/\.//')
    # Convert version (e.g., "2004", "2204", "2404") to ubuntu format (e.g., "ubuntu2004", "ubuntu2204", "ubuntu2404")
    local ubuntu_ver="ubuntu${version}"

    zip_file="$(basename "$url")"

    test -d "$dest" || mkdir -p "$dest"

    cd "$dest" || return 1

    # Skip download if file exists and --force not set
    if [[ -f "$zip_file" && "${FORCE:-false}" != "true" ]]; then
        echo "Using cached: $zip_file"
    else
        curl --retry 3 --retry-delay 5 -#L "$url" -o "$zip_file"
    fi
    unzip -o "$zip_file"

    # Try to cd into extracted subdirectory (some zips create one, some don't)
    local extracted_dir="${zip_file%.zip}"
    if [[ -d "$extracted_dir" ]]; then
        cd "$extracted_dir" || return 1
    fi

    echo "Searching for .deb files in: $(pwd)"
    echo "Pattern: *labview*${ubuntu_ver}*.deb"

    # Find .deb file based on package type and version
    shopt -s nullglob
    case "$pkg_type" in
        labview)
            # Match patterns like: ni-labview-2026-community_*_ubuntu2404_all.deb
            deb_files=(./*labview*"${ubuntu_ver}"*.deb ./*"${ubuntu_ver}"*labview*.deb)
            ;;
        drivers)
            # Match patterns like: ni-ubuntu2404-drivers-2026Q1.deb
            deb_files=(./*"${ubuntu_ver}"*drivers*.deb ./*drivers*"${ubuntu_ver}"*.deb)
            ;;
        *)
            # Default: match any ubuntu version pattern
            deb_files=(./*"${ubuntu_ver}"*.deb)
            ;;
    esac
    shopt -u nullglob

    if [[ ${#deb_files[@]} -eq 0 ]]; then
        echo -e "Error: No matching .deb file found for ${pkg_type:-package} with ${ubuntu_ver}"; 
        echo "Available .deb files:"
        ls -la ./*.deb 2>/dev/null || true
        return 1
    fi

    # Use the first match (or could prompt user if multiple matches)
    deb_file="${deb_files[0]}"
    echo "Found package: $deb_file"

    if [[ ! -f "$deb_file" ]]; then
        echo -e "Error '$deb_file' does not exist"; 
        return 1
    fi
    sudo nala update
    sudo nala install -y "$deb_file"

    # Cleanup zip files if --cleanup flag is set
    if [[ "$CLEANUP" == "true" ]]; then
        echo "Cleaning up downloaded files..."
        rm -f "$dest/$zip_file"
        rm -f "$dest"/*.deb
    fi

    cd "$dest" || return 1
}

install_lv() {
    local out_dir="${1:-"$OUT_DIR"}"

    install-repo "$LV_URL" "labview" "$out_dir" || return 1

    sudo nala update
    sudo nala install -y \
        ni-labview-2026-desktop \
        ni-labview-vicompare \
        ni-labview-vimerge \
        ni-hwcfg-utility

    sudo dkms autoinstall
}

install_drivers()
{
    local out_dir="${1:-"$OUT_DIR"}"

    install-repo "$DRIVERS_URL" "drivers" "$out_dir" || return 1
    sudo nala update
    sudo nala install -y \
        ni-serial \
        ni-visa \
        ni-daqmx
    
    sudo dkms autoinstall
}

install_all()
{
    echo "=== Installing prerequisites ==="
    prerequisites || return 1

    echo "=== Installing LabVIEW ==="
    install_lv "$@" || return 1

    echo "=== Installing drivers ==="
    install_drivers "$@" || return 1

    echo "=== Installation complete ==="
}


"$@"

