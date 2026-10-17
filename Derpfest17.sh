#!/usr/bin/env bash

########################################
# SOURCE SETUP
########################################

echo "==> Initializing repo..."
# DerpFest AOSP
repo init --depth=1 -u https://github.com/DerpFest-AOSP/android_manifest.git -b 17 --git-lfs

# SYNC SOURCE
########################################

echo "==> Syncing source..."
/opt/crave/resync.sh
/opt/crave/resync.sh
/opt/crave/resync.sh



# Device Source
if [ -d "device/xiaomi/platina" ]; then
    echo "==> Removing old device/xiaomi/platina..."
    rm -rf device/xiaomi/platina
fi
mkdir -p device/xiaomi
git clone --depth 1 --branch Derpfest https://github.com/andrey167/android_device_xiaomi_platina.git device/xiaomi/platina

# Kernel Source
if [ -d "kernel/xiaomi/sdm660" ]; then
    echo "==> Removing old kernel/xiaomi/sdm660..."
    rm -rf kernel/xiaomi/sdm660
fi
mkdir -p kernel/xiaomi
git clone --depth 1 --branch Platinum https://github.com/andrey167/kernel_xiaomi_platinum.git kernel/xiaomi/sdm660
# KernelSu-next
(cd kernel/xiaomi/sdm660 && rm -rf KernelSU && curl -LSs "https://raw.githubusercontent.com/andrey167/KernelSU/refs/heads/main-susfs/kernel/setup.sh" | bash -s main-susfs)

# Vendor Source
if [ -d "vendor/xiaomi/platina" ]; then
    echo "==> Removing old vendor/xiaomi/platina..."
    rm -rf vendor/xiaomi/platina
fi
mkdir -p vendor/xiaomi
git clone --depth 1 --branch Platina https://github.com/andrey167/android_vendor_xiaomi_platina.git vendor/xiaomi/platina

# Hardware Source
if [ -d "hardware/xiaomi" ]; then
    echo "==> Removing old hardware/xiaomi..."
    rm -rf hardware/xiaomi
fi
mkdir -p hardware
git clone --depth 1 --branch lineage-23.2 https://github.com/LineageOS/android_hardware_xiaomi.git hardware/xiaomi

# Dolby
if [ -d "hardware/dolby" ]; then
    echo "==> Removing old hardware/dolby..."
    rm -rf hardware/dolby
fi
git clone https://github.com/andrey167/hardware_dolby hardware/dolby 

# Soong
if [ -d "build/soong" ]; then
    echo "==> Removing old build/soong..."
    rm -rf build/soong
fi
git clone https://github.com/andrey167/android_build_soong.git build/soong



# 1. hardware/qcom-caf/common
if [ -d "hardware/qcom-caf/common" ]; then
    echo "==> Removing existing hardware/qcom-caf/common..."
    rm -rf hardware/qcom-caf/common
fi

echo "==> Cloning hardware/qcom-caf/common..."
git clone --depth 1 --branch lineage-23.2 \
    https://github.com/LineageOS/android_hardware_qcom-caf_common.git \
    hardware/qcom-caf/common

# 2. Создаём корневой каталог msm8998
mkdir -p hardware/qcom-caf/msm8998

# 3. msm8998 audio
if [ -d "hardware/qcom-caf/msm8998/audio" ]; then
    echo "==> Removing existing msm8998/audio..."
    rm -rf hardware/qcom-caf/msm8998/audio
fi

echo "==> Cloning msm8998/audio..."
git clone --depth 1 --branch lineage-23.2-caf-msm8998 \
    https://github.com/LineageOS/android_hardware_qcom_audio.git \
    hardware/qcom-caf/msm8998/audio

# 4. msm8998 display
if [ -d "hardware/qcom-caf/msm8998/display" ]; then
    echo "==> Removing existing msm8998/display..."
    rm -rf hardware/qcom-caf/msm8998/display
fi

echo "==> Cloning msm8998/display..."
git clone --depth 1 --branch lineage-23.2-caf-msm8998 \
    https://github.com/LineageOS/android_hardware_qcom_display.git \
    hardware/qcom-caf/msm8998/display

# 5. msm8998 media
if [ -d "hardware/qcom-caf/msm8998/media" ]; then
    echo "==> Removing existing msm8998/media..."
    rm -rf hardware/qcom-caf/msm8998/media
fi

echo "==> Cloning msm8998/media..."
git clone --depth 1 --branch lineage-23.2-caf-msm8998 \
    https://github.com/LineageOS/android_hardware_qcom_media.git \
    hardware/qcom-caf/msm8998/media


echo
echo "==> MSM8998 repositories cloned successfully!"
echo "==> Repository status:"

git -C hardware/qcom-caf/common branch --show-current
git -C hardware/qcom-caf/msm8998/audio branch --show-current
git -C hardware/qcom-caf/msm8998/display branch --show-current
git -C hardware/qcom-caf/msm8998/media branch --show-current


mkdir -p hardware/qcom-caf/msm8998

if [ ! -f hardware/qcom-caf/common/os_pickup.bp ]; then
    echo "ERROR: common/os_pickup.bp not found"
    exit 1
fi

rm -f hardware/qcom-caf/msm8998/Android.bp

ln -s ../common/os_pickup.bp \
    hardware/qcom-caf/msm8998/Android.bp

test -f hardware/qcom-caf/msm8998/Android.bp
echo
echo "==> Done."


########################################
# BUILD SETUP
########################################

echo "==> Removing old rom zip files..."
rm -f out/target/product/platina/DerpFest*.zip
rm -f out/target/product/platina/*.zip


echo "==> Preparing environment..."
. build/envsetup.sh

export BUILD_USERNAME=andrey
export BUILD_HOSTNAME=crave
export TZ=Asia/Jakarta
export KBUILD_USERNAME="$BUILD_USERNAME"
export KBUILD_HOSTNAME="$BUILD_HOSTNAME"

#keys
git clone https://github.com/andrey167/platinakeys vendor/evolution-priv/keys

grep -q "vendor/evolution-priv/keys/keys.mk" device/xiaomi/platina/BoardConfig.mk || sed -i '$ a -include vendor/evolution-priv/keys/keys.mk' device/xiaomi/platina/lineage_platina.mk
#sed -i 's/PRODUCT_CERTIFICATE_OVERRIDES/PRODUCT_PACKAGE_NAME_OVERRIDES/g' vendor/evolution-priv/keys/keys.mk
tail -5 device/xiaomi/platina/lineage_platina.mk

echo "==> Lunching target..."
lunch lineage_platina-cp2a-user

echo "==> Cleaning previous build outputs..."
m installclean

echo "==> Starting ROM compilation..."
if ! m derp; then
    echo "=================================================="
    echo "==> ERROR: Compilation failed during 'm derp!"
    echo "=================================================="
    exit 1
fi

########################################
# UPLOAD AND CLEANUP
########################################

ZIP_FILE=$(ls -t out/target/product/platina/DerpFest*.zip 2>/dev/null | head -n 1)

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
