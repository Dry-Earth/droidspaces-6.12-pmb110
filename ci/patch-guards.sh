#!/bin/bash
# 把上游 PMB110 / 6.12 的守卫改成 LineageOS 24 / hummer / 6.6.144。
set -euxo pipefail

F=src/dsm/post-fs-data.sh
sed -i \
  -e 's/6\.12\.69-\*/6.6.144-*/g' \
  -e 's/6\.12\.69/6.6.144/g' \
  -e 's/vermagic=6\.12/vermagic=6.6/g' \
  -e 's/\*PMB110\*/\*hummer*/g' \
  "$F"

sed -i \
  -e 's/^id=.*/id=Droidspaces-hummer/' \
  -e 's/^name=.*/name=Droidspaces 6.6 (OnePlus Ace 5 Pro)/' \
  -e 's/^version=.*/version=v1.0.23-6.6-hummer/' \
  -e 's|^description=.*|description=LineageOS 24 / OnePlus Ace 5 Pro (hummer) / 6.6.144-4k-g6350e8af3f4c. LKM 方案：不刷内核，补 PID/IPC/SYSVIPC/mqueue/devtmpfs/pids/macvlan/ip6nat。默认不自动加载。|' \
  src/dsm/module.prop

sed -i \
  -e 's/PMB110/OnePlus Ace 5 Pro (hummer)/g' \
  -e 's/6\.12\.69/6.6.144/g' \
  -e 's/6\.12/6.6/g' \
  src/dsm/desc.sh

# WebUI 里的机型/版本文案（有就替换，没有也不报错）
if [ -f src/dsm/webroot/index.html ]; then
  sed -i -e 's/PMB110/OnePlus Ace 5 Pro/g' -e 's/6\.12\.69/6.6.144/g' -e 's/6\.12/6.6/g' src/dsm/webroot/index.html
fi

echo "==> guards"
grep -nE '6\.6\.144|vermagic=6\.6|hummer|PMB110|6\.12' "$F" || true
echo "==> module.prop"
cat src/dsm/module.prop
