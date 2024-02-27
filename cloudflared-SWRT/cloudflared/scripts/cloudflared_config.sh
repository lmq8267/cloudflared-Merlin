#!/bin/sh

source /jffs/softcenter/scripts/base.sh
eval `dbus export cloudflared_`
mkdir -p /tmp/upload
cfd_enable=`dbus get cloudflared_enable`
cfd_cron_time=`dbus get cloudflared_cron_time`
cfd_cron_hour_min=`dbus get cloudflared_cron_hour_min`
cfd_cron_type=`dbus get cloudflared_cron_type`
cfd_logs=/tmp/upload/cloudflared.log
cputype=$(uname -ms | tr ' ' '_' | tr '[A-Z]' '[a-z]')
[ -n "$(echo $cputype | grep -E "linux.*armv.*")" ] && cpucore="arm"
[ -n "$(echo $cputype | grep -E "linux.*armv7.*")" ] && [ -n "$(cat /proc/cpuinfo | grep vfp)" ] && cpucore="arm"
[ -n "$(echo $cputype | grep -E "linux.*aarch64.*|linux.*armv8.*")" ] && cpucore="aarch64"
scriptname=$(basename $0)
  proxy_url="https://hub.gitmirror.com/"
  proxy_url2="http://gh.ddlc.top/"
  
logg () {
   echo "【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:  $1" >>${cfd_logs}
   echo -e "\033[36;1m【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】: \033[0m\033[35;1m$1 \033[0m"
}

# 自启
fun_nat_start(){
    if [ "${cloudflared_enable}"x = "1"x ] ;then
	    [ ! -L "/jffs/softcenter/init.d/S89cloudflared.sh" ] && ln -sf /jffs/softcenter/scripts/cloudflared_config.sh /jffs/softcenter/init.d/S89cloudflared.sh
    fi
}
# 定时任务
fun_crontab(){
    if [ "${cfd_enable}" != "1" ] || [ "${cfd_cron_time}"x = "0"x ];then
        [ -n "$(cru l | grep cloudflared_monitor)" ] && cru d cloudflared_monitor
    fi
     if [ "${cfd_cron_hour_min}" == "min" ] && [ "${cfd_cron_time}"x != "0"x ] ; then
        if [ "${cfd_cron_type}" == "watch" ]; then
        	cru a cloudflared_monitor "*/"${cfd_cron_time}" * * * * /bin/sh /jffs/softcenter/scripts/cloudflared_config.sh watch"
        elif [ "${cfd_cron_type}" == "start" ]; then
            cru a cloudflared_monitor "*/"${cfd_cron_time}" * * * * /bin/sh /jffs/softcenter/scripts/cloudflared_config.sh restart"
    	fi
    elif [ "${cfd_cron_hour_min}" == "hour" ] && [ "${cfd_cron_time}"x != "0"x ] ; then
        if [ "${cfd_cron_type}" == "watch" ]; then
            cru a cloudflared_monitor "0 */"${cfd_cron_time}" * * * /bin/sh /jffs/softcenter/scripts/cloudflared_config.sh watch"
        elif [ "${cfd_cron_type}" == "start" ]; then
            cru a cloudflared_monitor "0 */"${cfd_cron_time}" * * * /bin/sh /jffs/softcenter/scripts/cloudflared_config.sh restart"
        fi
    fi
}

# 关闭进程（先用默认信号，再使用9）
onkillcfd(){
    PID=$(pidof cloudflared)
    [ -n "$(cru l | grep cloudflared_monitor)" ] && cru d cloudflared_monitor
    if [ -n "${PID}" ];then
		start-stop-daemon -K -p /var/run/cloudflared.pid >/dev/null 2>&1
		kill -9 "${PID}" >/dev/null 2>&1
    fi
    rm -f /var/run/cloudflared.pid
}

# 停止并清理
onstop(){
	onkillcfd
	logger "【软件中心】：关闭 cloudflared..."
        [ -z "$(pidof cloudflared)" ] && logg "cloudflared已停止运行"
}    

fun_update(){
tag=""
curltest=`which curl`
if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
   tag="$( wget -T 5 -t 3 --user-agent "$user_agent" --max-redirect=0 --output-document=-  https://api.github.com/repos/cloudflare/cloudflared/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
   [ -z "$tag" ] && tag="$( wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=-  https://api.github.com/repos/cloudflare/cloudflared/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
   [ -z "$tag" ] && tag="$( wget -T 5 -t 3 --output-document=-  https://api.github.com/repos/cloudflare/cloudflared/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
else
    tag="$( curl --connect-timeout 3 --user-agent "$user_agent"  https://api.github.com/repos/cloudflare/cloudflared/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
    [ -z "$tag" ] && tag="$( curl -L --connect-timeout 3 --user-agent "$user_agent" -s  https://api.github.com/repos/cloudflare/cloudflared/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
    [ -z "$tag" ] && tag="$( curl -k -L --connect-timeout 20 -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep 'tag_name' | cut -d\" -f4 )"
fi
[ -z "$tag" ] && tag="$( curl -k -L --connect-timeout 20 --silent https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep 'tag_name' | cut -d\" -f4 )"
[ -z "$tag" ] && tag="$(curl -k --silent "https://api.github.com/repos/cloudflare/cloudflared/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"
logg "开始下载更新版本.."
cfd_bin=`dbus get cloudflared_path`
[ -z "$cfd_bin" ] && cfd_bin=/tmp/cloudflared && dbus set cloudflared_path=$cfd_bin
[ -x "${cfd_bin}" ] || chmod 755 ${cfd_bin}
cloudflared_ver="$(${cfd_bin} -v | awk {'print $3'})"
if [ ! -z "$cloudflared_ver" ] && [ ! -z "$tag" ] || [ ! -f "$cfd_bin" ] ; then
 if [ "$cloudflared_ver"x != "$tag"x ] ; then
   logg "发现新版本 cloudflared_${tag} 开始下载..."
   case "${cpucore}" in 
    "arm")  
      curl -L -k -o /tmp/cloudflared --connect-timeout 10 --retry 3 "${proxy_url}https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-linux-arm" || curl -L -k -o tmp/cloudflared --connect-timeout 10 --retry 3 "${proxy_url2}https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-linux-arm"
    ;;
   "aarch64")  
     curl -L -k -o /tmp/cloudflared --connect-timeout 10 --retry 3 "${proxy_url}https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-linux-arm64" || curl -L -k -o tmp/cloudflared --connect-timeout 10 --retry 3 "${proxy_url2}https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-linux-arm64" 
   ;;
   *)
     logg "未知cpu架构，无法下载..."
   ;;
   esac
    chmod 755  /tmp/cloudflared
   if [ $(($(/tmp/cloudflared -h | wc -l))) -lt 3 ] ; then
     logg "下载失败，无法更新..."
   else
     cloudflared_ver="$(/tmp/cloudflared -v | awk {'print $3'})"
     if [ ! -z "$cloudflared_ver" ] ; then
     cp -rf /tmp/cloudflared ${cfd_bin}
     dbus set cloudflared_version=$cloudflared_ver
     logg "已成功更新至${cloudflared_ver}"
     fi
fi
else
  logg "当前版本${cloudflared_ver} 最新版本${tag} 相同，无需更新 ..."
fi
else
  logg "获取当前版本${cloudflared_ver} 最新版本${tag} 失败，无法更新 ..."
fi
}

fun_start_stop(){

 if [ "${cloudflared_enable}" != "1" ] ; then
   onstop
   return 1
 fi
  cfd_mode=`dbus get cloudflared_mode`
  cfd_token=`dbus get cloudflared_token`
  user_cmd=`dbus get cloudflared_cmd`
  cfd_log=`dbus get cloudflared_log_level`
  cfd_bin=`dbus get cloudflared_path`
  [ -z "$cfd_bin" ] && cfd_bin=/tmp/cloudflared && dbus set cloudflared_path=$cfd_bin
  [ -z "$cfd_log" ] && cfd_log=info && dbus set cloudflared_log_level=info
  [ "$cfd_mode" = "token" ] && [ -z "$cfd_token" ] && logg "未获取到隧道token，无法启动，请检查隧道token值是否填写，程序退出" && return 1
  [ "$cfd_mode" = "user_cmd" ] && [ -z "$user_cmd" ] && logg "未获取到自定义启动参数，无法启动，请检查自定义启动参数是否填写，程序退出" && return 1
  chmod +x ${cfd_bin}
  [ $(($($cfd_bin -h | wc -l))) -lt 3 ] && rm -rf ${cfd_bin} && fun_update
  chmod +x ${cfd_bin}
  cloudflared_ver="$($cfd_bin -v | awk {'print $3'})"
  dbus set cloudflared_version=$cloudflared_ver
  if [ "$cfd_mode" = "token" ] && [ ! -z "$cfd_token" ] ; then
     cfd_cmd="tunnel --no-autoupdate --logfile ${cfd_logs} --loglevel ${cfd_log} run --token ${cfd_token}"
  fi
  if [ "$cfd_mode" = "user_cmd" ] && [ ! -z "$user_cmd" ] ; then
     cfd_cmd="${user_cmd}"
  fi
  logg "当前cloudflared启动参数 ${cfd_bin} ${cfd_cmd} "
  killall cloudflared 2>/dev/null
    rm -rf /var/run/cloudflared.pid
    start-stop-daemon --start --quiet --make-pidfile --pidfile /var/run/cloudflared.pid --background --startas /bin/sh -- -c  "${cfd_bin} ${cfd_cmd} >>${cfd_logs} 2>&1 &"
   sleep 5
   [ ! -z "$(pidof cloudflared)" ] && logg "cloudflared启动成功！"
   echo `date +%s` > /tmp/cloudflared_time
}


case $ACTION in
start)

    logger "【软件中心】：启动 cloudflared..."
	fun_start_stop
	fun_nat_start
	fun_crontab
	;;
stop)
	onstop
	;;
restart)
        onstop
        fun_start_stop
	fun_nat_start
	fun_crontab
	;;
watch)
    [ -n "$(pidof cloudflared)" ] && exit
    logger "【软件中心】定时任务：进程掉线，重新启动 cloudflared..."
         onstop
        fun_start_stop
	;;
clearlog)
        true >${cfd_logs}
	http_response "$1"
    ;;
update)
        fun_update
	http_response "$1"
    ;;
*)
 if [ "${cloudflared_enable}" != "1" ] ; then
   logger "【软件中心】：未开启 cloudflared ，无需启动..."
   exit
 fi
    logger "【软件中心】：启动 cloudflared..."
	fun_start_stop
	fun_nat_start
	fun_crontab
	;;
esac
# 界面提交的参数
case $2 in
1)
        logger "【软件中心】：启动 cloudflared..."
	fun_start_stop 
	fun_nat_start
	fun_crontab
	http_response "$1"
	;;
clearlog)
        true >${cfd_logs}
	http_response "$1"
    ;;
update)
        fun_update 
	http_response "$1"
    ;;
restart)
        onstop
        fun_start_stop 
	fun_nat_start
	fun_crontab
	http_response "$1"
	;;
esac
