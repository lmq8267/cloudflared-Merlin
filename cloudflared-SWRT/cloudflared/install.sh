#! /bin/sh

source /jffs/softcenter/scripts/base.sh
eval `dbus export cloudflared_`
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
MODEL=$(nvram get productid)
DIR=$(cd $(dirname $0); pwd)

en=`dbus get cloudflared_enable`
if [ ! -d "/jffs/softcenter" ] ; then
  echo_date "你的固件不适配，无法安装此插件包，请正确选择插件包！"
  rm -rf /tmp/cloudflared* >/dev/null 2>&1
  exit 1
fi
if [ "${en}"x = "1"x ] ; then
    sh /jffs/softcenter/scripts/cloudflared_config.sh stop
fi
find /jffs/softcenter/init.d/ -name "*cloudflared.sh*"|xargs rm -rf
cd /tmp

cp -rf /tmp/cloudflared/scripts/* /jffs/softcenter/scripts/
cp -rf /tmp/cloudflared/webs/* /jffs/softcenter/webs/
cp -rf /tmp/cloudflared/res/* /jffs/softcenter/res/
cp /tmp/cloudflared/uninstall.sh /jffs/softcenter/scripts/uninstall_cloudflared.sh
ln -sf /jffs/softcenter/scripts/cloudflared_config.sh /jffs/softcenter/init.d/S99cloudflared.sh



chmod +x /jffs/softcenter/scripts/cloudflared_*
chmod +x /jffs/softcenter/init.d/S99cloudflared.sh
chmod +x /jffs/softcenter/scripts/uninstall_cloudflared.sh
dbus set softcenter_module_cloudflared_description="Cloudflare Tunnel 客户端(以前称为 Argo Tunnel)"
dbus set softcenter_module_cloudflared_install=1
dbus set softcenter_module_cloudflared_name=cloudflared
dbus set softcenter_module_cloudflared_title=cloudflared
dbus set softcenter_module_cloudflared_version="$(cat $DIR/version)"

sleep 1
echo_date "cloudflared 插件安装完毕！"
rm -rf /tmp/cloudflared* >/dev/null 2>&1
en=`dbus get cloudflared_enable`
if [ "${en}"x = "1"x ] ; then
    sh /jffs/softcenter/scripts/cloudflared_config.sh restart
fi
exit 0
