#!/bin/bash
# 用刚编好的 KDIR 编译 Droidspaces LKM。
set -euxo pipefail

if [ "${USE_STOCK_CLANG:-0}" = "1" ] && [ -x /work/clang-stock/bin/clang ]; then
  export PATH="/work/clang-stock/bin:$PATH"
  echo "==> clang: stock $(clang --version | head -n1)"
else
  echo "==> clang: DDK $(clang --version | head -n1)"
fi

KDIR=${KDIR:-/work/kernel/out}
VER=${VER:-android15-6.6}
KERNELRELEASE=${KERNELRELEASE:?KERNELRELEASE is required}

test -s "$KDIR/Module.symvers"
test -s "$KDIR/System.map"

echo "==> KDIR=$KDIR VER=$VER"
grep -m1 UTS_RELEASE "$KDIR/include/generated/utsrelease.h"

cd /work/src

echo "==> build main modules"
make -C droid_lkm KDIR="$KDIR" VER="$VER" KERNELRELEASE="$KERNELRELEASE" -j"$(nproc)"

if [ "${BUILD_NETWORK:-true}" = "true" ]; then
  echo "==> build network modules"
  for m in net_macvlan net_ip6nat; do
    make -C "$KDIR" M="/work/src/$m" KERNELRELEASE="$KERNELRELEASE" clean >/dev/null 2>&1 || true
    make -C "$KDIR" M="/work/src/$m" KERNELRELEASE="$KERNELRELEASE" -j"$(nproc)" modules
  done
fi

mkdir -p dsm/ko
for k in droid_lkm droid_lkm_vendor droid_lkm_misc droid_lkm_pids; do
  if [ -f "droid_lkm/out/$VER/$k.ko" ]; then
    cp "droid_lkm/out/$VER/$k.ko" dsm/ko/
  fi
done
if [ "${BUILD_NETWORK:-true}" = "true" ]; then
  [ -f net_macvlan/macvlan.ko ] && cp net_macvlan/macvlan.ko dsm/ko/
  [ -f net_ip6nat/ip6table_nat.ko ] && cp net_ip6nat/ip6table_nat.ko dsm/ko/
fi

test -s dsm/ko/droid_lkm.ko

echo "==> modules"
ls -lh dsm/ko
for k in dsm/ko/*.ko; do
  printf '%s: ' "$k"
  strings "$k" | grep -m1 'vermagic=' || echo 'vermagic not found'
done
