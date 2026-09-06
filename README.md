# Grow · 封城之后 —— 源代码与工程说明

## 引擎与依赖

- 引擎：**Godot 4.7.2（标准版，非 mono）**，官网 https://godotengine.org/download
- 导出模板：Godot_v4.7.2-stable_export_templates.tpz（与引擎版本一致，编辑器内「编辑器 → 管理导出模板」下载，或从 Godot 官方 GitHub Releases 下载）
- 无其他第三方依赖

## 目录结构

| 目录 / 文件 | 说明 |
|---|---|
| `scenes/Main.tscn` | 主场景（游戏入口） |
| `scripts/` | 游戏逻辑（Main / CardView / ShoppingCard / GameData / Audio 等） |
| `data/` | 事件、结局、结算提示、图片清单等数据脚本与设计文档 |
| `art/` `audio/` `fonts/` | 美术 / 音频 / 字体素材 |
| `export_presets.cfg` | 导出预设（Windows Desktop 与 Web 两套） |

## 生成可执行版本

方式一（编辑器）：
1. 用 Godot 4.7.2 打开本目录的 `project.godot`；
2. 菜单「项目 → 导出」，选择 `Windows Desktop` 或 `Web` 预设，点击「导出项目」。

方式二（命令行）：

```bat
Godot_v4.7.2-stable_win64_console.exe --path . --headless --import
Godot_v4.7.2-stable_win64_console.exe --path . --headless --export-release "Windows Desktop" builds/Grow.exe
Godot_v4.7.2-stable_win64_console.exe --path . --headless --export-release "Web" builds/web/index.html
```

导出产物位于 `builds/`（见 release 文件夹中的成品示例）。

## 直接运行（开发模式）

用 Godot 4.7.2 打开工程后按 F5 即可运行。

## 设计文档

事件数值与文案规范见 `data/EVENTS_PLAN.md`，图片素材编号规范见 `data/IMAGE_LIST.md`。
