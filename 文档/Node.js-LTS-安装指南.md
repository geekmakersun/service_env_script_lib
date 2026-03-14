# Node.js LTS 安装指南

## 1. 安装 nvm

使用 curl 命令从 GitHub 仓库下载并安装 nvm：

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
```

安装完成后，重新加载 bashrc 文件以使用 nvm 命令：

```bash
source /root/.bashrc
```

## 2. 安装最新 LTS 版本的 Node.js

使用 nvm 安装最新的 LTS 版本的 Node.js：

```bash
nvm install --lts
```

## 3. 设置全局默认版本

将安装的 LTS 版本设置为全局默认版本：

```bash
nvm alias default node
```

## 4. 验证安装

验证 Node.js 和 npm 版本：

```bash
node -v
npm -v
```

## 5. 常用 nvm 命令

- 查看已安装的 Node.js 版本：
  ```bash
  nvm ls
  ```
- 切换到特定版本：
  ```bash
  nvm use <版本号>
  ```
- 查看可用的 Node.js 版本：
  ```bash
  nvm ls-remote
  ```

## 6. 注意事项

- nvm 仅在当前终端会话中有效，如需在新终端中使用，需要确保 bashrc 文件已正确配置
- 安装全局 npm 包时，建议在特定的 Node.js 版本下进行，以避免版本冲突

***

**文档创建时间**：2026-03-14
**适用系统**：Linux
**测试环境**：Ubuntu/Debian 系列
