# Droidspaces LKM for OnePlus Ace 5 Pro (hummer)

在 **LineageOS 24.0 原厂内核**上补齐 Droidspaces / Docker 容器所需的内核能力，
**不刷内核、不改 App 源码**，全部通过 KernelSU 模块（`.ko`）完成。

本仓库是 [ai-luo2006/droidspaces-6.12-pmb110](https://github.com/ai-luo2006/droidspaces-6.12-pmb110)
的 fork，把目标机型从「一加 Ace 6 至尊版 PMB110 / 6.12.69」改成了：

| 项目 | 本 fork 的目标 |
|---|---|
| 机型 | 一加 Ace 5 Pro（代号 `hummer`） |
| 系统 | LineageOS 24.0（20261030） |
| 内核 | `6.6.144-4k-g6350e8af3f4c` |
| 内核 commit | `6350e8af3f4c452d087fbd6fe1aabe03cbc0af75` |
| KMI | `android15-6.6` |
| 原厂编译器 | clang r596125（`Android ... clang version 22.0.2`） |

---

## 先选路线：你不需要同时用两种方案

| 路线 | 做法 | 适合谁 |
|---|---|---|
| **A. 原生 boot.img** | 刷 [hummer-lineage-kernel-build](https://github.com/Dry-Earth/hummer-lineage-kernel-build/releases/tag/boot-42075428894) 里的 `new-boot.img`，内核编译时直接打开 PID/IPC/SYSVIPC/mqueue/devtmpfs 等 | 想一次性解决、能接受刷 boot 分区 |
| **B. 本仓库 LKM** | 不刷内核，用 KernelSU 模块在**原厂内核**上补功能 | 不想动 boot 分区 / 想保留官方内核 |

**不要混用**：路线 A 的内核已经原生支持这些能力，再加载 `droid_lkm.ko`
属于重复实现，钩子可能冲突。选了 A 就不需要 `droid_lkm / vendor / misc`；
`droid_lkm_pids`、`macvlan`、`ip6table_nat` 是否可用取决于 A 的 config，未验证。

本 README 之后只讲 **路线 B（LKM）**。

---

## 这个 LKM 包补什么

| 能力 | 模块 | 说明 |
|---|---|---|
| PID / IPC / SYSVIPC / POSIX mqueue 命名空间 | `droid_lkm.ko` | 运行时补 `CONFIG_PID_NS` / `CONFIG_IPC_NS` / `CONFIG_SYSVIPC` / `CONFIG_POSIX_MQUEUE` |
| devtmpfs | `droid_lkm_misc.ko` | 注册文件系统，给容器 `/dev` 提供设备节点 |
| OPPO 厂商兼容 | `droid_lkm_vendor.ko` | ghost task / ddl 越界兜底 |
| pids 控制器 | `droid_lkm_pids.ko` | 让 `--pids-limit` 真正生效 |
| macvlan（可选） | `macvlan.ko` | 容器独立 IP（`--net=macvlan`）；上游按 6.12 API 写，6.6 默认不编 |
| IPv6 NAT（可选） | `ip6table_nat.ko` | NAT66；同样默认不编 |

> 6.6 默认只打包 **4 个模块**：`droid_lkm`、`droid_lkm_vendor`、`droid_lkm_misc`、`droid_lkm_pids`。
> `macvlan.ko` / `ip6table_nat.ko` 的源码依赖 6.12 的 `net_device` 字段
> （`lltx` / `change_proto_down` 等），在 6.6 上会编译失败；工作流默认跳过它们。
> 如果你用的是路线 A 的原生 boot.img，macvlan 已经在内核里了，不需要这两个模块。

> **`CONFIG_USER_NS` 补不了。** 这是整个项目最重要的结论。原厂内核编译时就没开，
> 模块无法在运行时补出来。后果：容器 root **就是**宿主 root，不存在 uid 隔离。
> 详见下方「安全模型」。

---

## 为什么不能直接用上游预编译的 `.ko`

上游的 `release/` 是给 PMB110 / `6.12.69-android16` 编的，直接拿到 6.6.144 上：

1. **vermagic 不匹配** → `insmod: invalid module format`
2. **KCFI 不匹配** → `CFI failure` + 整机断电

所以本仓库提供 GitHub Actions 工作流，按你的目标内核重新编。它做了三件关键的事：

1. **用精确内核 commit + 原厂 config 生成 KDIR**
   - 上游 DDK 的 `android15-6.6` KDIR 是 `6.6.127-4k-g46a034eca005`，
     和你的 `6.6.144-4k-g6350e8af3f4c` 差一个 patchlevel，vermagic 对不上。
   - 工作流改为：检出 `LineageOS/android_kernel_oneplus_sm8750`
     `6350e8af...`，用 `config/hummer_config.gz`（从官方 boot.img 提取的真实 config）
     编出 `Image + modules`，得到 `Module.symvers` / `System.map` / `utsrelease.h`。
2. **用原厂 clang r596125 编 KDIR 和 LKM**
   - 从 AOSP 预编译 clang 项目下载 r596125；
   - 下载失败自动回退 DDK 的 r510928，并在日志/构建信息里标注。
   - 编译器版本不影响 vermagic 和 genksyms CRC，但 KCFI 对编译器敏感；
     想零风险，就用 r596125。
3. **把守卫改成你的机型**
   - `post-fs-data.sh`：`6.12.69-*` → `6.6.144-*`，`*PMB110*` → `*hummer*`，
     `vermagic=6.12` → `vermagic=6.6`
   - `module.prop`：`id=Droidspaces-hummer`，名称/版本/描述改成 LineageOS 24 / Ace 5 Pro

---

## 一键构建

GitHub 仓库 → **Actions** → **Build hummer 6.6 LKM (Droidspaces)** → **Run workflow**。

参数：

| 参数 | 默认 | 说明 |
|---|---|---|
| `use_stock_clang` | ✅ | 下载原厂 clang r596125；失败自动回退 DDK r510928 |
| `build_network` | ❌ | 尝试编 `macvlan.ko` / `ip6table_nat.ko`；6.6 上大概率失败，失败会跳过 |
| `publish_release` | ✅ | 成功后自动发 Release |

耗时约 **25–35 分钟**（含内核 KDIR 构建）。产物：

- Actions Artifacts：`hummer-lkm-<run_id>`（zip + 4 个 `.ko` + `build-info.txt`）
- Release：`hummer-lkm-<run_id>`

工作流关键日志会打印：

```
==> clang: stock Android (...) clang version 22.0.2
==> baseline config: 2683 lines
==> KDIR ready
...
droid_lkm.ko: vermagic=6.6.144-4k-g6350e8af3f4c SMP preempt mod_unload modversions aarch64
```

### 本次构建结果（2026-11-06）

- Release：https://github.com/Dry-Earth/droidspaces-6.12-pmb110/releases/tag/hummer-lkm-42139605326
- zip：`Droidspaces-v1.0.23-6.6-hummer.zip`（5.1 MB）
- zip sha256：`b0ca50bb781624ab5c66929bb216e7e605ea1e20b520fd867424dc673aef6770`
- 编译工具链：原厂 clang r596125（`clang version 22.0.2`）
- 模块 vermagic 全部为：`6.6.144-4k-g6350e8af3f4c SMP preempt mod_unload modversions aarch64`

| 模块 | sha256 |
|---|---|
| `droid_lkm.ko` | `928edf9acd74a19d4a41822afa12274c3cbe29d26b439fcdc7ed4a72ce572906` |
| `droid_lkm_vendor.ko` | `5df09e30951492d574a3cfea75782d7618146e6de748b8094b0d2972ba9e61b8` |
| `droid_lkm_misc.ko` | `9833e4ee022b6e2d1271b50d064bc6d124eb79a81b760b5e3a94bc76b11e956a` |
| `droid_lkm_pids.ko` | `c0375d5d96b976b8768bb780ba098add62e6f764a9767bd30f820432074b0893` |

> 这是**第一次为 6.6.144 构建**，编译和 vermagic 已对齐，但**还没有在真机上验证**。
> 第一次安装请保留包内的 `no_boot`，先手动逐块加载；崩了就按「排错」回滚。

---

## 安装

### 1. 确认 root 方案

KernelSU / KernelSU Next / SUKISU / APatch 均可（需要能装 KernelSU 模块）。
确认模块加载没有被 `CONFIG_MODULE_SIG_FORCE` 拦住（本机是 `# CONFIG_MODULE_SIG_FORCE is not set`）。

### 2. 安装 zip

KernelSU 管理器 → 模块 → 安装 → 选 Release 里的
`Droidspaces-v1.0.23-6.6-hummer.zip` → 重启。

首次安装包内自带 `no_boot`，**开机不会自动加载**，这是故意的安全模式。

### 3. 手动加载一次并验证

在 WebUI 里点「加载」，或者：

```sh
su -c 'sh /data/adb/modules/Droidspaces-hummer/post-fs-data.sh'
```

然后看日志：

```sh
su -c 'cat /data/adb/modules/Droidspaces-hummer/load.log'
su -c 'grep -E "^(droid_lkm|macvlan|ip6table_nat)" /proc/modules'
su -c 'dmesg | grep -iE "droid_lkm|CFI failure|Unknown symbol" | tail -50'
```

**逐块确认**（第一次务必这样）：

```sh
su -c 'insmod /data/adb/modules/Droidspaces-hummer/ko/droid_lkm.ko gate=0 mqueue=1 nspid=1 nspid_append=1 skip_sysvipc=0 no_fake_ns=0 skip_do_exit=0'
su -c 'dmesg | grep -i droid_lkm | tail -30'
```

主模块不崩，再依次加 `vendor` → `misc` → `pids` → `macvlan` → `ip6table_nat`。
`droid_lkm_misc.ko` 在非 6.12 内核上最容易出问题；如果一加载就重启，先放弃它，
只留主模块也能跑容器。

### 4. 验证通过后再开自启

```sh
su -c 'rm -f /data/adb/modules/Droidspaces-hummer/no_boot'
```

---

## 验证清单

```sh
# 1. 模块在线
grep -E '^(droid_lkm|droid_lkm_vendor|droid_lkm_misc|droid_lkm_pids|macvlan|ip6table_nat) ' /proc/modules

# 2. 没有 CFI / Unknown symbol
dmesg | grep -iE 'CFI failure|Unknown symbol' | tail

# 3. pid ns 独立（容器内 vs 宿主）
readlink /proc/self/ns/pid

# 4. devtmpfs
grep devtmpfs /proc/filesystems

# 5. Droidspaces 自检
su -c 'droidspaces check'
```

`droidspaces check` 或 App 的 Requirements 页面里，**must have / recommended 全绿**
才算适配成功。`user namespace` 那一项永远红，属预期。

---

## 排错

| 现象 | 原因 | 处理 |
|---|---|---|
| `invalid module format` | vermagic 不匹配 | 确认工作流用的是 `6.6.144-4k-g6350e8af3f4c`，且 KDIR 来自精确 commit |
| `CFI failure` 后关机 | clang 与内核不匹配 | 用 `use_stock_clang=true` 重跑；日志确认是 r596125 |
| `Unknown symbol xxx` | 6.6 的未导出符号集合和 6.12 不同 | 看具体符号，需要补 shim；先只加载主模块 |
| 加载后立即重启 | `droid_lkm_misc` 最容易触发 | 进 KernelSU 安全模式，或 recovery 删 `/data/adb/modules/Droidspaces-hummer`；先用 `skip_misc` |
| `insmod` 返回 `-22` | 参数名与 6.6 不一致 | 去掉参数裸加载：`insmod droid_lkm.ko` |
| 机型守卫拦截 | 指纹里没有 `hummer` | `echo hummer > /data/adb/modules/Droidspaces-hummer/allow_list` |
| 内核守卫拦截 | `uname -r` 不是 `6.6.144-*` | OTA 后内核变了，需要重跑工作流；或临时 `touch allow_any_kernel`（不推荐） |

---

## 安全模型（必须知道）

```
容器 root  ==  宿主 root        （无 CONFIG_USER_NS，无法改变）
capability ==  32 个全量        （含 SYS_ADMIN / MKNOD / SYS_PTRACE）
SELinux    ==  Permissive
网络       ==  net_mode=host（默认）
```

这个模块挡误操作，**不挡有意为之**。容器权限等价于你在 Termux 里 `su` 后跑的东西。
不要用它运行来路不明的镜像，也不要把它当安全沙箱。

---

## 目录结构

```
.github/workflows/build-hummer-lkm.yml   # 本 fork 的构建流程
ci/build-kdir.sh                         # 用原厂 config 生成 KDIR
ci/build-lkm.sh                          # 编译 Droidspaces LKM
ci/patch-guards.sh                       # 改机型/内核守卫
config/hummer_config.gz                  # 从官方 boot.img 提取的真实 config
src/                                     # 上游源码（droid_lkm / dsm / 网络模块）
docs/                                    # 上游文档（部分仍是 PMB110 的例子）
```

> `docs/` 和 `release/` 里的历史内容仍以上游 PMB110 / 6.12 为主，
> 看的时候注意区分；本 README 和 `.github/workflows/build-hummer-lkm.yml`
> 才是本 fork 针对 hummer 的说明。

---

## 鸣谢

本项目完全建立在原作者和上游社区的工作之上：

- **原作者 [ai-luo2006](https://github.com/ai-luo2006)** —
  上游仓库 [ai-luo2006/droidspaces-6.12-pmb110](https://github.com/ai-luo2006/droidspaces-6.12-pmb110)：
  LKM 思路、kABI/KCFI 经验、droid_lkm / vendor / misc / pids / macvlan / ip6nat
  源码、WebUI、守卫与 bootloop 保护，均来自原作者。
- **[ravindu644](https://github.com/ravindu644)** — Droidspaces 本体与 GKI kABI 补丁。
- **[Ylarod](https://github.com/Ylarod)** — DDK 工具链镜像。
- **LineageOS** — hummer 内核源码与官方 boot.img。
- **[cctv18](https://github.com/cctv18/oppo_oplus_realme_sm8750)** — 容器/网络选项清单与
  OPPO 机型注意事项（仅作参考，未采用其模块校验绕过补丁）。

没有上游这些工作，这个 fork 不可能存在。
