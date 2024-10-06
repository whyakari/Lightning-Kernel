#!/usr/bin/env bash
#
# Copyright (C) 2023 Edwiin Kusuma Jaya (ryuzenn)
#
# Simple Local Kernel Build Script
#
# Configured for Redmi Note 8 / ginkgo custom kernel source
#
# Setup build env with akhilnarang/scripts repo
#
# Use this script on root of kernel directory

SECONDS=0 # builtin bash timer
ZIPNAME="Lean-Kernel-Ginkgo$(TZ=Lima/America date +"%Y%m%d-%H%M").zip"
CLANG_DIR="$HOME/tc/clang-lean"
GCC_64_DIR="$HOME/tc/aarch64-linux-android-4.9"
GCC_32_DIR="$HOME/tc/arm-linux-androideabi-4.9"
AK3_DIR="$HOME/android/AnyKernel3"
DEFCONFIG="vendor/lean-perf_defconfig"

export PATH="$CLANG_DIR/bin:$PATH"
export KBUILD_BUILD_USER="telegram"
export KBUILD_BUILD_HOST="LeanHijosdesusMadres"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"
export KBUILD_BUILD_VERSION="1"
export LOCALVERSION

# Comprobar si el compilador clang está presente, si no, descargar ZyC Stable
if [ ! -d "${CLANG_DIR}" ]; then
    echo "No se encontró el compilador clang... Clonando ZyC Stable desde GitHub"

    # Establecer la URL de ZyC Stable directamente
    CLANG_URL="https://github.com/ZyCromerZ/Clang/releases/download/16.0.6-20240430-release/Clang-16.0.6-20240430.tar.gz"
    ARCHIVE_NAME="zyc-clang.tar.gz"
    
    # Descargar ZyC Stable Clang
    echo "Descargando ZyC Clang... Por favor espera..."
    if ! wget -P "$HOME" "$CLANG_URL" -O "$HOME/$ARCHIVE_NAME"; then
        echo "Error al descargar Clang. Abortando..."
        exit 1
    fi

    # Crear el directorio clang y extraer el archivo
    mkdir -p "${CLANG_DIR}"
    if ! tar -xvf "$HOME/$ARCHIVE_NAME" -C "${CLANG_DIR}"; then
        echo "Error al extraer Clang. Abortando..."
        exit 1
    fi

    # Eliminar el archivo descargado
    rm -f "$HOME/$ARCHIVE_NAME"

    # Verificar si el directorio clang se creó correctamente
    if [ ! -d "${CLANG_DIR}" ]; then
        echo "Error al crear el directorio 'clang'. Abortando..."
        exit 1
    fi
fi

if ! [ -d "${GCC_64_DIR}" ]; then
    echo "gcc not found! Cloning to ${GCC_64_DIR}..."
    if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git ${GCC_64_DIR}; then
        echo "Cloning failed! Aborting..."
        exit 1
    fi
fi

if ! [ -d "${GCC_32_DIR}" ]; then
    echo "gcc_32 not found! Cloning to ${GCC_32_DIR}..."
    if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git ${GCC_32_DIR}; then
        echo "Cloning failed! Aborting..."
        exit 1
    fi
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      LD=ld.lld \
                      AR=llvm-ar \
                      AS=llvm-as \
                      NM=llvm-nm \
                      OBJCOPY=llvm-objcopy \
                      OBJDUMP=llvm-objdump \
                      STRIP=llvm-strip \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      Image.gz-dtb \
                      dtbo.img

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
    echo -e "\nKernel compiled successfully! Zipping up...\n"
    git restore arch/arm64/configs/vendor/lean-perf_defconfig
    if [ -d "$AK3_DIR" ]; then
        cp -r $AK3_DIR AnyKernel3
    elif ! git clone -q https://github.com/LeanxModulostk/AnyKernel3; then
        echo -e "\nAnyKernel3 repo not found locally and cloning failed! Aborting..."
        exit 1
    fi
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
    cp out/arch/arm64/boot/dtbo.img AnyKernel3
    rm -f *zip
    cd AnyKernel3
    git checkout ginkgo &> /dev/null
    zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
    cd ..
    rm -rf AnyKernel3
    rm -rf out/arch/arm64/boot
    echo -e "LEAN Kernel"
    echo -e "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
    echo "Zip: $ZIPNAME"
else
    echo -e "\nCompilation failed!"
    exit 1
fi