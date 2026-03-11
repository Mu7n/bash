

case $(uname -m) in amd64 | x86_64) arch_sh="64";; armv8 | aarch64) arch_sh="arm64-v8a";; i386 | i686) arch_sh="32";; *) red "未知系统！";; esac
name_sh="xray"
link_sh="https://github.com/XTLS/Xray-core/releases/download"
api_sh="$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest)"
tag_sh="$(echo "$api_sh" | grep '"tag_name"' | awk -F '"' '{print $4}')"
file_sh="Xray-linux-${arch_sh}.zip"
url_sh="${link_sh}/${tag_sh}/${file_sh}"
path_sh="/etc/aio/${name_sh}"
grep_sh="$(ps -ef | grep $name_sh | grep -v grep | awk '{print $8}')"

sh_unzip(){
  mkdir -p -m 644 $path_sh
  unzip -oj $file_sh -d $path_sh
  rm -rf ${file_sh}
  ln -sf ${path_sh}/${name_sh} /usr/local/bin
}

sh_file(){
  while true; do
    blue "$url_sh，正在下载。"
    curl -f -O -L -H 'Cache-Control: no-cache' $url_sh -#
    curl -f -O -L -H 'Cache-Control: no-cache' $url_sh.dgst -#
    local_sh="$(sha256sum $file_sh | awk '{printf $1}')"
    check_sh="$(awk -F '= ' '/256=/ {print $2}' $file_sh.dgst)"
    if [ $check_sh != $local_sh ]; then sleep 5; tag_sh=""; tag_sh="$(echo "$api_sh" | grep '"tag_name"' | awk -F '"' '{print $4}')"; url_sh="${link_sh}/${tag_sh}/${file_sh}"; else sh_unzip && break; fi
  done
}

sh_service(){
  cat > /etc/init.d/${name_sh} << XRAY
#!/sbin/openrc-run

name="${name_sh}"
description="${name_sh} Service"

supervisor=supervise
respawn_delay=5
respawn_max=2
respawn_period=600

pidfile="/run/\${RC_SVCNAME}.pid"
rc_ulimit="-n 1024 -u 1024"
capabilities="^cap_net_bind_service,^cap_net_admin,^cap_net_raw"
extra_commands="checkconfig"

command="${path_sh}/${name_sh}"
command_args="run -confdir ${path_sh}"
required_files="${path_sh}"

depend() {
	need net
	want dns ntp-client
	after firewall
}

checkconfig() {
	$command $command_args -test
	eend $?
}

start_pre() {
	checkconfig || return 1
}
XRAY
  if [ ! -z $grep_sh ]; then pkill -9 $name_sh; fi
  chmod 644 /etc/systemd/system/${name_sh}.service; systemctl daemon-reload; systemctl start $name_sh; systemctl enable $name_sh
}
