# NanoMQ on Zephyr：示例仓库

三个把 NanoMQ MQTT broker 跑在 Zephyr RTOS 上的示例：

| 示例 | 目标 | 网络 |
| --- | --- | --- |
| [`examples/nanomq_zephyr_qemu_x86`](examples/nanomq_zephyr_qemu_x86/) | `qemu_x86` 仿真 | QEMU SLIRP 用户态网络 |
| [`examples/nanomq_zephyr_esp32s3`](examples/nanomq_zephyr_esp32s3/) | ESP32-S3 实机 | Wi-Fi STA + DHCP，数据面放 PSRAM |
| [`examples/nanomq_zephyr_stm32_art-pi`](examples/nanomq_zephyr_stm32_art-pi/) | ART-Pi（STM32H750XBH6）实机 | 板载 AP6212 的 Wi-Fi STA + DHCP，数据面放 SDRAM |

三个示例编译的是同一份 NanoMQ broker 核心（`nanomq/`）和 NanoNNG（带 Zephyr
平台适配层的 `nng/` 分支），应用源码和 CMake 里找依赖的方式都一样；区别在板级支持
和网络层。

NanoMQ 本体不在这里。这次移植的来龙去脉 —— broker 核心为什么这么改、平台适配层
兜住了什么、路上踩了哪些框架坑 —— 写在 nanomq 自己的文档里：

* [NanoMQ 移植到 Zephyr RTOS：把 MQTT Broker 跑在 MCU 上](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md)（[English](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-zephyr.md)）
* [把 broker 搬到 ART-Pi（STM32H750）](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-art-pi.md)（[English](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-art-pi.md)）

本仓库负责能跑起来的那一半：应用、板级支持、烧写工具和验收测试。

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `examples/<example>/` | 每个目标一个应用，各自的 README 里有完整的编译、烧写和串口步骤 |
| `examples/cmake/nanomq_dependency.cmake` | 定位 nanomq checkout（`NANOMQ_ROOT`、`NNG_ROOT`），缺失时直接给出提示 |
| `examples/cmake/nanonng_external.cmake` | 用 `ExternalProject` 交叉编译 NanoNNG |
| `scripts/fetch-nanomq.sh` | 把 pin 住的 nanomq 版本取到 `extern/nanomq` |
| `nanomq.ref` | pin 的版本：`REPO`、`REF`、nng 子模块提交，以及这一对通过验证的日期 |
| `extern/nanomq` | 取回来的依赖（已 gitignore） |
| `GLOSSARY.md` | 文档和提交信息里用的术语 |
| `docs/adr/` | 关于本仓库的决策，连同被否掉的备选方案 |

## 1. 克隆到 west workspace 里

**本仓库必须放在一个 Zephyr west workspace 内。** `west build` 是从应用目录往上
找 workspace 的，放在外面根本编不了；
`examples/nanomq_zephyr_stm32_art-pi/tools/flash.sh` 会直接把这句话打出来，而不是
在 west 内部报一个看不懂的错。

```sh
cd ~/zephyrproject                                            # 你的 west workspace
git clone https://github.com/nanomq/NanoMQ-Zephyr-Example.git
```

## 2. 取 nanomq 依赖

示例编译时要用 nanomq checkout 里的 broker 核心和 NanoNNG，所以第一次编译前先取
一次：

```sh
cd ~/zephyrproject/NanoMQ-Zephyr-Example
scripts/fetch-nanomq.sh
```

脚本把 nanomq 克隆到 `extern/nanomq`（已 gitignore），并切到
[`nanomq.ref`](nanomq.ref) 里记的版本 —— 当前是 nanomq `bb70558a` 配 nng
`3da6917f`，验证日期 2026-10-13。它只初始化 `nng` 子模块；nanomq 其余子模块对应
的功能在示例里都是关闭的。

* `scripts/fetch-nanomq.sh --ref <ref>` 换成别的版本做实验。
* `west build … -DNANOMQ_ROOT=/path/to/nanomq` 直接用你手上已有的 checkout（比如
  改了 nng 源码的开发 worktree），连脚本都不用跑。

以后要升级 pin：改 `nanomq.ref` 里的 `REF`，重跑脚本，重跑功能测试，再更新
`VERIFIED`。

## 3. 环境

完整步骤和验证用的版本见
[移植教程](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md#环境搭建)。
要点：

* **Zephyr 4.4+ 的 west workspace 及其 Python 虚拟环境**（`west` 和 Zephyr 的
  Python 依赖都在里面），加上 **Zephyr SDK 1.0.x**：

  ```sh
  source ~/zephyr-venv/bin/activate              # 你的 venv 在哪就写哪
  export ZEPHYR_SDK_INSTALL_DIR=$HOME/zephyr-sdk-1.0.1
  ```

* **只有 ESP32-S3 示例**需要 ESP-IDF 环境（`esptool` 和 HAL blob），并执行一次
  `west blobs fetch hal_espressif` —— 不取 blob 的话 Wi-Fi 会静默消失。编译器仍然
  来自 Zephyr SDK。
* **ART-Pi 示例**需要三处树外补丁和 `west blobs fetch hal_infineon`，见
  [它的 README](examples/nanomq_zephyr_stm32_art-pi/README.md)。
* **`qemu_x86`** 需要给 Zephyr 的 e1000 驱动打一个两行补丁。**这是必须的**：不打
  补丁 broker 照样启动并打印横幅，但任何客户端都连不上，因为仿真网卡会把广播帧丢
  掉。diff 在 [qemu 的 README](examples/nanomq_zephyr_qemu_x86/README.md) 和移植
  教程里，打到 workspace 的 `zephyr/` 目录。

## 4. 编译与运行

命令都在仓库根目录（`~/zephyrproject/NanoMQ-Zephyr-Example`，已经在 workspace
内）执行。每个示例的 README 有完整步骤，这里只给最短路径：

### qemu_x86 —— 最快的一个

```sh
west build -b qemu_x86 -d build/nanomq_zephyr_qemu_x86 examples/nanomq_zephyr_qemu_x86
west build -d build/nanomq_zephyr_qemu_x86 -t run      # 串口直接占住当前终端
```

`-t run` 会把 broker 的端口转发到 `127.0.0.1`，并占用终端。想后台跑、串口写文件，
用 [qemu 的 README](examples/nanomq_zephyr_qemu_x86/README.md) 里那条完整的
`qemu-system-i386` 命令，以及清理残留实例的命令。开发时先跑这个：一轮编译加运行只
要几秒。

### ESP32-S3

```sh
cp examples/nanomq_zephyr_esp32s3/local.conf.example \
   examples/nanomq_zephyr_esp32s3/local.conf        # SSID、口令、REST 凭据
west build -b esp32s3_devkitc/esp32s3/procpu -d build/esp32s3_nanomq \
    examples/nanomq_zephyr_esp32s3 -- -DEXTRA_CONF_FILE=local.conf
west flash -d build/esp32s3_nanomq --runner esp32 --esp-device /dev/ttyUSB0
```

### ART-Pi

```sh
cp examples/nanomq_zephyr_stm32_art-pi/local.conf.example \
   examples/nanomq_zephyr_stm32_art-pi/local.conf     # SSID、口令、REST 凭据
examples/nanomq_zephyr_stm32_art-pi/tools/flash.sh --wifi
examples/nanomq_zephyr_stm32_art-pi/tools/console.sh
```

`flash.sh` 一步完成编译和烧写（镜像要放进 QSPI 窗口、挂在板子的出厂 bootloader
之后，所以光敲 `west build` 出来的镜像不能用），`--wifi` 是验证过的变体。

## 5. 端口与服务

三个示例对外暴露的服务一样：

| 服务 | 端口 | ESP32-S3 | qemu_x86 | ART-Pi | 认证 / 加密 |
| --- | --- | --- | --- | --- | --- |
| MQTT over TCP | 1883 | 支持 | 支持 | 支持 | 无认证、无 TLS |
| REST API | 8081 | 支持 | 支持 | 支持 | Basic 认证，凭据由你配置，无 TLS |
| MQTT over WebSocket | 8083 | 支持 | 支持 | 支持 | 无认证、无 TLS；路径 `/mqtt` |

REST 监听只有在 `CONFIG_BROKER_REST_USER` 和 `CONFIG_BROKER_REST_PASS` 都设成你自己
的凭据时才会起来：两者默认都是空字符串，公开的 `admin` / `public` 组合也被拒绝。
不设就什么都不监听 —— 这时功能测试的 `rest_get` 分组会报 SKIP，而不是失败。

## 6. 安全前提

默认配置假设的是受控的实验网络：三个示例都把 MQTT、WebSocket 和 REST 绑在
`0.0.0.0` 上，MQTT 侧没有认证，TLS 没有编进移植版，REST 的 Basic 认证走明文
HTTP，只是 Base64 编码而不是加密。

要在实验网络之外使用，至少要把监听地址收敛到需要的网卡、设置自己的 REST 凭据，并
把管理接口放到可信网络或 TLS 代理之后。**不要把默认配置暴露到公网。** 细节见教程的
[安全前提](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md#安全前提)。

## 7. 功能测试

`examples/nanomq_zephyr_qemu_x86/function_test.py` 是三个示例共用的验收套件：它自己
拉起并驱动 QEMU，也可以对已经在跑的实机用 `--addr <板子IP> --no-manage`。

```sh
python3 examples/nanomq_zephyr_qemu_x86/function_test.py                   # 全部分组
python3 examples/nanomq_zephyr_qemu_x86/function_test.py --list            # 有哪些分组
python3 examples/nanomq_zephyr_qemu_x86/function_test.py --no-manage --addr 192.168.1.8
```

`--no-manage --addr <板子IP>` 同时会把套件重新调参：非 loopback 地址会隐含
`--time-scale 4 --retry 2`，这是本地回环下调好的 sleep 在真实网络上需要的。ART-Pi
示例的 `tools/verify.sh <板子IP>` 在它外面包了三个验收闸门（`mqtt_v311`、
`mqtt_v5`、`rest_get`），`--full` 再带上其余分组。套件需要的 Python 依赖在
[教程](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md#运行功能测试)里列了。

## 8. 这个移植版没有的东西

Zephyr 版**不是**通用 NanoMQ 的等价替代。broker 的周边功能是编译进来、运行时受控
的，但有几项能力在这个平台上不可用或未验证：

| 能力 | 现状 | 后续计划 |
| --- | --- | --- |
| 文件系统（配置、日志、持久会话） | 不写盘；`$SYS` 只反映运行状态 | **会支持**：挂上 Zephyr 的 fs 子系统即可 |
| SQLite 持久化 | 未包含（`NNG_ENABLE_SQLITE=OFF`） | **会支持**：与文件系统一起 |
| Parquet | 未包含（`SUPP_PARQUET` 未定义） | **会支持**：同上 |
| TLS | 未包含（`NNG_ENABLE_TLS=OFF`），因此没有 MQTTS / WSS / HTTPS | **会支持**：Zephyr 自带 mbedTLS 和 `tls_credentials` |
| MQTT 认证（密码 / ACL） | 未接线，任何客户端都能连 | **会支持**：配置接线加验证 |
| 规则引擎 | 嵌入式配置里没有对应的开关路径 | **会支持**：纯配置工作 |
| IPC 传输（`nanomq ctl`） | 关闭；Zephyr 只有匿名 `socketpair` | **等平台支持** |
| QUIC | 未包含（依赖 msquic） | **不计划支持** |

另外两点值得知道：线程数是固定的（taskq 2、poller 1、expire 1，配合
`CONFIG_POSIX_THREAD_THREADS_MAX=16` 和 16 KB 栈），而且 broker 的 `process.c`
在 Zephyr 上编不了 —— 每个示例都用一份等价符号桩顶上。移植基线是 NanoMQ 0.25.6
（即上游 `master`），配置来自内置默认值加启动代码，不读 `nanomq.conf`。

## 9. 三个示例对比

|  | `examples/nanomq_zephyr_esp32s3` | `examples/nanomq_zephyr_stm32_art-pi` | `examples/nanomq_zephyr_qemu_x86` |
| --- | --- | --- | --- |
| **目标平台** | ESP32-S3 实机 | ART-Pi（STM32H750XBH6）实机 | `qemu_x86` |
| **硬件要求** | ESP32-S3 开发板 | ART-Pi 开发板 | 无 |
| **网络** | Wi-Fi STA + DHCP | 板载 AP6212 的 Wi-Fi STA + DHCP | QEMU SLIRP 用户态网络 |
| **内存 / 存储** | 16 MB flash + 八线 PSRAM（数据面在 PSRAM） | 8 MB QSPI flash 原地执行 + 32 MB SDRAM（数据面在 SDRAM） | 31 MB 仿真内存，无持久存储 |
| **额外前置条件** | Wi-Fi 凭据、ESP-IDF（烧写）、Espressif blob | Wi-Fi 凭据、三处树外补丁、Infineon blob | Zephyr e1000 驱动补丁 |
| **典型用途** | 实机评估与硬件测试 | ARM 上的实机评估；板级 bring-up 参考 | 开发期的快速验证 |

开发时建议从 `qemu_x86` 开始。实机评估用手上的板子就行：ESP32-S3 是更早跑通的
目标，ART-Pi 展示的是同一份移植在 ARM Cortex-M7 上的样子，flash 布局、射频通路和
bring-up 坑都是另一套。

## 相关链接

* nanomq 文档里的[移植教程](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md)与 [ART-Pi 一文](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-art-pi.md)
* [nanomq/NanoNNG](https://github.com/nanomq/NanoNNG) —— 带 Zephyr 平台适配层的 nng 分支
* [本仓库的决策记录](docs/adr/)与[术语表](GLOSSARY.md)
* [NanoMQ 社区讨论](https://github.com/nanomq/nanomq/discussions)

## 许可证

[MIT](LICENSE)
