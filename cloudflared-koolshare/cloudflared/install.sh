#! /bin/sh

source /koolshare/scripts/base.sh
eval `dbus export cloudflared_`
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
MODEL=$(nvram get productid)
DIR=$(cd $(dirname $0); pwd)

en=`dbus get cloudflared_enable`
if [ ! -d "/koolshare" ] ; then
  echo_date "你的固件不适配，无法安装此插件包，请正确选择插件包！"
  rm -rf /tmp/cloudflared* >/dev/null 2>&1
  exit 1
fi
if [ "${en}"x = "1"x ] ; then
    sh /koolshare/scripts/cloudflared_config.sh stop
fi
find /koolshare/init.d/ -name "*cloudflared.sh*"|xargs rm -rf
cd /tmp

cp -rf /tmp/cloudflared/scripts/* /koolshare/scripts/
cp -rf /tmp/cloudflared/webs/* /koolshare/webs/
cp -rf /tmp/cloudflared/res/* /koolshare/res/
cp /tmp/cloudflared/uninstall.sh /koolshare/scripts/uninstall_cloudflared.sh
ln -sf /koolshare/scripts/cloudflared_config.sh /koolshare/init.d/N99cloudflared.sh



chmod +x /koolshare/scripts/cloudflared_*
chmod +x /koolshare/init.d/N99cloudflared.sh
chmod +x /koolshare/scripts/uninstall_cloudflared.sh
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
    sh /koolshare/scripts/cloudflared_config.sh restart
fi
exit 0
