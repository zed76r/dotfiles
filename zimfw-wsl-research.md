# 从 Zinit 迁移到 Zimfw 的 macOS / WSL 方案研究

日期：2026-08-17

## 结论

可以迁移，而且在“不依赖延迟加载、保留当前全部插件功能、不用 Homebrew 安装 Zimfw、macOS 配置同步后可在 WSL 使用”的约束下，Zimfw 更适合作为单纯的 Zsh 插件管理器。

但收益应准确描述：

- 明显收益在于启动路径更简单、首个按键不再撞上 Zinit 延迟调度，以及插件、CLI 二进制、completion 各自有明确生命周期。
- 已完成的隔离 macOS 对照中，完整同步加载的启动时间 p50 约从 Zinit 的 109 ms 降到 Zimfw 的 81.3 ms；首字符路径约从当前配置的 19.3 ms 降到 2.55 ms。
- 插件全部就绪以后，持续输入、Starship prompt 和 completion 的体验不会因为“管理器换成 Zimfw”继续显著变快；这些主要由插件本身和对应 CLI completion 决定。
- 迁移不应让 Zimfw 接管 `starship`、`mise` 或动态生成的 CLI completion。Zimfw 只管理静态 Zsh 模块，二进制和 completion 用独立脚本安装、更新与生成。

因此建议迁移，但不是把现有所有 `zinit ice` 机械翻译成 `zmodule`，而是重划三层职责。

## 当前必须保留的功能基线

实际配置盘点得到以下功能，迁移验收必须覆盖：

- `zsh-completions`
- Oh My Zsh `jump`：`jump`、`mark`、`unmark`、`marks`、`^G`
- Oh My Zsh `sudo`：`Esc Esc`
- `fast-syntax-highlighting`
- `zsh-autosuggestions` 及其 widget 包装
- `history-search-multi-word`：`^R`
- `LS_COLORS`
- Starship prompt 及其 `precmd`、`preexec`、ZLE hooks
- mise activation、PATH/shims、`precmd`、`chpwd` hooks
- `kubectl`、`k3s`、`flux`、`helm`、`mise`、`pnpm`、`codex` completion
- 自定义 `codex()` wrapper 及 `_codex_with_effort`，包括 `low medium high xhigh ultra max`

当前还存在两个与迁移无关的基线缺陷：Zinit 下的 `clrs.zsh` 是空文件，因此 `LS_COLORS` 实际未生效；`.zshrc` 的 `list-colors` 使用了 Unicode 弯引号。迁移时应该修正并单独验收，不能把当前错误复制成“功能等价”。

## 推荐职责划分

### 1. 同步的声明性配置

由 macOS 作为权威源，通过现有 OneDrive 流程同步：

```text
~/.zshenv
~/.zprofile
~/.zshrc
~/.zsh/zimrc
~/.zsh/starship.toml
~/.zsh/ai.zsh
~/.zsh/darwin.zsh
~/.zsh/linux.zsh
~/.zsh/bin/shell-bootstrap.zsh
~/.zsh/bin/shell-update.zsh
~/.zsh/bin/refresh-completions.zsh
~/.zsh/versions.lock
```

`~/.zsh/zimrc` 是唯一的模块声明文件，设置：

```zsh
ZIM_CONFIG_FILE=$HOME/.zsh/zimrc
ZIM_HOME=${XDG_DATA_HOME:-$HOME/.local/share}/zim
```

`versions.lock` 固定 Zimfw 版本、插件 commit，以及 `starship`、`mise` 的版本。这样 macOS 与 WSL 使用相同声明和版本，而不是各自在某天碰巧安装到不同的 latest。

### 2. 每台机器本地重建的状态

以下内容不通过 OneDrive 同步：

```text
~/.local/bin/starship
~/.local/bin/mise
${XDG_DATA_HOME:-~/.local/share}/zim/
${XDG_CACHE_HOME:-~/.cache}/zsh/completions/
${XDG_CACHE_HOME:-~/.cache}/zsh/zcompdump-*
```

理由：macOS 和 WSL 的可执行文件格式、架构、路径和 completion 生成结果可能不同；同步 Git checkout 和 symlink 也容易受 OneDrive/NTFS 语义影响。

所有脚本都用 `zsh ~/.zsh/bin/<script>.zsh` 调用，不依赖 OneDrive 保留 executable bit。

### 3. Zimfw 管理的静态模块

建议按依赖和 widget 包装顺序声明：

```text
zsh-users/zsh-completions
Oh My Zsh jump plugin
Oh My Zsh sudo plugin
zdharma-continuum/history-search-multi-word
zsh-users/zsh-autosuggestions
zdharma-continuum/fast-syntax-highlighting
```

实际 `zimrc` 应锁定插件版本。Zimfw 原生支持 branch、tag 和 frozen，但不能直接把任意 commit 当作一等 revision；要严格复现当前 checkout SHA，可以让 `versions.lock` 记录 SHA，`shell-bootstrap.zsh` 在 `zimfw install` 后核对并 checkout 指定 commit，再执行 `zimfw build`。更新脚本则统一更新、写入新 lock，并重新构建。

`LS_COLORS` 不建议继续依赖当前空的 `clrs.zsh`。应选择一个明确、可验证的生成或静态配置来源，并在两端检查 `LS_COLORS` 非空和 `zstyle ':completion:*' list-colors` 的实际值。

## Starship 和 mise 的独立安装、更新

两者安装到 `~/.local/bin`，不需要 Homebrew：

- mise 官方为 macOS/Linux 提供 standalone binary installer，默认安装目录就是 `~/.local/bin`，支持固定 `MISE_VERSION`、自定义 `MISE_INSTALL_PATH` 和 `mise self-update`。
- Starship 官方安装器支持 macOS/Linux、`--bin-dir`、`--version` 和非交互安装。

推荐 bootstrap 不直接在交互 shell 启动时执行 `curl | sh`，而是：

1. 从 `versions.lock` 读取固定版本。
2. 识别 `uname -s`、`uname -m`，下载对应 release 到临时目录。
3. 校验发布方 checksum；mise 在可用环境进一步使用官方签名校验路径。
4. 运行 `--version` 验证下载物。
5. 原子移动到 `~/.local/bin`。
6. 失败时保留现有可用版本，不覆盖。

`.zshrc` 只做本地、无网络初始化：

```zsh
(( $+commands[mise] )) && eval "$(mise activate zsh)"
(( $+commands[starship] )) && eval "$(starship init zsh)"
```

`upgrade_all` 应调用统一的 `shell-update.zsh`，不再调用 `zinit update`。更新必须是显式动作，不能发生在 shell startup。

## Completion 设计

Zimfw 不负责 `kubectl completion zsh` 这类动态产物。`refresh-completions.zsh` 按机器生成：

```text
kubectl -> _kubectl
k3s     -> _k3s（仅命令存在时）
flux    -> _flux
helm    -> _helm
mise    -> _mise
pnpm    -> _pnpm
codex   -> _codex
```

每个生成项遵循同一事务：

1. 检查命令存在。
2. 比较命令版本或 binary fingerprint。
3. 输出到临时文件。
4. 确认非空并通过 `zsh -n`。
5. 原子替换正式文件；失败时继续使用旧 completion。

机器本地 completion 目录要在 `compinit` 前加入 `fpath`。首次或缓存失效时做完整审计并生成本地 zcompdump，正常启动使用缓存。`_codex_with_effort` 继续保留在 `ai.zsh`，在 `compinit` 后执行：

```zsh
compdef _codex_with_effort codex
```

不要修改生成的 `_codex`，也不要在启动时运行 `codex completion zsh`。

## 首次切换流程

用户已明确保证：第一次改完，WSL 会先执行 `syncwin -d`。基于这个前提，推荐流程如下：

1. 在 macOS 建立当前 `.zsh*` 和 `.zsh/` 的可恢复备份。
2. 在隔离 `ZDOTDIR` 完成 Zimfw 配置和全功能验收，不先覆盖当前交互环境。
3. 应用 macOS 配置，执行 `zsh -n`、启动、widget、hook、completion 和 PTY 延迟验收。
4. 执行 `syncmac -u`，把声明性配置和 lock 上传到共享目录。
5. WSL **首先执行** `syncwin -d`，使其拿到完整的一致版本；不允许先 `syncwin -u`。
6. `syncwin -d` 自动执行 `zsh ~/.zsh/bin/shell-bootstrap.zsh`，在 Linux 本机安装 Zimfw/modules、Starship、mise，并生成 completion；也可手工重复执行，结果幂等。
7. 新开 shell 或 `exec zsh`，运行与 macOS 相同的功能验收。
8. 两端都通过后，才清理旧 Zinit machine-local 数据；清理属于独立、可恢复操作，不是切换必要步骤。

bootstrap 必须可重复执行：已满足 lock 时不下载，半成品写在临时目录，全部校验通过后才替换。任何失败都不能破坏已有二进制、插件 checkout 或当前可用 shell。

## 后续同步和更新语义

仅保证首次 `syncwin -d` 还不够。当前 `syncwin -u` 会上传 `.zsh/` 和 shell profile，未来可能把 WSL 的共享 shell 配置反向覆盖到 Mac 权威版本。

建议沿用现有 Codex common config 的所有权模型：

- `syncmac -u`：Mac 声明性配置 → OneDrive。
- `syncwin -d`：OneDrive 声明性配置 → WSL，然后自动执行本机 bootstrap/apply。
- `syncwin -u`：只上传 WSL 自有内容；当前实现已排除 Mac 权威的 `.zshrc`、`.zshenv`、`.zprofile` 和整个 `.zsh/` 声明目录。

若仍希望 WSL 编辑通用 shell 配置，应改成 Git 分支/变更审核，而不是让 `syncwin -u` 隐式决定最后写入者。

更新有两种模式：

1. 推荐的可复现模式：只在 Mac 执行 `shell-update.zsh --refresh-lock`，验证后 `syncmac -u`；WSL `syncwin -d` 后运行普通 bootstrap，收敛到新 lock。
2. 滚动模式：两端分别执行 self-update/latest。操作简单，但会产生版本漂移，不符合“同步完成后两端一致”的主要目标。

## 验收标准

迁移不能只以“shell 能打开”判断完成：

- 所有 shell 文件通过 `zsh -n`，startup 不联网且无错误。
- 关键函数、widget 和 bindings 存在：`^R`、`^G`、`Esc Esc`、autosuggestion widgets、Starship keymap widget。
- `precmd_functions`、`preexec_functions`、`chpwd_functions` 中的 Starship、mise、highlight、autosuggestion hooks 等价。
- `_comps` 至少正确映射 `kubectl`、`flux`、`helm`、`mise`、`pnpm`、`codex`、`git`、`sudo`；有 `k3s` 时额外映射。
- `codex -e <Tab>` 给出 `low medium high xhigh ultra max`，普通参数仍委托原生 `_codex`。
- `STARSHIP_CONFIG`、mise activation/PATH、mark 和 sudo widget 行为一致。
- `LS_COLORS` 非空，completion `list-colors` 不含弯引号。
- 在真实 PTY 中交替跑至少 30 次，报告 startup、首字符、空命令回到可输入状态、`kubectl ge<Tab>` 和 `codex -e <Tab>` 的 median/p95；macOS 和 WSL 分别测，不能用 macOS 结果推断 WSL。
- 新开 shell、执行 `syncwin -d` 后重建、离线启动三种场景都通过。

## 回滚

切换前保留配置备份并继续保留旧 Zinit 数据。若 macOS 或 WSL 验收失败：

1. 恢复旧 `.zshrc` / `.zshenv` / `.zprofile` / `.zsh/` 声明。
2. 新开 shell 验证旧 Zinit 配置可用。
3. 不删除 Zimfw 或新二进制也不影响回滚；它们没有被旧配置 source。
4. 只有在两端稳定一段时间后，才另行确认是否删除旧 `~/.local/share/zinit` 和缓存。

## 最终判断

在这套边界下，迁移值得做：Zimfw 负责静态插件，独立 bootstrap/update 负责跨平台二进制与动态 completion，macOS lock 负责一致性，WSL 通过 `syncwin -d` 和本机重建获得相同功能。它能保留现有体验，并消除当前首键延迟的主要来源；代价是新增三段短脚本和一个 lock 文件，但职责更清楚，也比把平台二进制藏在插件管理器内部更适合 WSL。

## 实施后验证记录

2026-08-17 已完成实际切换和以下验证：

- macOS arm64：固定版本安装、checksum、插件 commit、动态 completion 和真实 PTY 功能测试通过。
- OrbStack 一次性 Debian arm64：cold bootstrap、Starship `1.26.0`、mise `2026.8.6 linux-arm64`、widgets/hooks/bindings/completion 通过。
- OrbStack 一次性 Debian amd64：cold bootstrap、Starship `1.26.0`、mise `2026.8.6 linux-x64`、widgets/hooks/bindings/completion 通过，覆盖典型 x86_64 WSL 资产路径。
- macOS 真实 HOME 的 30 次新 shell PTY：`startup -> ZLE ready` median `132.352 ms`、p95 `145.562 ms`；`first key -> ZLE redraw` median `1.116 ms`、p95 `1.276 ms`。

最后一组 startup 指标以完整 prompt 后进入 ZLE 为终点，严格于 `zsh -i -c exit`，不应与前文的简单启动 p50 直接比较；首字符 redraw 则直接验证迁移后的输入路径不再出现原 Zinit 延迟调度造成的首键 hitch。

## 主要资料

- [Zimfw 官方 README：手动安装、`ZIM_HOME`、`ZIM_CONFIG_FILE`、模块与更新命令](https://github.com/zimfw/zimfw)
- [mise 官方安装文档：standalone binary、固定版本、路径与校验](https://mise.jdx.dev/installing-mise.html)
- [Starship 官方仓库：跨平台安装与 Zsh 初始化](https://github.com/starship/starship)
- [kubectl 官方 Zsh completion 文档](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_completion/)
- [Flux 官方 Zsh completion 文档](https://fluxcd.io/flux/cmd/flux_completion_zsh/)
- [Helm 官方命令文档](https://helm.sh/docs/helm/)
