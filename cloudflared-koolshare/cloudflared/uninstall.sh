#! /bin/sh

export KSROOT=/koolshare
source $KSROOT/scripts/base.sh
eval `dbus export cloudflared`

en=`dbus get cloudflared_enable`
bin=`dbus get cloudflared_path`
if [ "${en}"x = "1"x ] ; then
    sh /koolshare/scripts/cloudflared_config.sh stop
fi
rm -rf $bin
confs=`dbus list cloudflared|cut -d "=" -f1`

for conf in $confs
do
	dbus remove $conf
done

sleep 1
rm -rf /koolshare/scripts/cloudflared*
rm -rf /koolshare/bin/cloudflared*
rm -rf /koolshare/init.d/?99cloudflared.sh
rm -rf /koolshare/webs/Module_cloudflared.asp
rm -rf /koolshare/res/icon-cloudflared.png

echo "【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】: 卸载完成，江湖有缘再见~"
rm -rf /koolshare/scripts/uninstall_cloudflared.sh
