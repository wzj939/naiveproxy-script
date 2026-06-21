#!/bin/bash
set -e

# 彩色输出
red='\e[91m'; green='\e[92m'; yellow='\e[93m'; cyan='\e[96m'; none='\e[0m'
_error(){ echo -e "${red}❌ $*${none}"; }
_info(){ echo -e "${cyan}ℹ️ $*${none}"; }
_ok(){ echo -e "${green}✅ $*${none}"; }

[[ $(id -u) != 0 ]] && _error "请用 root 用户运行" && exit 1

domain=""; email=""; user="User"
password=$(cat /proc/sys/kernel/random/uuid)
naive_port=443

install_deps(){ apt-get update -y; apt-get install -y curl wget git tar unzip certbot; }

install_go_prebuilt(){
    _info "正在下载并安装官方预编译的 Go..."
    wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz -O /tmp/go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    export PATH=/usr/local/go/bin:$PATH
    _ok "Go 已安装到 /usr/local/go"
    go version
}

check_go_version(){
    if command -v go >/dev/null 2>&1; then
        current_go=$(go version | awk '{print $3}' | sed 's/go//')
        major=$(echo $current_go | cut -d. -f1)
        minor=$(echo $current_go | cut -d. -f2)
        if [[ $major -lt 1 || $minor -lt 21 ]]; then
            _info "Go 版本过低，自动安装预编译版本..."
            install_go_prebuilt
        else
            _ok "检测到已安装的 Go，版本满足要求: $current_go"
        fi
    else
        _info "系统未检测到 Go，自动安装预编译版本..."
        install_go_prebuilt
    fi
}

build_caddy(){
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    ~/go/bin/xcaddy build \
      --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive
    mv caddy /usr/bin/caddy; chmod +x /usr/bin/caddy
}

check_domain(){
    server_ip=$(curl -s https://ipinfo.io/ip)
    resolved_ip=$(curl -sH 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$domain&type=A" | grep -oE "([0-9]{1,3}\\.){3}[0-9]{1,3}" | head -1)
    [[ "$resolved_ip" == "$server_ip" ]] || { _error "域名解析错误: $domain -> $resolved_ip (服务器IP: $server_ip)"; exit 1; }
}

write_caddy_json(){
    mkdir -p /etc/caddy /var/www/html
    cat > /etc/caddy/config.json <<EOF
{
  "apps": {
    "http": {
      "servers": {
        "naive": {
          "listen": [":$naive_port"],
          "routes": [
            {
              "handle": [
                {
                  "handler": "forward_proxy",
                  "auth_user": "$user",
                  "auth_pass": "$password",
                  "hide_ip": true,
                  "hide_via": true,
                  "probe_resistance": true
                },
                {
                  "handler": "file_server",
                  "root": "/var/www/html"
                }
              ]
            }
          ]
        }
      }
    }
  },
  "tls": {
    "automation": {
      "policies": [
        {
          "subjects": ["$domain"],
          "issuer": {
            "module": "acme",
            "email": "$email"
          }
        }
      ]
    }
  }
}
EOF
}

systemd_service(){
    cat > /etc/systemd/system/naive.service <<EOF
[Unit]
Description=NaiveProxy (Caddy JSON)
After=network.target
[Service]
ExecStart=/usr/bin/caddy run --config /etc/caddy/config.json --adapter json
ExecReload=/usr/bin/caddy reload --config /etc/caddy/config.json --adapter json
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload; systemctl enable naive; systemctl restart naive
}

add_cron(){
    cat > /etc/caddy/.renew.sh <<EOF
#!/usr/bin/env bash
systemctl stop naive
certbot renew
systemctl start naive
EOF
    chmod +x /etc/caddy/.renew.sh
    if [ `grep -c "caddy" /var/spool/cron/root 2>/dev/null` -lt '1' ]; then
        mkdir -p /var/spool/cron/; touch /var/spool/cron/root
        echo "0 1 * * * /etc/caddy/.renew.sh" >> /var/spool/cron/root
    fi
    _ok "证书自动续签 cron 已设置"
}

update_script(){
    _info "正在从 GitHub Release 拉取最新脚本..."
    repo_url="https://github.com/<你的GitHub用户名>/<你的仓库名>/releases/latest/download/naiveproxy.sh"
    wget -O /root/naive.sh $repo_url
    chmod +x /root/naive.sh
    ln -sf /root/naive.sh /usr/local/bin/naive
    _ok "脚本已更新到最新版本，请重新运行: naive"
    exit 0
}

show_info(){ cat /etc/caddy/config.json; systemctl status naive --no-pager; }
edit_config(){ read -p "新域名: " d; [ -z "$d" ] || domain=$d; write_caddy_json; systemctl restart naive; }
optimize(){ curl -s https://github.com/teddysun/across/raw/master/bbr.sh | bash; }
uninstall(){ systemctl stop naive; systemctl disable naive; rm -f /usr/bin/caddy /etc/caddy/config.json /etc/systemd/system/naive.service; }
restart_naive(){ systemctl restart naive; _ok "NaiveProxy 已重启"; }

install_naive(){
    read -p "请输入域名: " domain
    read -p "请输入邮箱: " email
    install_deps; check_go_version; build_caddy; check_domain
    write_caddy_json
    systemd_service
    add_cron
}

update_naive(){ check_go_version; build_caddy; systemctl restart naive; }

menu(){
    while true; do
        echo -e "
${yellow}NaiveProxy 管理脚本 (JSON 配置)${none}
1. 安装/更新
2. 显示信息
3. 修改配置
4. 优化(BBR)
5. 启动服务
6. 停止服务
7. 重启服务
8. 更新脚本
9. 卸载
0. 退出"
        read -p "请选择: " c
        case $c in
            1) echo "1. 安装 NaiveProxy"; echo "2. 更新到最新版"; read -p "请输入选项: " sub; [[ $sub == 1 ]] && install_naive || [[ $sub == 2 ]] && update_naive ;;
            2) show_info ;;
            3) edit_config ;;
            4) optimize ;;
            5) systemctl start naive; _ok "服务已启动" ;;
            6) systemctl stop naive; _ok "服务已停止" ;;
            7) restart_naive ;;
            8) update_script ;;
            9) uninstall; _ok "已卸载"; exit 0 ;;
            0) exit 0 ;;
            *) _error "输入错误" ;;
        esac
    done
}

menu
