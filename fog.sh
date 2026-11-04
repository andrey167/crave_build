#!/usr/bin/env bash

########################################
# SOURCE SETUP
########################################

echo "==> Initializing repo..."
# AXION AOSP
repo init --depth=1 -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs

# SYNC SOURCE
########################################

echo "==> Syncing source..."
/opt/crave/resync.sh
/opt/crave/resync.sh
/opt/crave/resync.sh



# Device Source
if [ -d "device/xiaomi/fog" ]; then
    echo "==> Removing old device/xiaomi/fog..."
    rm -rf device/xiaomi/fog
fi
mkdir -p device/xiaomi
git clone --depth 1 --branch axion-16.2 https://github.com/Romeo13card/device_xiaomi_fog.git device/xiaomi/fog

# Kernel Source
if [ -d "device/xiaomi/fog-kernel" ]; then
    echo "==> Removing old device/xiaomi/fog-kernel..."
    rm -rf device/xiaomi/fog-kernel
fi
mkdir -p device/xiaoomi/fog-kernel
git clone  --branch neutron https://github.com/Romeo13card/device_xiaomi_fog-kernel.git device/xiaomi/fog-kernel

# Vendor Source
if [ -d "vendor/xiaomi/fog" ]; then
    echo "==> Removing old vendor/xiaomi/fog..."
    rm -rf vendor/xiaomi/fog
fi
mkdir -p vendor/xiaomi
git clone --depth 1 --branch baklava-and-beyond https://github.com/alternoegraha/vendor_xiaomi_fog.git vendor/xiaomi/fog

# Hardware Source
if [ -d "hardware/xiaomi" ]; then
    echo "==> Removing old hardware/xiaomi..."
    rm -rf hardware/xiaomi
fi
mkdir -p hardware
git clone --depth 1 --branch lineage-23.2 https://github.com/LineageOS/android_hardware_xiaomi.git hardware/xiaomi

# DolbyUI
if [ -d "packages/apps/DolbyUI" ]; then
    echo "==> Removing old packages/apps/DolbyUI..."
    rm -rf packages/apps/DolbyUI
fi
git clone https://github.com/swiitch-OFF-Lab/packages_apps_DolbyUI.git packages/apps/DolbyUI -b 16.0 --depth 1

# Dolby
if [ -d "hardware/dolby" ]; then
    echo "==> Removing old hardware/dolby..."
    rm -rf hardware/dolby
fi
git clone https://github.com/swiitch-OFF-Lab/hardware_dolby.git hardware/dolby -b sony-1.5 --depth 1


# MIUI Camera
if [ -d "vendor/xiaomi/camera" ]; then
    echo "==> Removing old vendor/xiaomi/camera..."
    rm -rf vendor/xiaomi/camera
fi
git clone --depth 1 --branch vauxite-sm6225 https://gitlab.com/ThankYouMario/proprietary_vendor_xiaomi_camera vendor/xiaomi/camera




########################################
# BUILD SETUP
########################################

echo "==> Removing old rom zip files..."
rm -f out/target/product/fog/*.zip

echo "==> Preparing environment..."
. build/envsetup.sh

export BUILD_USERNAME=romeo_13card
export BUILD_HOSTNAME=crave
export TZ=Asia/Jakarta
export KBUILD_USERNAME="$BUILD_USERNAME"
export KBUILD_HOSTNAME="$BUILD_HOSTNAME"

gk -s
axionSync

# Apply AxionRu Russian translations
echo "Applying AxionRu translations..."

AXIONRU_URL="https://github.com/andrey167/AxionRu.git"
AXIONRU_DIR="$(pwd)/.axionru_tmp"

rm -rf "$AXIONRU_DIR"
git clone --depth=1 "$AXIONRU_URL" "$AXIONRU_DIR" || {
    echo "ERROR: Failed to clone AxionRu!"
    rm -rf "$AXIONRU_DIR"
    exit 1
}

# Copy translations into Android sources, replacing existing files
cp -af "$AXIONRU_DIR/." "$(pwd)/"

rm -rf "$AXIONRU_DIR"

echo "AxionRu translations applied successfully!"

# omni
if [ -d "packages/services/Omnijaws" ]; then
    echo "==> Removing old packages/services/Omnijaws..."
    rm -rf packages/services/Omnijaws
fi
git clone --depth 1 --branch lineage-23.2 https://github.com/andrey167/android_packages_services_OmniJaws.git packages/services/Omnijaws

echo "==> Lunching target..."
axion fog user va

echo "==> Cleaning previous build outputs..."
m installclean

echo "==> Starting ROM compilation..."
if ! ax -br; then
    echo "=================================================="
    echo "==> ERROR: Compilation failed during 'ax -br'!"
    echo "=================================================="
    exit 1
fi

########################################
# UPLOAD AND CLEANUP
########################################

ZIP_FILE=$(ls -t out/target/product/fog/axion*.zip 2>/dev/null | head -n 1)

if [ -n "$ZIP_FILE" ] && [ -f "$ZIP_FILE" ]; then
    echo "==> Uploading $ZIP_FILE to GoFile..."
    SERVER=""
    for i in {1..3}; do
        SERVER_RESP=$(curl -s https://api.gofile.io/servers)
        SERVER=$(echo "$SERVER_RESP" | grep -o '"name":"[^"]*' | head -n 1 | cut -d'"' -f4)
        [ -n "$SERVER" ] && break
        sleep 3
    done

    UPLOAD_SUCCESS=false
    if [ -n "$SERVER" ]; then
        UPLOAD_RES=$(curl -# -F "file=@$ZIP_FILE" "https://${SERVER}.gofile.io/contents/uploadfile")
        if echo "$UPLOAD_RES" | grep -q '"status":"ok"'; then
            DOWNLOAD_PAGE=$(echo "$UPLOAD_RES" | grep -o '"downloadPage":"[^"]*' | cut -d'"' -f4)
            echo "=================================================="
            echo "GOFILE LINK: $DOWNLOAD_PAGE"
            echo "=================================================="
            UPLOAD_SUCCESS=true
        fi
    fi

    if [ "$UPLOAD_SUCCESS" = false ]; then
        echo "==> FALLBACK: Uploading to Pixeldrain..."
        PD_RESPONSE=$(curl -s -F "file=@$ZIP_FILE" https://pixeldrain.com/api/file/)
        PD_FILE_ID=$(echo "$PD_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
        echo "=================================================="
        echo "PIXELDRAIN LINK: https://pixeldrain.com/u/$PD_FILE_ID"
        echo "=================================================="
    fi
fi
