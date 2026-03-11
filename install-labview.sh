#!/usr/bin/env bash
set -euo pipefail

SAVE_DIR="$PWD"
OUT_DIR="$HOME/Downloads/NI-Downloads"
CLEANUP=false
FORCE=false
CONFIG_FILE="./packages.config"
PKG_MGR="nala"

CMD_VERSION=""
CMD_QUARTER=""
CMD_EDITION=""

declare -A PACKAGES
declare -A VERSION

LV_URL=""
DRIVERS_URL=""

load_config() {
	local config_path="$1"
	if [[ ! -f "$config_path" ]]; then
		echo "Error: Config file not found: $config_path"
		exit 1
	fi

	local current_section=""
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line#"${line%%[![:space:]]*}"}"

		[[ -z "$line" || "$line" =~ ^# ]] && continue

		if [[ "$line" =~ ^\[([a-z]+)\]$ ]]; then
			current_section="${BASH_REMATCH[1]}"
			continue
		fi

		if [[ -z "$current_section" ]]; then
			continue
		fi

		if [[ "$current_section" == "version" ]]; then
			if [[ "$line" =~ ^([a-z_]+)=(.+)$ ]]; then
				VERSION["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
			fi
		elif [[ "$line" =~ ^[a-z0-9.+-]+\$ ]]; then
			PACKAGES["${current_section}_${line}"]=1
		elif [[ "$line" =~ ^[a-z0-9.+-]+$ ]]; then
			PACKAGES["${current_section}_${line}"]=1
		fi
	done <"$config_path"
}

validate_config() {
	local missing=()

	[[ -z "${VERSION[year]:-}" ]] && missing+=("version.year")
	[[ -z "${VERSION[quarter]:-}" ]] && missing+=("version.quarter")
	[[ -z "${VERSION[lv_version]:-}" ]] && missing+=("version.lv_version")
	[[ -z "${VERSION[edition]:-}" ]] && missing+=("version.edition")

	if [[ ${#missing[@]} -gt 0 ]]; then
		echo "Error: Missing required configuration values:"
		for m in "${missing[@]}"; do
			echo "  - $m"
		done
		exit 1
	fi

	local edition="${VERSION[edition]}"
	if [[ "$edition" != "community" && "$edition" != "pro" ]]; then
		echo "Error: Invalid edition '$edition'. Must be 'community' or 'pro'"
		exit 1
	fi

	local quarter="${VERSION[quarter]}"
	if [[ "$quarter" != "Q1" && "$quarter" != "Q2" && "$quarter" != "Q3" && "$quarter" != "Q4" ]]; then
		echo "Error: Invalid quarter '$quarter'. Must be Q1, Q2, Q3, or Q4"
		exit 1
	fi
}

build_urls() {
	local year="${VERSION[year]}"
	local quarter="${VERSION[quarter]}"
	local lv_version="${VERSION[lv_version]}"
	local edition="${VERSION[edition]}"

	LV_URL="https://download.ni.com/support/softlib/labview/labview_development_system/${year}_${quarter}/ni-labview-${year}-${edition}-${lv_version}_linux.zip"
	DRIVERS_URL="https://download.ni.com/support/softlib/MasterRepository/LinuxDrivers${year}${quarter}/NILinux${year}${quarter}DeviceDrivers.zip"

	if [[ ! "$LV_URL" =~ ^https://.*\.zip$ ]]; then
		echo "Error: Malformed LabVIEW URL: $LV_URL"
		exit 1
	fi

	if [[ ! "$DRIVERS_URL" =~ ^https://.*\.zip$ ]]; then
		echo "Error: Malformed drivers URL: $DRIVERS_URL"
		exit 1
	fi
}

substitute_vars() {
	local input="$1"
	local year="${VERSION[year]}"
	local quarter="${VERSION[quarter]}"
	local lv_version="${VERSION[lv_version]}"
	local edition="${VERSION[edition]}"

	input="${input//\$\{year\}/$year}"
	input="${input//\$\{quarter\}/$quarter}"
	input="${input//\$\{lv_version\}/$lv_version}"
	input="${input//\$\{edition\}/$edition}"

	echo "$input"
}

get_packages() {
	local section="$1"
	local pkg
	local prefix="${section}_"
	for pkg in "${!PACKAGES[@]}"; do
		if [[ "$pkg" == "$prefix"* ]]; then
			local pkg_name="${pkg#"$prefix"}"
			pkg_name=$(substitute_vars "$pkg_name")
			echo "$pkg_name"
		fi
	done | sort
}

check_nala() {
	if command -v nala &>/dev/null; then
		PKG_MGR="nala"
		return 0
	fi

	echo "nala not found. Checking for apt..."

	if ! command -v apt &>/dev/null; then
		echo "Error: Neither nala nor apt is available"
		exit 1
	fi

	echo "nala not installed. Would you like to install it? [Y/n]"
	read -r response || response="y"
	if [[ "$response" =~ ^[Yy]$ || -z "$response" ]]; then
		echo "Installing nala..."
		if sudo apt update && sudo apt install -y nala; then
			PKG_MGR="nala"
			echo "nala installed successfully"
			return 0
		fi
		echo "Failed to install nala, falling back to apt"
	fi

	echo "Using apt as package manager (nala not available)"
	PKG_MGR="apt"
	return 0
}

install_packages() {
	local -a pkgs=("$@")
	if [[ ${#pkgs[@]} -eq 0 ]]; then
		return 0
	fi

	if [[ "$PKG_MGR" == "nala" ]]; then
		sudo nala update
		sudo nala install -y "${pkgs[@]}"
	else
		sudo apt update
		sudo apt install -y "${pkgs[@]}"
	fi
}

show_help() {
	cat <<EOF
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
    --config FILE     Path to config file (default: ./packages.config)
    --version YEAR    LabVIEW year (e.g., 2026)
    --quarter Q#      Quarter (e.g., Q1)
    --edition EDITION Edition (community or pro)

EOF
}

# Parse command line options
while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
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
	--config)
		CONFIG_FILE="$2"
		shift 2
		;;
	--version)
		CMD_VERSION="$2"
		shift 2
		;;
	--quarter)
		CMD_QUARTER="$2"
		shift 2
		;;
	--edition)
		CMD_EDITION="$2"
		shift 2
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

check_nala

if [[ "$CONFIG_FILE" != /* ]]; then
	CONFIG_FILE="$(dirname "$0")/$CONFIG_FILE"
fi

load_config "$CONFIG_FILE"
validate_config

if [[ -n "$CMD_VERSION" ]]; then
	VERSION[year]="$CMD_VERSION"
fi
if [[ -n "$CMD_QUARTER" ]]; then
	VERSION[quarter]="$CMD_QUARTER"
fi
if [[ -n "$CMD_EDITION" ]]; then
	VERSION[edition]="$CMD_EDITION"
fi

validate_config
build_urls

test -d "$OUT_DIR" || mkdir -p "$OUT_DIR"

cd "$OUT_DIR" || exit

cleanup() {
	cd "$SAVE_DIR" || exit
}
trap cleanup EXIT

prerequisites() {
	local -a pkgs
	mapfile -t pkgs < <(get_packages "prerequisites")
	install_packages "${pkgs[@]}"
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
		echo -e "Error: No matching .deb file found for ${pkg_type:-package} with ${ubuntu_ver}"
		echo "Available .deb files:"
		ls -la ./*.deb 2>/dev/null || true
		return 1
	fi

	# Use the first match (or could prompt user if multiple matches)
	deb_file="${deb_files[0]}"
	echo "Found package: $deb_file"

	if [[ ! -f "$deb_file" ]]; then
		echo -e "Error '$deb_file' does not exist"
		return 1
	fi

	if [[ "$PKG_MGR" == "nala" ]]; then
		sudo nala update
		sudo nala install -y "$deb_file"
	else
		sudo apt update
		sudo apt install -y "$deb_file"
	fi

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
	local -a pkgs

	install-repo "$LV_URL" "labview" "$out_dir" || return 1

	mapfile -t pkgs < <(get_packages "labview")
	install_packages "${pkgs[@]}"

	sudo dkms autoinstall
}

install_drivers() {
	local out_dir="${1:-"$OUT_DIR"}"
	local -a pkgs

	install-repo "$DRIVERS_URL" "drivers" "$out_dir" || return 1
	mapfile -t pkgs < <(get_packages "drivers")
	install_packages "${pkgs[@]}"

	sudo dkms autoinstall
}

install_all() {
	echo "=== Installing prerequisites ==="
	prerequisites || return 1

	echo "=== Installing LabVIEW ==="
	install_lv "$@" || return 1

	echo "=== Installing drivers ==="
	install_drivers "$@" || return 1

	echo "=== Installation complete ==="
}

"$@"
