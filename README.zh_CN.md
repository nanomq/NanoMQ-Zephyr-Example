# NanoMQ on Zephyr：示例仓库

三个在 Zephyr RTOS 上运行 NanoMQ MQTT broker 的示例：

| 示例 | 目标 | 网络 |
| --- | --- | --- |
| [`examples/nanomq_zephyr_qemu_x86`](examples/nanomq_zephyr_qemu_x86/) | `qemu_x86` 仿真 | QEMU SLIRP 用户态网络 |
| [`examples/nanomq_zephyr_esp32s3`](examples/nanomq_zephyr_esp32s3/) | ESP32-S3 实机 | Wi-Fi STA + DHCP，数据面位于 PSRAM |
| [`examples/nanomq_zephyr_stm32_art-pi`](examples/nanomq_zephyr_stm32_art-pi/) | ART-Pi（STM32H750XBH6）实机 | 板载 AP6212 的 Wi-Fi STA + DHCP，数据面位于 SDRAM |

三个示例编译同一份 NanoMQ broker 核心（`nanomq/`）与 NanoNNG（带 Zephyr 平台
适配层的 `nng/` 分支），应用源码与依赖解析方式一致，差异在板级支持与网络层。

NanoMQ 本体不在本仓库内。broker 核心的改动原因、平台适配层所覆盖的内容，以及移植
过程中遇到的框架层问题，均在 nanomq 的文档中说明：

* [NanoMQ 移植到 Zephyr RTOS：把 MQTT Broker 跑在 MCU 上](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md)（[English](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-zephyr.md)）
* [把 broker 搬到 ART-Pi（STM32H750）](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-art-pi.md)（[English](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-art-pi.md)）

本仓库负责可运行部分：示例应用、板级支持、烧写工具与验收测试。

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `examples/<example>/` | 每个目标对应一个应用，各示例 README 提供完整的编译、烧写与串口步骤 |
| `examples/cmake/nanomq_dependency.cmake` | 定位 nanomq checkout（`NANOMQ_ROOT`、`NNG_ROOT`），缺失时给出明确提示 |
| `examples/cmake/nanonng_external.cmake` | 使用 `ExternalProject` 交叉编译 NanoNNG |
| `scripts/fetch-nanomq.sh` | 将 pin 的 nanomq 版本获取到 `extern/nanomq` |
| `nanomq.ref` | pin 的版本：`REPO`、`REF`、nng 子模块提交，以及该组合通过验证的日期 |
| `extern/nanomq` | 获取到的依赖（已 gitignore） |
| `GLOSSARY.md` | 文档与提交信息使用的术语 |
| `docs/adr/` | 本仓库的决策记录，含被否决的备选方案 |

## 1. 克隆到 west workspace

**本仓库必须位于 Zephyr west workspace 内。** `west build` 从应用目录向上查找
workspace，仓库位于 workspace 之外时无法构建；此时
`examples/nanomq_zephyr_stm32_art-pi/tools/flash.sh` 会直接给出提示，而不是让 west
抛出难以理解的错误。

```sh
cd ~/zephyrproject                                            # 你的 west workspace
git clone https://github.com/nanomq/NanoMQ-Zephyr-Example.git
```

## 2. 获取 nanomq 依赖

示例构建时使用 nanomq checkout 中的 broker 核心与 NanoNNG，因此首次构建前需先获取
依赖：

```sh
cd ~/zephyrproject/NanoMQ-Zephyr-Example
scripts/fetch-nanomq.sh
```

脚本将 nanomq 克隆到 `extern/nanomq`（已 gitignore），并检出
[`nanomq.ref`](nanomq.ref) 中记录的版本（当前为 nanomq `bb70558a` 配 nng
`3da6917f`，验证日期 2026-10-13）。脚本仅初始化 `nng` 子模块，其余子模块对应的
功能在示例中均已关闭。

* `scripts/fetch-nanomq.sh --ref <ref>`：切换到其他版本进行实验。
* `west build … -DNANOMQ_ROOT=/path/to/nanomq`：直接使用已有的 checkout（例如
  修改过 nng 源码的开发 worktree），无需运行脚本。

后续升级 pin 时：修改 `nanomq.ref` 中的 `REF`，重新运行脚本与功能测试，并更新
`VERIFIED`。

## 3. 环境

完整步骤与验证所用版本见
[移植教程](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md#环境搭建)。
要点如下：

* Zephyr 4.4+ 的 west workspace 及其 Python 虚拟环境（`west` 与 Zephyr 的 Python
  依赖均在其中），以及 Zephyr SDK 1.0.x：

  ```sh
  source ~/zephyr-venv/bin/activate              # 按实际的 venv 路径调整
  export ZEPHYR_SDK_INSTALL_DIR=$HOME/zephyr-sdk-1.0.1
  ```

* 仅 ESP32-S3 示例需要 ESP-IDF 环境（`esptool` 与 HAL blob），并执行一次
  `west blobs fetch hal_espressif`；未获取 blob 时 Wi-Fi 会静默失效。编译器仍由
  Zephyr SDK 提供。
* ART-Pi 示例需要三处树外补丁与 `west blobs fetch hal_infineon`，见
  [该示例的 README](examples/nanomq_zephyr_stm32_art-pi/README.md)。
* `qemu_x86` 需要为 Zephyr 的 e1000 驱动打一个两行补丁。**该补丁为必需项**：未应用
  时 broker 仍会启动并打印横幅，但任何客户端都无法建立连接，原因是仿真网卡会丢弃
  广播帧。diff 见 [qemu 示例的 README](examples/nanomq_zephyr_qemu_x86/README.md)
  与移植教程，应用于 workspace 的 `zephyr/` 目录。

## 4. 编译与运行

以下命令均在仓库根目录（`~/zephyrproject/NanoMQ-Zephyr-Example`，位于 workspace
内）执行。各示例的 README 包含完整步骤。

### qemu_x86

```sh
west build -b qemu_x86 -d build/nanomq_zephyr_qemu_x86 examples/nanomq_zephyr_qemu_x86
west build -d build/nanomq_zephyr_qemu_x86 -t run      # 串口输出占用当前终端
```

`-t run` 会将 broker 端口转发到 `127.0.0.1`，并占用当前终端。如需后台运行并将串口
输出写入文件，可使用 [qemu 示例的 README](examples/nanomq_zephyr_qemu_x86/README.md)
中给出的完整 `qemu-system-i386` 命令，以及清理残留实例的命令。开发阶段建议先使用该
示例：一轮构建加运行仅需数秒。

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

`flash.sh` 一步完成构建与烧写（镜像需放入 QSPI 窗口、运行在板子的出厂 bootloader
之后，因此仅执行 `west build` 得到的镜像不可用）；`--wifi` 是经验证的变体。

## 5. 端口与服务

三个示例对外暴露的服务相同：

| 服务 | 端口 | ESP32-S3 | qemu_x86 | ART-Pi | 认证 / 加密 |
| --- | --- | --- | --- | --- | --- |
| MQTT over TCP | 1883 | 支持 | 支持 | 支持 | 无认证、无 TLS |
| REST API | 8081 | 支持 | 支持 | 支持 | Basic 认证，凭据需自行配置，无 TLS |
| MQTT over WebSocket | 8083 | 支持 | 支持 | 支持 | 无认证、无 TLS；路径 `/mqtt` |

REST 监听仅在 `CONFIG_BROKER_REST_USER` 与 `CONFIG_BROKER_REST_PASS` 均设置为自有
凭据后才会启用：两者默认为空字符串，公开的 `admin` / `public` 组合也会被拒绝。未
设置时不会有任何监听，此时功能测试的 `rest_get` 分组报告为 SKIP，而非失败。

## 6. 安全前提

默认配置面向受控的实验网络：三个示例均将 MQTT、WebSocket 与 REST 绑定在
`0.0.0.0` 上，MQTT 侧无认证，移植版未包含 TLS，REST 的 Basic 认证基于明文 HTTP，
仅做 Base64 编码，不提供加密。

如需在实验网络之外使用，至少应：将监听地址收敛到实际使用的网卡、设置自有 REST
凭据，并将管理接口置于可信网络或 TLS 代理之后。**请勿将默认配置暴露到公网。**
详见教程的[安全前提](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md#安全前提)。

## 7. 功能测试

`examples/nanomq_zephyr_qemu_x86/function_test.py` 是三个示例共用的验收套件：可
自行拉起并驱动 QEMU，也可通过 `--addr <板子IP> --no-manage` 测试已在运行的实机。

```sh
python3 examples/nanomq_zephyr_qemu_x86/function_test.py                   # 全部分组
python3 examples/nanomq_zephyr_qemu_x86/function_test.py --list            # 列出分组
python3 examples/nanomq_zephyr_qemu_x86/function_test.py --no-manage --addr 192.168.1.8
```

`--no-manage --addr <板子IP>` 会同时调整套件参数：非 loopback 地址将隐含
`--time-scale 4 --retry 2`，这是按本地回环调好的 sleep 在真实网络上所需的设置。
ART-Pi 示例的 `tools/verify.sh <板子IP>` 在其之上封装了三个验收闸门
（`mqtt_v311`、`mqtt_v5`、`rest_get`），加 `--full` 可包含其余分组。套件所需的
Python 依赖见[教程](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md#运行功能测试)。

## 8. 本移植版缺少或尚未验证的能力

Zephyr 版**不是**通用 NanoMQ 的等价替代。broker 的周边功能均编译进固件并在运行时
控制，但以下能力在该平台上不可用或尚未验证：

| 能力 | 现状 | 后续计划 |
| --- | --- | --- |
| 文件系统（配置、日志、持久会话） | 不写盘；`$SYS` 仅反映运行状态 | **会支持**：挂载 Zephyr 的 fs 子系统即可 |
| SQLite 持久化 | 未包含（`NNG_ENABLE_SQLITE=OFF`） | **会支持**：与文件系统一起 |
| Parquet | 未包含（`SUPP_PARQUET` 未定义） | **会支持**：同上 |
| TLS | 未包含（`NNG_ENABLE_TLS=OFF`），因此没有 MQTTS / WSS / HTTPS | **会支持**：Zephyr 自带 mbedTLS 和 `tls_credentials` |
| MQTT 认证（密码 / ACL） | 未接线，任何客户端均可连接 | **会支持**：配置接线加验证 |
| 规则引擎 | 嵌入式配置中没有对应的开关路径 | **会支持**：仅需配置 |
| IPC 传输（`nanomq ctl`） | 关闭；Zephyr 仅提供匿名 `socketpair` | **待平台支持** |
| QUIC | 未包含（依赖 msquic） | **不计划支持** |

另有两点需要说明：线程数固定（taskq 2、poller 1、expire 1，配合
`CONFIG_POSIX_THREAD_THREADS_MAX=16` 与 16 KB 栈），且 broker 的 `process.c` 无法
在 Zephyr 上编译，各示例均以等价的符号桩替代。本移植跟踪上游 `master`，pin 的版本
为 NanoMQ 0.25.7（比 bring-up 记录所基于的 0.25.6 前进了一个开发版本）；配置来自
内置默认值与启动代码，不读取 `nanomq.conf`。

## 9. 三个示例对比

|  | `examples/nanomq_zephyr_esp32s3` | `examples/nanomq_zephyr_stm32_art-pi` | `examples/nanomq_zephyr_qemu_x86` |
| --- | --- | --- | --- |
| **目标平台** | ESP32-S3 实机 | ART-Pi（STM32H750XBH6）实机 | `qemu_x86` |
| **硬件要求** | ESP32-S3 开发板 | ART-Pi 开发板 | 无 |
| **网络** | Wi-Fi STA + DHCP | 板载 AP6212 的 Wi-Fi STA + DHCP | QEMU SLIRP 用户态网络 |
| **内存 / 存储** | 16 MB flash + 八线 PSRAM（数据面在 PSRAM） | 8 MB QSPI flash 原地执行 + 32 MB SDRAM（数据面在 SDRAM） | 31 MB 仿真内存，无持久存储 |
| **额外前置条件** | Wi-Fi 凭据、ESP-IDF（烧写）、Espressif blob | Wi-Fi 凭据、三处树外补丁、Infineon blob | Zephyr e1000 驱动补丁 |
| **典型用途** | 实机评估与硬件测试 | ARM 上的实机评估；板级 bring-up 参考 | 开发阶段的快速验证 |

开发阶段建议从 `qemu_x86` 开始；实机评估使用手头的板子即可：ESP32-S3 是较早验证的
目标，ART-Pi 则在 ARM Cortex-M7 上验证同一份移植，两者的 flash 布局、射频通路与
bring-up 难点各不相同。

## 相关链接

* nanomq 文档里的[移植教程](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md)与 [ART-Pi 一文](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-art-pi.md)
* [nanomq/NanoNNG](https://github.com/nanomq/NanoNNG)，带 Zephyr 平台适配层的 nng 分支
* [本仓库的决策记录](docs/adr/)与[术语表](GLOSSARY.md)
* [NanoMQ 社区讨论](https://github.com/nanomq/nanomq/discussions)

## 许可证

[MIT](LICENSE)
