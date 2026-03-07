#!/bin/bash

set -u
red(){ echo -e "\e[31m$1\e[0m";}
blue(){ echo -e "\e[34m$1\e[0m";}
purple(){ echo -e "\e[35m$1\e[0m";}
cyan(){ echo -e "\e[36m$1\e[0m";}
readp(){ read -p "$(cyan "$1")" $2;}

case $(uname -m) in
  x86_64)     arch_sh="amd64";;
  aarch64)    arch_sh="arm64";;
  *)          red "未知系统！";;
esac

name_sh="frps"
link_sh="https://github.com/fatedier/frp/releases/download"
api_sh="$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest)"
tag_sh="$(echo "$api_sh" | grep '"tag_name"' | awk -F '"' '{print $4}' | cut -c 2-)"
file_sh="frp_${tag_sh}_linux_${arch_sh}.tar.gz"
url_sh="${link_sh}/v${tag_sh}/${file_sh}"
path_sh="/etc/aio/${name_sh}"
grep_sh="$(ps -ef | grep $name_sh | grep -v grep | awk '{print $8}')"
domain_sh="$(ls -l /etc/letsencrypt/live | awk '/^d/ {print $NF}')"

sh_configfrp(){
  cat > ${path_sh}/config.toml << TOML
bindAddr = "0.0.0.0"
bindPort = 60443
kcpBindPort = 60443
vhostHTTPPort = 60443
vhostHTTPSPort = 60443

auth.method = "token"
auth.token = "$token_sh"

#webServer.addr = "0.0.0.0"
#webServer.port = 60080
#webServer.user = "$USERNAME"
#webServer.password = "$PASSWORD"
#subDomainHost = "$domain_sh"

transport.maxPoolCount = 10
transport.tcpKeepalive = 7200
transport.tcpMux = true
transport.tcpMuxKeepaliveInterval = 60
transport.heartbeatTimeout = 90

allowPorts = [
  { single = 3000 },
  { single = 16601 },
  { start = 10000, end = 60000 }
]

log.to = "${path_sh}/${name_sh}.log"
log.level = "info"
log.maxDays = 3
TOML
}

sh_file(){
  mkdir -p -m 644 $path_sh
  rm -rf ${path_sh}/${name_sh}
  while true; do if [ -s ${path_sh}/${name_sh} ]; then rm -rf ${file_sh} frp_${tag_sh}_linux_${arch_sh}; ln -sf ${path_sh}/${name_sh} /usr/local/bin; break; else blue "$url_sh，正在下载。"; curl -OL $url_sh && tar xzvf $file_sh && mv -f frp_${tag_sh}_linux_${arch_sh}/${name_sh} ${path_sh} || sleep 5; tag_sh=""; tag_sh="$(echo "$api_sh" | grep '"tag_name"' | awk -F '"' '{print $4}')"; url_sh="${link_sh}/v${tag_sh}/${file_sh}"; fi; done
}

sh_service(){
  cat > /etc/systemd/system/${name_sh}.service << FRP
[Unit]
Description=$name_sh Service
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=${path_sh}/${name_sh} -c ${path_sh}/config.toml

[Install]
WantedBy=multi-user.target
FRP
  if [ ! -z $grep_sh ]; then pkill -9 $name_sh; fi
  chmod 644 /etc/systemd/system/${name_sh}.service; systemctl daemon-reload; systemctl start $name_sh; systemctl enable $name_sh
}

read_token(){
  readp "请输入username：" USERNAME
  readp "请输入password：" PASSWORD
  token_sh="${USERNAME}${PASSWORD}"
  purple "token：$token_sh"
  while true; do readp "请确认令牌[Yes/No]：" input_sh; case $input_sh in [yY][eE][sS]|[yY]) purple "已确认。"; break;; [nN][oO]|[nN]) readp "请输入username：" USERNAME; readp "请输入password：" PASSWORD; token_sh="${USERNAME}${PASSWORD}"; purple "token：$token_sh";; *) red "请重新输入！"; continue;; esac done
}

sh_sshd(){
  if [ ! -s /etc/ssh/sshd_config.d/sshd.conf ]; then
    readp "请输入SSH端口：" sshd_sh
    purple "SSH端口：$sshd_sh"
    echo -e "PermitRootLogin yes\nPubkeyAuthentication yes\nPasswordAuthentication no\nPort $sshd_sh" > /etc/ssh/sshd_config.d/sshd.conf
    systemctl restart ssh
    if [ -s /usr/lib/systemd/system/ssh.socket ]; then sed -i "s/22/$sshd_sh/g" /usr/lib/systemd/system/ssh.socket && systemctl daemon-reload && systemctl restart ssh.socket; fi
    ufw allow $sshd_sh; ufw allow 60443/tcp; ufw allow 60443/udp; echo "y" | ufw enable >/dev/null
  fi
}

purple "\nMu"

if [ -s ${path_sh}/${name_sh} ]; then
  while true; do
    purple "检测到已安装$name_sh。"
	blue "1、升级"
	blue "2、退出"
	readp "请输入选项：" option_sh
	case $option_sh in 1) sh_file; systemctl restart $name_sh break;; 2) break;; *) red "请重新输入！"; continue;; esac
  done
fi

ufw status; export SYSTEMD_PAGER=""; service $name_sh status

purple "\nEND！"
