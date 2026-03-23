#!/usr/bin/env bash

#用到哪，学到哪。
#bash <(curl -sSL https://get.docker.com)；安装docker
#export PATH="/目录/文件:$PATH"；ln -s ${文件} /usr/local/bin；终端输入进程/脚本名称可直接运行
#vim按下i进入编辑模式；按下ecs退出编辑模式；输入:wq!强制保存退出；输入:q!退出不保存
#iptables -A INPUT -p tcp --dport 端口 -j ACCEPT
#ps -ef | grep 进程 | grep -v grep | awk '{print $2}'；查找进程ID
#awk -F '"' '{print $4}' | cut -c 2-；以"为分隔号；-c 2显示第二个字符；-c 2-从第二个字符开始显示
#awk -F '.' 'NR==1 {print $4}'；以.为分隔号；打印第一行第四列
#awk中/ /是正则表达式；^表示字符串中开始的位置；d/-分别是权限中开始字符
#ls -l /目录 | awk '/^d/ {print $NF}'；打印/目录下的子目录
#ls -l /目录 | awk '/^-/ {print $NF}'；打印/目录下的文件
#sed -i 's|/目录/文件|替换|g; s#目录/文件#替换#g' /目录/文件；含有路径时；分隔符需要把/换成|
#sed -i "s/目标/$替换/g" /目录/文件；引用变量需要把'换成"或'"$替换"'
#sed -i '$a '"$变量"'\n文本' /目录/文件；在最后一行$a插入；引用变量需要'"$"'
#echo -e "文本\n换行\n" > /目录/文件；不存在则创建；存在则覆盖
#tar -zcvf 文件.tar.gz /目录
#tar -xzvf /目录/文件.tar.gz -C /解压指定目录
#base64 -w 0 Mu.tar.gz > Mu.txt；base64编码
#base64 -d /etc/nginx/Mu.txt > /etc/nginx/Mu.tar.gz；base64解码
#cat > file << EOF；覆盖&转义(文本中不需要转义的特殊符号前加\)
#cat >> file << 'EOF'；追加&禁止转义(开头EOF加上''即可)
# ！(非、不是)；
#if [ -s "文件" ]；目录/文件存在且size大于0
#if [ -d "目录" ]；目录存在
#if [ -f "文件" ]；文件存在
#if [ -z "$str" ]；变量长度为0
#if [ -n "$str" ]；变量非空
#if ! type "nginx" ; then 安装; fi；如果命令不存在则安装
#if grep -qi "$str" /etc/文件 || grep -qi "$str" /var/文件 ; then 当无判断函数；只检测命令时；无需使用括号；记得加空格
#-f/-gt等判断函数需要用[]；有多个连接符号||并存在[]；最外层需要用{}；记得加空格
#if [[ -f "文件" && -n "$(cat /文件)" ]]; then 多个-f/-gt等判断函数且有连接符号&&；只需在最外层使用[[]]
#if { [ -d "目录" ] && grep -qi "$str" /目录; } || { [ -f "文件" ] && grep -qi "$str" /目录; }; then 如果目录存在并检索到变量或者文件存在并检索到变量
#set -ue(退出报错)；set -x(显示命令)

set -u
red(){  echo -e "\e[31m$1\e[0m";}
blue(){  echo -e "\e[34m$1\e[0m";}
purple(){  echo -e "\e[35m$1\e[0m";}
cyan(){  echo -e "\e[36m$1\e[0m";}
readp(){  read -p "$(cyan "$1")" $2;}

HTTP(){
  if [ ! -d /etc/nginx/html ]; then
    cat > /etc/nginx/nginx.conf << 'HTTP'
pid #/nginx.pid;
worker_processes auto;
error_log /var/log/nginx/error.log;
events {
  multi_accept on;
  worker_connections 1024;
}
http {
  include mime.types;
  default_type application/octet-stream;
  map $http_x_forwarded_for $client_ip {
    "" $remote_addr;
    "~*(?P<firstAddr>([0-9a-f]{0,4}:){1,7}[0-9a-f]{1,4}|([0-9]{1,3}\.){3}[0-9]{1,3})$" $firstAddr;
  } #创建自定义变量 $client_ip 实现 CDN 获取到客户端真实 IP
  log_format main '$client_ip - $remote_user [$time_local] "$request"'
                  '$status $body_bytes_sent "$http_referer"'
                  '"$http_user_agent" "$http_x_forwarded_for"';
  access_log /var/log/nginx/access.log main;
  sendfile on;
  server_tokens off;
  keepalive_timeout 65;
  ssl_prefer_server_ciphers on;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
  include #/etc/nginx;
}
HTTP
  sed -i "s|#/nginx.pid|${nginxpid}|g; s|#/etc/nginx|${nginxconf}|g" /etc/nginx/nginx.conf
  blue "解压html。"
  echo "" | base64 -d | tee /etc/nginx/html.tar.gz > /dev/null
  tar -xzvf /etc/nginx/html.tar.gz
  rm -rf /etc/nginx/html.tar.gz
}

DEST(){
  if [ ! -f "$serverjson" ]; then REALITY; fi
  if [ "$(echo "$nginxversion" | awk -F '.' '{print $2}')" -ge 25 ] && [ "$(echo "$nginxversion" | awk -F '.' '{print $3}')" -gt 0 ]; then
    nginxhttp="ssl proxy_protocol;http2 on;"
  else
    nginxhttp="ssl http2 proxy_protocol;"
  fi
  cat > $nginxconf << DEST
server {
  listen 80;
  listen [::]:80;
  return 301 https://\$host\$request_uri;
}
server {
  listen 127.0.0.1:44380 default_server $nginxhttp
  set_real_ip_from 127.0.0.1;
  real_ip_header proxy_protocol;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_reject_handshake on;
} #限定域名连接，禁止其他方式访问网站
server {
  listen 127.0.0.1:44380 $nginxhttp
  set_real_ip_from 127.0.0.1;
  real_ip_header proxy_protocol;
  server_name cdn$serverdomain; #修改 CDN 域名
  ssl_certificate ${nginxcertpath}/${serverdomain}/fullchain.pem; #修改 CDN 域名证书
  ssl_certificate_key ${nginxcertpath}/${serverdomain}/privkey.pem; #修改 CDN 域名证书
  location /$(grep '"path"' $serverjson | awk -F '"' '{print $4}') { #与 reality-xhttp 中 path 对应
    grpc_pass grpc://127.0.0.1:44308; #转发 reality-xhttp 监听进程
    grpc_set_header Host \$host;
    grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }
  location / {
    root /etc/nginx/Mu;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
  }
}
server {
  #listen 443 quic reuseport; #版本不小于 v1.25.0 且 SSL 库支持 QUIC
  #listen [::]:443 quic reuseport; #版本不小于 v1.25.0 且 SSL 库支持 QUIC
  listen 127.0.0.1:44380 $nginxhttp
  set_real_ip_from 127.0.0.1;
  real_ip_header proxy_protocol;
  server_name $serverdomain;
  ssl_certificate ${nginxcertpath}/${serverdomain}/fullchain.pem;
  ssl_certificate_key ${nginxcertpath}/${serverdomain}/privkey.pem;
  location /$(grep '"path"' $serverjson | awk -F '"' '{print $4}') { #与 reality-xhttp 中 path 对应
    grpc_pass grpc://127.0.0.1:44308; #转发 reality-xhttp 监听进程
    grpc_set_header Host \$host;
    grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }
  location / {
    root /etc/nginx/Mu;
    add_header Alt-Svc 'h3=":443"; ma=86400'; #通告 HTTP/3 server 的可用性
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
  }
  location ~ ^/s/(x|m)/(.*) {
    default_type 'text/plain; charset=utf-8';
    alias ${nginxsubpath}/\$1/\$2;
  }
}
#1、reality+vision 和 reality+xhttp 客户端仅使用 www.example.com 域名连接。
#2、xhttp+tls 客户端可使用 www.example.com 或 cdn.example.com 域名连接。
DEST
  pkill -9 nginx && service nginx restart && purple "Nginx配置完成！"
}

REALITY(){
  if [ ! -f "$serversystem" ]; then SERVICE; fi
  serveruuid="$(xray uuid)"
  serverx25519="$(xray x25519)"
  serverprivate="$(echo "$serverx25519" | grep "PrivateKey" | awk '{print $2}')"
  serverpublic="$(echo "$serverx25519" | grep "Password" | awk '{print $2}')"
  cat > $serverjson << REALITY
{
  "log": {
    "loglevel": "warning",
    "access": "${serverpath}/access.log",
    "error": "${serverpath}/error.log"
  },
  "dns": {
    "servers": [
      "https+local://1.1.1.1/dns-query", // 首选 1.1.1.1 的 DoH 查询，牺牲速度但可防止 ISP 偷窥
      "localhost"
    ]
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "ip": ["geoip:cn"],
        "outboundTag": "block"
      }
    ]
  },
  "inbounds": [
    {
      "tag": "XTLS",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$serveruuid",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 44308  //回落 reality-xhttp 监听进程
          }
        ]
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "target": 44380,  //转发 Nginx 监听进程
          "xver": 1,
          "serverNames": ["$serverdomain"],
          "privateKey": "$serverprivate",
          "shortIds": ["1a2b3c4d5e6f"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      }
    },
    {
      "tag": "XHTTP",
      "listen": "127.0.0.1",
      "port": 44308,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$serveruuid",
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "host": "",  // 服务端不验证 host 客户端玩法更多
          "mode": "auto",  // 服务端设置 auto 客户端玩法更多
          "path": "$serverpublic"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      }
    },
    {
      "tag": "XKCP",
      "port": 10723,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$serveruuid",
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "kcp",
        "mtu": 900,
        "tti": 30,
        "uplinkCapacity": 100,
        "downlinkCapacity": 200,
        "congestion": true,
        "readBufferSize": 5,
        "writeBufferSize": 5,
        "finalmask": {
          "udp": [
            {
              "type": "header-utp"
            },
            {
              "type": "mkcp-aes128gcm",
              "settings": {
                "password": "$serveruuid"
              }
            }
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    }
  }
}
#1、reality+vision 和 reality+xhttp 客户端仅使用 www.example.com 域名连接。
#2、xhttp+tls 客户端可使用 www.example.com 或 cdn.example.com 域名连接。
REALITY
  service $servername restart && purple "Xray配置完成！"
}

RCINITD(){
  if [ ! -f "$serverprocess" ]; then DOWNLOAD; fi
  if [ ! -f "$serversystem" ]; then
    cat > $serversystem << RCINITD
#!/sbin/openrc-run
name="$servername"
description="$servername Service"
supervisor=supervise-daemon
respawn_delay=5
respawn_max=2
respawn_period=600
pidfile="/run/\${RC_SVCNAME}.pid"
rc_ulimit="-u 10240 -n 102400"
capabilities="^cap_net_bind_service,^cap_net_admin,^cap_net_raw"
extra_commands="checkconfig"
confdir=${confdir:-"$serverpath"}
command="$serverprocess"
command_args="run -confdir \$confdir"
required_files="\$confdir"
depend() {
  need net
  want dns ntp-client
  after firewall
}
checkconfig() {
  \$command \$command_args -test
  eend \$?
}
start_pre() {
  checkconfig || return 1
}
RCINITD
    chmod +x $serversystem; $serverenable; service $servername start
  fi
}

SYSTEMD(){
  if [ ! -f "$serverprocess" ]; then DOWNLOAD; fi
  if [ ! -f "$serversystem" ]; then
    cat > $serversystem << SYSTEMD
[Unit]
Description=$servername Service
After=network.target nss-lookup.target
[Service]
ExecStart=$serverprocess run -confdir $serverpath
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10240
LimitNOFILE=102400
RuntimeDirectory=$servername
RuntimeDirectoryMode=0755
[Install]
WantedBy=multi-user.target
SYSTEMD
    chmod +x $serversystem; $serverenable; service $servername start
  fi
}

DOWNLOAD(){
  if [ ! -d "${nginxcertpath}/${serverdomain}" ]; then CERT; fi
  while true; do
    while true; do
      blue "$serverurl，正在下载。"
      curl -O -L -H 'Cache-Control: no-cache' $serverurl -#
      if unzip -t $serverfile; then
        break
      else
        sleep 15 && servertag="" && servertag="$(curl -sf $serverapi | grep '"tag_name"' | awk -F '"' '{print $4}')" && serverurl="${serversite}/${servertag}/${serverfile}"
      fi
    done
    blue "$serverurl.dgst，正在下载。"
    curl -O -L -H 'Cache-Control: no-cache' $serverurl.dgst -#
    serverzip="$(sha256sum $serverfile | awk '{printf $1}')"
    serverdgst="$(awk -F '= ' '/256=/ {print $2}' $serverfile.dgst)"
    if [ "$serverdgst" == "$serverzip" ]; then
      blue "check！"
      mkdir -p -m 644 $serverpath
      unzip -oj $serverfile -d $serverpath
      ln -sf ${serverpath}/${servername} /usr/local/bin
      rm -rf $serverfile
      rm -rf $serverfile.dgst
      break
    fi
  done
  if [ -f "$serversystem" ]; then service $servername restart; fi
}

DOMAIN(){
  if [[ -d "$nginxcertpath" && -n "$(ls -l $nginxcertpath | awk '/^d/ {print $NF}')" ]]; then
    serverdomain="$(ls -l $nginxcertpath | awk '/^d/ {print $NF}')"
  else
    readp "请输入域名：" serverdomain
    purple "域名：$serverdomain"
    while true; do readp "请确认域名[yes/no]：" input; case "$input" in [yY][eE][sS]|[yY]) purple "已确认。"; break;; [nN][oO]|[nN]) readp "请输入域名：" serverdomain; purple "域名：$serverdomain";; *) red "请重新输入！"; continue;; esac; done
  fi
}

CERT(){
  if [ -z "$serverdomain" ]; then DOMAIN; fi
  if [ -d "${nginxcertpath}/${serverdomain}" ]; then
    blue "续签SSL证书。"
    certbot renew --deploy-hook 'service nginx restart'
  else
    HTTP
    blue "申请SSL证书。"
    rm -rf /etc/letsencrypt/{archive,live,renewal}
    echo -e "0 0 1 * * certbot renew --deploy-hook 'service nginx restart'" > /var/spool/cron/crontabs/root
    echo -e "server {\n    listen 80;\n    listen [::]:80;\n    server_name $serverdomain;\n}" > $nginxconf
    service nginx restart && certbot --nginx --agree-tos -n -m ssl@cert.bot -d $serverdomain
  fi
}

SSHD(){
  if [ ! -f /etc/ssh/sshd_config.d/sshd.conf ]; then
    readp "请输入SSH端口：" serversshd
    purple "SSH端口：$serversshd"
    echo -e "PermitRootLogin yes\nPubkeyAuthentication yes\nPasswordAuthentication no\nPort $serversshd" > /etc/ssh/sshd_config.d/sshd.conf
    service ssh restart
    if [ -f /usr/lib/systemd/system/ssh.socket ]; then sed -i "s/22/$serversshd/g" /usr/lib/systemd/system/ssh.socket && systemctl restart ssh.socket; fi
    ufw allow $serversshd; ufw allow 80/tcp; ufw allow 80/udp; ufw allow 443/tcp; ufw allow 443/udp; ufw allow 10723/tcp; ufw allow 10723/udp; ufw allow 23710/tcp; ufw allow 23710/udp; echo "y" | ufw enable >/dev/null
  fi
}

SUBSCRIBE(){
  xdomain="$(grep '"serverNames"' $serverjson | awk -F '"' '{print $4}')"
  xuuid="$(grep '"id"' $serverjson | awk -F '"' 'NR==1 {print $4}')"
  xpublic="$(grep '"path"' $serverjson | awk -F '"' '{print $4}')"
  xsid="$(grep '"shortIds"' $serverjson | awk -F '"' '{print $4}')"
  #xipv4="$(curl -s -4 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')"
  #xipv6="$(curl -s -6 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')"
  mkdir -p -m 555 ${nginxsubpath}/x
  mkdir -p -m 555 ${nginxsubpath}/m
  cat > ${nginxsubpath}/xray << XSUB
vless://${xuuid}@${xdomain}:443?type=tcp&flow=xtls-rprx-vision&fp=chrome&security=reality&sni=${xdomain}&pbk=${xpublic}&sid=${xsid}#XTLS
vless://${xuuid}@${xdomain}:443?type=xhttp&path=${xpublic}&mode=auto&fp=chrome&security=reality&sni=${xdomain}&pbk=${xpublic}&sid=${xsid}#XHTTP
vless://${xuuid}@${xdomain}:10723?&type=kcp&headerType=utp&mtu=100&tti=30&up=100&down=300&seed=${xuuid}&udp=xudp#XKCP

XSUB
  cat > ${nginxsubpath}/mihomo << MSUB
proxies:
  - name: "XTLS"
    type: vless
    server: $xdomain
    port: 443
    uuid: $xuuid
    flow: xtls-rprx-vision
    network: tcp
    tls: true
    skip-cert-verify: false
    servername: $xdomain
    reality-opts:
      public-key: $xpublic
      short-id: $xsid
    udp: true
    packet-encoding: xudp
    client-fingerprint: chrome
  - name: "XHTTP"
    type: vless
    server: $xdomain
    port: 443
    uuid: $xuuid
    network: xhttp
    tls: true
    skip-cert-verify: false
    servername: $xdomain
    reality-opts:
      public-key: $xpublic
      short-id: $xsid
    xhttp:
      path: $xuuid
      mode: auto
    udp: true
    packet-encoding: xudp
    client-fingerprint: chrome
  - name: "XKCP"
    type: vless
    server: $xdomain
    port: 10723
    uuid: $xuuid
    network: kcp
    congestion-controller: bbr
    up: 100
    down: 300
    mtu: 100
    tti: 30
    password: $xuuid
MSUB
  if [[ -f "${nginxsubpath}/subapi" && -n "$(cat ${nginxsubpath}/subapi)" ]]; then
    serversalt="$(cat ${nginxsubpath}/subapi)"
  else
    readp "请输入salt值：" serversalt
    echo "$serversalt" > ${nginxsubpath}/subapi
  fi
  rm -rf ${nginxsubpath}/x/*
  rm -rf ${nginxsubpath}/m/*
  serveruser="$(echo -n "${servername}${serversalt}"$'\n' | md5sum | awk '{print $1}')"
  serverbase="$(base64 -w 0 ${nginxsubpath}/xray)"
  echo "$serverbase" > ${nginxsubpath}/x/${serveruser}
  cat ${nginxsubpath}/mihomo > ${nginxsubpath}/m/${serveruser}
  chmod -R 555 $nginxsubpath
  subxlink="https://${serverdomain}/s/x/${serveruser}"
  submlink="https://${serverdomain}/s/m/${serveruser}"
  blue "\nXray\n"; purple "$subxlink\n"; $qrcmd "$subxlink"; blue "\nMihomo\n"; purple "$submlink\n"; $qrcmd "$submlink"
}

Nginx(){
  while true; do
    purple "\n检测到$serverdomain证书。\n"
    blue "1、续签证书"
    blue "2、更改域名"
    blue "3、退出"
    purple ""
    readp "请输入选项：" option
    case "$option" in
      1) CERT; DEST; return;;
      2) DOMAIN; CERT; REALITY; DEST; return;;
      3) return;;
      *) red "请重新输入！"; continue;;
    esac
  done
}

Xray(){
  while true; do
    purple "\n检测到"$(xray version | awk 'NR==1 {print $2}')"版本。\n"
    blue "1、升级内核"
    blue "2、订阅链接"
    blue "3、退出"
    purple ""
    readp "请输入选项：" option
    case "$option" in
      1) DOWNLOAD; return;;
      2) SUBSCRIBE; return;;
      3) return;;
      *) red "请重新输入！"; continue;;
    esac
  done
}

MENU(){
  while true; do
    purple ""
    blue "1、Xray"
    blue "2、Nginx"
    blue "3、Exit"
    purple ""
    readp "请输入选项：" option
    case "$option" in
      1) Xray; continue;;
      2) Nginx; continue;;
      3) break;;
      *) red "请重新输入！"; continue;;
    esac
  done
}

CHECK(){
  if [ -z "$release" ]; then
    red "未知架构！"
    exit 0
  elif [ "$release" == alpine ]; then
    if ! type "nginx" "certbot" "unzip" "tar" "qr" "ufw" >/dev/null 2>&1; then
      blue "开始安装。"
      apk update && apk add nginx certbot certbot-nginx unzip tar py3-qrcode ufw
    fi
    serversystem="/etc/init.d/${servername}"
    serverenable="rc-update add $servername"
    nginxpid="/run/nginx/nginx.pid"
    nginxconf="/etc/nginx/http.d/default.conf"
    qrcmd="qr --ascii"
    RCINITD
  elif [ "$release" == debian ] || [ "$release" == ubuntu ]; then
    if ! type "nginx" "certbot" "unzip" "tar" "qrencode" "ufw" >/dev/null 2>&1; then
      blue "开始安装。"
      apt-get update -y && apt install -y nginx certbot python3-certbot-nginx unzip tar qrencode ufw
    fi
    serversystem="/etc/systemd/system/${servername}.service"
    serverenable="systemctl enable $servername"
    nginxpid="/run/nginx.pid"
    nginxconf="/etc/nginx/sites-enabled/default"
    qrcmd="qrencode -m 1 -t UTF8i"
    SYSTEMD
  fi
}

if { [ -f "/etc/issue" ] && grep -qi "Alpine" /etc/issue; } || { [ -f "/etc/os-release" ] && grep -qi "ID=alpine" /etc/os-release; }; then
  release="alpine"
elif { [ -f "/etc/issue" ] && grep -qi "debian" /etc/issue; } || { [ -f "/etc/os-release" ] && grep -qi "ID=debian" /etc/os-release; }; then
  release="debian"
elif { [ -f "/etc/issue" ] && grep -qi "Ubuntu" /etc/issue; } || { [ -f "/etc/os-release" ] && grep -qi "ID=ubuntu" /etc/os-release; }; then
  release="ubuntu"
fi

case "$(uname -m)" in
  amd64 | x86_64) serverfile="Xray-linux-64.zip";;
  armv8 | aarch64) serverfile="Xray-linux-arm64-v8a.zip";;
  i386 | i686) serverfile="Xray-linux-32.zip";;
  *) red "未知架构！"; exit 0;;
esac

servername="xray"
serversite="https://github.com/XTLS/Xray-core/releases/download"
serverapi="https://api.github.com/repos/XTLS/Xray-core/releases/latest"
servertag="$(curl -sf "$serverapi" | grep '"tag_name"' | awk -F '"' '{print $4}')"
serverurl="${serversite}/${servertag}/${serverfile}"
serverpath="/etc/aio/${servername}"
serverprocess="${serverpath}/${servername}"
serverjson="${serverpath}/${servername}.json"
nginxversion="$(nginx -v 2>&1)"
nginxsubpath="/etc/aio/subscribe"
nginxcertpath="/etc/letsencrypt/live"

purple "\nMu"

CHECK
DOMAIN
MENU
SSHD

purple "\nEnd!"
