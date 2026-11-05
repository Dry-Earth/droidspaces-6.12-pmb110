#!/bin/bash
# 在 DDK 容器里用“目标机器真实 config”编出与 stock 内核一致的 KDIR。
# KDIR = /work/kernel/out，后面编 LKM 时直接用它。
set -euxo pipefail

if [ "${USE_STOCK_CLANG:-0}" = "1" ] && [ -x /work/clang-stock/bin/clang ]; then
  export PATH="/work/clang-stock/bin:$PATH"
  echo "==> clang: stock $(clang --version | head -n1)"
else
  echo "==> clang: DDK $(clang --version | head -n1)"
fi

export ARCH=arm64
export LLVM=1
export LLVM_IAS=1
export CROSS_COMPILE=aarch64-linux-gnu-

cd /work/kernel
mkdir -p out

if [ ! -s /work/config/hummer_config.gz ]; then
  echo "::error::/work/config/hummer_config.gz 不存在"
  exit 1
fi
zcat /work/config/hummer_config.gz > out/.config
echo "==> baseline config: $(grep -c '^CONFIG_' out/.config) lines"

make O=out olddefconfig

echo "==> key config"
grep -E '^CONFIG_(LOCALVERSION|LOCALVERSION_AUTO|CFI_CLANG|MODVERSIONS|MODULES|MODULE_SIG_FORCE|SMP|PREEMPT)' out/.config || true

# Image 生成 vmlinux / System.map；modules 生成 Module.symvers（外部模块需要）
make O=out -j"$(nproc)" KERNELRELEASE="$KERNELRELEASE" Image modules

test -s out/Module.symvers
test -s out/System.map
grep -q "$KERNELRELEASE" out/include/generated/utsrelease.h
grep -a -q "Linux version $KERNELRELEASE" out/arch/arm64/boot/Image

echo "==> KDIR ready"
ls -lh out/arch/arm64/boot/Image out/Module.symvers out/System.map
