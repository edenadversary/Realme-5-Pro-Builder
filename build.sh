SECONDS=0
ZIPNAME="TLWAT-RUI2-$(date '+%Y%m%d-%H%M').zip"

[ $USE_PERSONAL_DEFCONFIG = "true" ] && DEFCONFIG="godspeed_suki_defconfig"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

if ! [ -d "$HOME/clang" ]; then
echo "- Toolchains not found! Fetching..."
aria2c https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/llvm-r450784/clang-r437112b.tar.gz
mkdir $HOME/clang
tar -xf *.tar.gz -C $HOME/clang
rm -rf *.tar.gz
fi

[ ! -d "$HOME/gcc64" ] && git clone --depth=1 https://github.com/radcolor/aarch64-linux-gnu $HOME/gcc64
[ ! -d "$HOME/gcc32" ] && git clone --depth=1 https://github.com/radcolor/arm-linux-gnueabi $HOME/gcc32

export PATH="$HOME/clang/bin:$HOME/gcc64/bin:$HOME/gcc32/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/clang/lib"

USER="Opeth"
HOSTNAME="Perdition"

export BUILD_USERNAME=$USER
export BUILD_HOSTNAME=$HOSTNAME
export KBUILD_BUILD_USER=$USER
export KBUILD_BUILD_HOST=$HOSTNAME

export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
export CROSS_COMPILE_COMPAT=$CROSS_COMPILE_ARM32

BUILD_FLAGS="
O=out
ARCH=arm64
CC=clang
LD=ld.lld
AR=llvm-ar
AS=llvm-as
NM=llvm-nm
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump
STRIP=llvm-strip
CLANG_TRIPLE=$CROSS_COMPILE
"

if [[ $1 = "-r" || $1 = "--regen" ]]; then
mkdir out
make $(echo $BUILD_FLAGS) $DEFCONFIG
cp out/.config arch/arm64/configs/$DEFCONFIG
rm -rf out
echo -e "\nRegened defconfig succesfully!"
exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
echo -e "\nClean build!"
rm -rf out
fi

mkdir -p out
make $(echo $BUILD_FLAGS) $DEFCONFIG -j$(nproc --all)

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) $(echo $BUILD_FLAGS) Image.gz-dtb

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
git clone -q https://github.com/edenadversary/AnyKernel3-eden --single-branch
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3-eden
cd AnyKernel3-eden
sed -i "s/BLOCK=.*/BLOCK=\/dev\/block\/bootdevice\/by-name\/boot;/" "anykernel.sh"
zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
cd ..
if [ "$DO_CLEAN" = "true" ]; then 
rm -rf AnyKernel3-eden out/arch/arm64/boot
fi
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"
else
echo -e "\nCompilation failed!"
fi
