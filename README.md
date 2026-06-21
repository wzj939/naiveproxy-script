# NaiveProxy 一键管理脚本 (JSON 配置版)

这是一个基于 **Caddy + Naive 插件** 的一键管理脚本，使用 **JSON 配置文件**，支持安装、更新、配置修改、服务管理、优化 (BBR)、证书自动续签 cron 任务，以及脚本自更新功能。

---

## 功能特性
- 安装/更新二级菜单：先选择安装还是更新
- 域名解析检测：确保域名正确解析到服务器 IP
- Go 自动安装：下载并安装官方预编译的 Go 二进制包
- Caddy 构建：使用 xcaddy 自动编译带 Naive 插件的 Caddy
- 服务管理：启动、停止、重启、卸载
- 配置修改：修改域名、端口、用户、密码、邮箱
- 信息显示：查看当前 JSON 配置和服务状态
- 优化：一键开启 BBR
- 证书自动续签：每天凌晨 1 点执行续签脚本
- 脚本自更新：从 GitHub Release 拉取最新脚本

---

## 安装方法
一键安装命令组合（下载、赋权、软链接三步合并）：

```bash
wget -O /root/naive.sh https://github.com/wzj939/naiveproxy-script/releases/latest/download/naive.sh && chmod +x /root/naive.sh && ln -sf /root/naive.sh /usr/local/bin/naive
