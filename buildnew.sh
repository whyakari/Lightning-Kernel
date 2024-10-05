#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

SECONDS=0 # builtin bash timer
ZIPNAME="Lean.Kernel-Ginkgo$(TZ=Lima/America date +"%Y%m%d-%H%M").zip"
MAIN=$(readlink -f "$HOME")
AK3_DIR="$HOME/android/AnyKernel3"
DEFCONFIG="vendor/lean-perf_defconfig"

# Comprobar si el compilador clang está presente, si no, descargar ZyC Stable
if [ ! -d "$MAIN/clang" ]; then
    echo "No se encontró el compilador clang... Clonando ZyC Stable desde GitHub"

    # Establecer la URL de ZyC Stable
    CLANG_URL=$(curl -s https://raw.githubusercontent.com/v3kt0r-87/Clang-Stable/main/clang-zyc.txt)
    ARCHIVE_NAME="zyc-clang.tar.gz"
    
    # Descargar ZyC Stable Clang
    echo "Descargando ZyC Clang... Por favor espera..."
    if ! wget -P "$MAIN" "$CLANG_URL" -O "$MAIN/$ARCHIVE_NAME"; then
        echo "Error al descargar Clang. Abortando..."
        exit 1
    fi

    # Crear el directorio clang y extraer el archivo
    mkdir -p "$MAIN/clang"
    if ! tar -xvf "$MAIN/$ARCHIVE_NAME" -C "$MAIN/clang"; then
        echo "Error al extraer Clang. Abortando..."
        exit 1
    fi

    # Eliminar el archivo descargado
    rm -f "$MAIN/$ARCHIVE_NAME"

    # Verificar si el directorio clang se creó correctamente
    if [ ! -d "$MAIN/clang" ]; then
        echo "Error al crear el directorio 'clang'. Abortando..."
        exit 1
    fi
else
    echo "Se encontró el directorio Clang en $MAIN/clang. Omitiendo la descarga."
fi

# Establecer variables de entorno para la compilación
export PATH="$MAIN/clang/bin:$PATH"
export KBUILD_COMPILER_STRING="$("$MAIN/clang/bin/clang" --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

export KBUILD_BUILD_USER="linux"
export KBUILD_BUILD_HOST="LeanHijosdesusMadres"
export KBUILD_BUILD_VERSION="1"

# Establecer CROSS_COMPILE_ARM32 para evitar el error de compilación de vDSO
export CROSS_COMPILE_ARM32="$MAIN/clang/bin/arm-linux-gnueabi-"

if [[ $1 = "-r" || $1 = "--regen" ]]; then
    make O=out ARCH=arm64 $DEFCONFIG savedefconfig
    cp out/defconfig arch/arm64/configs/$DEFCONFIG
    exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
    rm -rf out
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nIniciando compilación...\n"
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
    CLANG_TRIPLE=aarch64-linux-gnu- \
    Image.gz-dtb dtbo.img

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
    echo -e "\nEl kernel se ha compilado correctamente. Empaquetando...\n"
    if [ -d "$AK3_DIR" ]; then
        cp -r $AK3_DIR AnyKernel3
    elif ! git clone -q https://github.com/LeanxModulostk/AnyKernel3; then
        echo -e "\nNo se encontró el repositorio AnyKernel3 localmente y la clonación falló. Abortando..."
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
    echo -e "\nCompletado en $((SECONDS / 60)) minuto(s) y $((SECONDS % 60)) segundo(s)!"
    echo "Zip: $ZIPNAME"
else
    echo -e "\n¡La compilación falló!"
    exit 1
fi
