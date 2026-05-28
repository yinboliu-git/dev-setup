# 开发环境一键安装工具

Windows 一键安装Claude Code和deepseek后端脚本，快速搭建 AI 开发环境。

## 安装内容

| 工具 | 说明 |
|------|------|
| **Git for Windows** (Git Bash) | 版本控制 + MinGW 终端环境 |
| **Miniconda** | Python 环境管理 |
| **Node.js + npm** | JavaScript 运行时 |
| **Claude Code** | AI 编程助手 (默认 2.1.150) |
| **Web 仪表盘** | 配置管理前端页面 |

## 使用方法

1. 下载本项目
2. 双击 `install.bat`
3. 按提示完成配置
4. 自动打开 Web 仪表盘

## 配置项

- Git 用户名 / 邮箱
- VPN / 代理端口
- AI 后端 URL / API Key (DeepSeek 等)

## 系统要求

- Windows 10 1809+ 或 Windows 11
- 管理员权限
- 网络连接

## 项目结构

```
├── install.bat          # 双击运行入口
├── setup.ps1            # 主安装脚本
├── scripts/             # 安装模块
│   ├── check-system.ps1
│   ├── install-git.ps1
│   ├── install-conda.ps1
│   ├── install-node.ps1
│   ├── install-claude.ps1
│   └── setup-env.ps1
├── frontend/            # Web 仪表盘
│   ├── index.html
│   ├── style.css
│   └── app.js
└── config/
    └── config.template.json
```
