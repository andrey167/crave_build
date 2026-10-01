#!/usr/bin/env bash

########################################
# SOURCE SETUP
########################################

echo "==> Resetting manifests..."
rm -rf .repo/local_manifests

echo "==> Initializing repo..."
repo init -u https://github.com/Evolution-X/manifest -b vic --depth=1 --git-lfs
git clone https://github.com/andrey167/crave_local_manifests -b evox .repo/local_manifests


#  Device Tree
if [ -d "device/xiaomi/platina" ]; then
    echo "==> Removing existing device/xiaomi/platina..."
    rm -rf device/xiaomi/platina
fi
git clone --depth 1 --branch evox https://github.com/andrey167/android_device_xiaomi_platina_evox device/xiaomi/platina

#  Kernel Source
if [ -d "kernel/xiaomi/platina" ]; then
    echo "==> Removing existing kernel/xiaomi/platina..."
    rm -rf kernel/xiaomi/platina
fi
git clone --depth 1 --branch non-ksub https://github.com/andrey167/platinum_kernel_xiaomi_platina kernel/xiaomi/platina

#  Vendor
if [ -d "vendor/xiaomi/platina" ]; then
    echo "==> Removing existing vendor/xiaomi/platina..."
    rm -rf vendor/xiaomi/platina
fi
git clone --depth 1 --branch lineage-22.2 https://github.com/LineageOS-platina/android_vendor_xiaomi_platina vendor/xiaomi/platina

#  ViPER4AndroidFX
if [ -d "packages/apps/ViPER4AndroidFX" ]; then
    echo "==> Removing existing packages/apps/ViPER4AndroidFX..."
    rm -rf packages/apps/ViPER4AndroidFX
fi
git clone --branch vic https://github.com/andrey167/packages_apps_ViPER4AndroidFX packages/apps/ViPER4AndroidFX

#  Hardware Xiaomi
if [ -d "hardware/xiaomi" ]; then
    echo "==> Removing existing hardware/xiaomi..."
    rm -rf hardware/xiaomi
fi
git clone --depth 1 --branch lineage-22.2 https://github.com/LineageOS/android_hardware_xiaomi hardware/xiaomi

########################################
# SYNC SOURCE
########################################

echo "==> Syncing source..."
/opt/crave/resync.sh
/opt/crave/resync.sh
/opt/crave/resync.sh

########################################
# BUILD SETUP
########################################

echo "==> Removing old rom zip files..."
rm -f out/target/product/platina/EvolutionX*.zip
rm -f out/target/product/platina/*.zip

echo "==> Preparing environment..."
. build/envsetup.sh

export BUILD_USERNAME=andrey
export BUILD_HOSTNAME=crave
export TZ=Asia/Jakarta
export KBUILD_USERNAME="$BUILD_USERNAME"
export KBUILD_HOSTNAME="$BUILD_HOSTNAME"

sed -i 's/tm.getModemService()/""/g' \
packages/services/Telephony/src/com/android/phone/CarrierConfigLoader.java
grep -n "modemService" packages/services/Telephony/src/com/android/phone/CarrierConfigLoader.java

git clone https://github.com/andrey167/platinakeys vendor/evolution-priv/keys

grep -q "vendor/evolution-priv/keys/keys.mk" device/xiaomi/platina/BoardConfig.mk || sed -i '$ a -include vendor/evolution-priv/keys/keys.mk' device/xiaomi/platina/lineage_platina.mk
#sed -i 's/PRODUCT_CERTIFICATE_OVERRIDES/PRODUCT_PACKAGE_NAME_OVERRIDES/g' vendor/evolution-priv/keys/keys.mk
tail -5 device/xiaomi/platina/lineage_platina.mk

echo "==> Lunching target..."
lunch lineage_platina-bp1a-userdebug

echo "==> Cleaning previous build outputs..."
m installclean

echo "==> Starting ROM compilation..."
if ! m evolution; then
    echo "=================================================="
    echo "==> ERROR: Compilation failed during 'm evolution'!"
    echo "=================================================="
    exit 1
fi

########################################
# UPLOAD AND CLEANUP
########################################

ZIP_FILE=$(ls -t out/target/product/platina/EvolutionX*.zip 2>/dev/null | head -n 1)

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
            echo "GOFILE VANILLA LINK: $DOWNLOAD_PAGE"
            echo "=================================================="
            UPLOAD_SUCCESS=true
        fi
    fi

    if [ "$UPLOAD_SUCCESS" = false ]; then
        echo "==> FALLBACK: Uploading to Pixeldrain..."
        PD_RESPONSE=$(curl -s -F "file=@$ZIP_FILE" https://pixeldrain.com/api/file/)
        PD_FILE_ID=$(echo "$PD_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
        echo "=================================================="
        echo "PIXELDRAIN VANILLA LINK: https://pixeldrain.com/u/$PD_FILE_ID"
        echo "=================================================="
    fi
fi
