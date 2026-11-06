#!/bin/bash
# 把上游 PMB110 / 6.12 的守卫改成 LineageOS 24 / hummer / 6.6.144。
set -euxo pipefail

F=src/dsm/post-fs-data.sh
sed -i \
  -e 's/6\.12\.69-\*/6.6.144-*/g' \
  -e 's/6\.12\.69/6.6.144/g' \
  -e 's/vermagic-not-6\.12/vermagic-not-6.6/g' \
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

# desc.sh 的 “已加载 n/6” 按实际打包的 ko 数量显示（6.6 默认不打包网络模块）
python3 - <<'PY'
from pathlib import Path
p = Path('src/dsm/desc.sh')
s = p.read_text()
s = s.replace(
    'list=""; n=0',
    'list=""; n=0; total=0\n'
    'for m in droid_lkm droid_lkm_vendor droid_lkm_misc droid_lkm_pids macvlan ip6table_nat; do\n'
    '  [ -f "$MODDIR/ko/$m.ko" ] && total=$((total+1))\n'
    'done'
)
s = s.replace('已加载 $n/6', '已加载 $n/$total')
p.write_text(s)
PY

echo "==> guards"
grep -nE '6\.6\.144|vermagic=6\.6|hummer|PMB110|6\.12' "$F" || true
echo "==> module.prop"
cat src/dsm/module.prop
