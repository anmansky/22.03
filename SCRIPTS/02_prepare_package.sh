#!/bin/bash
clear

### 基础部分 ###
# 使用 O3 级别的优化
sed -i 's/Os/O3 -funsafe-math-optimizations -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections/g' include/target.mk
# 更新 Feeds
./scripts/feeds update -a
./scripts/feeds install -a
# 默认开启 Irqbalance
sed -i "s/enabled '0'/enabled '1'/g" feeds/packages/utils/irqbalance/files/irqbalance.config
# Modify default IP
sed -i 's/192.168.1.1/10.0.10.100/g' package/base-files/files/bin/config_generate
# 移除 SNAPSHOT 标签
sed -i 's,-SNAPSHOT,,g' include/version.mk
sed -i 's,-SNAPSHOT,,g' package/base-files/image-config.in
# 维多利亚的秘密
rm -rf ./scripts/download.pl
rm -rf ./include/download.mk
wget -P scripts/ https://github.com/immortalwrt/immortalwrt/raw/master/scripts/download.pl
wget -P include/ https://github.com/immortalwrt/immortalwrt/raw/master/include/download.mk
sed -i '/unshift/d' scripts/download.pl
sed -i '/mirror02/d' scripts/download.pl
echo "net.netfilter.nf_conntrack_helper = 1" >>./package/kernel/linux/files/sysctl-nf-conntrack.conf

### 必要的 Patches ###
# offload bug fix
wget -qO - https://github.com/openwrt/openwrt/pull/4849.patch | patch -p1
# TCP performance optimizations backport from linux/net-next
#cp -rf ../PATCH/backport/TCP/* ./target/linux/generic/backport-5.10/
# UDP performance optimizations backport from linux/net-next
#cp -rf ../PATCH/backport/UDP/* ./target/linux/generic/backport-5.10/
# introduce "le9" Linux kernel patches
cp -f ../PATCH/backport/995-le9i.patch ./target/linux/generic/hack-5.10/995-le9i.patch
cp -f ../PATCH/backport/290-remove-kconfig-CONFIG_I8K.patch ./target/linux/generic/hack-5.10/290-remove-kconfig-CONFIG_I8K.patch
# ZSTD
cp -rf ../PATCH/backport/ZSTD/* ./target/linux/generic/hack-5.10/
# Patch arm64 型号名称
wget -P target/linux/generic/hack-5.10/ https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/generic/hack-5.10/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch
#FW4
#rm -rf ./package/network/config/firewall4
#svn export https://github.com/openwrt/openwrt/trunk/package/network/config/firewall4 package/network/config/firewall4
#rm -rf ./package/utils/ucode
#svn export https://github.com/openwrt/openwrt/trunk/package/utils/ucode package/utils/ucode
# Patch dnsmasq
#rm -rf ./package/network/services/dnsmasq
#svn export https://github.com/aparcar/openwrt/branches/dnsmasq-2.87test5/package/network/services/dnsmasq package/network/services/dnsmasq
#patch -p1 <../PATCH/dnsmasq/dnsmasq-add-filter-aaaa-option.patch
#patch -p1 <../PATCH/dnsmasq/luci-add-filter-aaaa-option.patch
#cp -f ../PATCH/dnsmasq/900-add-filter-aaaa-option.patch ./package/network/services/dnsmasq/patches/900-add-filter-aaaa-option.patch
# BBRv2
cp -rf ../PATCH/BBRv2/kernel/* ./target/linux/generic/hack-5.10/
cp -rf ../PATCH/BBRv2/openwrt/package ./
wget -qO - https://github.com/openwrt/openwrt/commit/7db9763.patch | patch -p1

# PRJC
#cp -f ../PATCH/PRJC/960-prjc_v5.10-lts-r3.patch ./target/linux/generic/hack-5.10/960-prjc_v5.10-lts-r3.patch
#echo '
#CONFIG_SCHED_ALT=y
#CONFIG_SCHED_BMQ=y
#' >>./target/linux/generic/config-5.10
# LRNG
cp -rf ../PATCH/LRNG/* ./target/linux/generic/hack-5.10/
echo '
CONFIG_LRNG=y
CONFIG_LRNG_JENT=y
' >>./target/linux/generic/config-5.10
# Grub 2
wget -qO - https://github.com/openwrt/openwrt/commit/31f1033.patch | patch -p1
# Haproxy
rm -rf ./feeds/packages/net/haproxy
svn export https://github.com/openwrt/packages/trunk/net/haproxy feeds/packages/net/haproxy
pushd feeds/packages
wget -qO - https://github.com/QiuSimons/packages/commit/7ffbfbe.patch | patch -p1
popd
# OPENSSL
wget -P package/libs/openssl/patches/ https://github.com/openssl/openssl/pull/11895.patch
wget -P package/libs/openssl/patches/ https://github.com/openssl/openssl/pull/14578.patch
wget -P package/libs/openssl/patches/ https://github.com/openssl/openssl/pull/16575.patch

### Fullcone-NAT 部分 ###
# Patch Kernel 以解决 FullCone 冲突
pushd target/linux/generic/hack-5.10
wget https://github.com/coolsnowwolf/lede/raw/master/target/linux/generic/hack-5.10/952-net-conntrack-events-support-multiple-registrant.patch
popd
# Patch FireWall 以增添 FullCone 功能
# FW4
mkdir package/network/config/firewall4/patches
wget -P package/network/config/firewall4/patches/ https://github.com/wongsyrone/lede-1/raw/master/package/network/config/firewall4/patches/999-01-firewall4-add-fullcone-support.patch
sed -i 's/-1,3 +1,5/-2,3 +2,5/g' package/network/config/firewall4/patches/999-01-firewall4-add-fullcone-support.patch
wget 'https://git.openwrt.org/?p=project/firewall4.git;a=patch;h=38423fae' -O package/network/config/firewall4/patches/990-unconditionally-allow-ct-status-dnat.patch
mkdir package/libs/libnftnl/patches
wget -P package/libs/libnftnl/patches/ https://github.com/wongsyrone/lede-1/raw/master/package/libs/libnftnl/patches/999-01-libnftnl-add-fullcone-expression-support.patch
sed -i '/PKG_LICENSE_FILES/a PKG_FIXUP:=autoreconf' package/libs/libnftnl/Makefile
mkdir package/network/utils/nftables/patches
wget -P package/network/utils/nftables/patches/ https://github.com/wongsyrone/lede-1/raw/master/package/network/utils/nftables/patches/999-01-nftables-add-fullcone-expression-support.patch
# FW3
mkdir package/network/config/firewall/patches
wget -P package/network/config/firewall/patches/ https://github.com/immortalwrt/immortalwrt/raw/master/package/network/config/firewall/patches/fullconenat.patch
wget -qO- https://github.com/msylgj/R2S-R4S-OpenWrt/raw/master/PATCHES/001-fix-firewall-flock.patch | patch -p1
# Patch LuCI 以增添 FullCone 开关
patch -p1 <../PATCH/firewall/luci-app-firewall_add_fullcone.patch
# FullCone PKG
git clone --depth 1 https://github.com/fullcone-nat-nftables/nft-fullcone package/new/nft-fullcone
svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/openwrt-fullconenat package/lean/openwrt-fullconenat
pushd package/lean/openwrt-fullconenat
patch -p2 <../../../../PATCH/firewall/fullcone6.patch
popd

### 获取额外的基础软件包 ###
# 更换为 ImmortalWrt Uboot 以及 Target
rm -rf ./target/linux/rockchip
svn export https://github.com/immortalwrt/immortalwrt/branches/master/target/linux/rockchip target/linux/rockchip
rm -rf ./package/boot/uboot-rockchip
svn export https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/uboot-rockchip package/boot/uboot-rockchip
svn export https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/arm-trusted-firmware-rockchip-vendor package/boot/arm-trusted-firmware-rockchip-vendor
rm -rf ./package/kernel/linux/modules/video.mk
wget -P package/kernel/linux/modules/ https://github.com/immortalwrt/immortalwrt/raw/master/package/kernel/linux/modules/video.mk
rm -rf ./target/linux/generic/config-5.10
wget -P target/linux/generic/ https://github.com/immortalwrt/immortalwrt/raw/master/target/linux/generic/config-5.10
# ImmortalWrt Uboot TMP Fix
wget -qO- https://github.com/immortalwrt/immortalwrt/commit/433c93e.patch | patch -REp1
# R4S超频到 2.2/1.8 GHz
#rm -rf ./target/linux/rockchip/patches-5.4/992-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch
#cp -f ../PATCH/target_r4s/991-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch ./target/linux/rockchip/patches-5.4/991-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch
#cp -f ../PATCH/target_r4s/213-RK3399-set-critical-CPU-temperature-for-thermal-throttling.patch ./target/linux/rockchip/patches-5.4/213-RK3399-set-critical-CPU-temperature-for-thermal-throttling.patch
# Disable Mitigations
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/mmc.bootscript
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/nanopi-r2s.bootscript
sed -i 's,rootwait,rootwait mitigations=off,g' target/linux/rockchip/image/nanopi-r4s.bootscript
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-efi.cfg
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-iso.cfg
sed -i 's,noinitrd,noinitrd mitigations=off,g' target/linux/x86/image/grub-pc.cfg
# AutoCore
svn export https://github.com/immortalwrt/immortalwrt/branches/master/package/emortal/autocore package/lean/autocore
sed -i 's/"getTempInfo" /"getTempInfo", "getCPUBench", "getCPUUsage" /g' package/lean/autocore/files/generic/luci-mod-status-autocore.json
rm -rf ./feeds/packages/utils/coremark
svn export https://github.com/immortalwrt/packages/trunk/utils/coremark feeds/packages/utils/coremark
##rtl8812au-ac
#wget  https://github.com/immortalwrt/immortalwrt/tree/master/package/kernel/rtl8812au-ac  package/kernel/rtl8812au-ac
cp -rf ../PACK/packages/rtl8812au-ac package/kernel/rtl8812au-ac
# 更换 Nodejs 版本
rm -rf ./feeds/packages/lang/node
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node feeds/packages/lang/node
sed -i '\/bin\/node/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $(1)/usr/bin/node' feeds/packages/lang/node/Makefile
rm -rf ./feeds/packages/lang/node-arduino-firmata
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-arduino-firmata feeds/packages/lang/node-arduino-firmata
rm -rf ./feeds/packages/lang/node-cylon
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-cylon feeds/packages/lang/node-cylon
rm -rf ./feeds/packages/lang/node-hid
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-hid feeds/packages/lang/node-hid
rm -rf ./feeds/packages/lang/node-homebridge
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-homebridge feeds/packages/lang/node-homebridge
rm -rf ./feeds/packages/lang/node-serialport
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-serialport feeds/packages/lang/node-serialport
rm -rf ./feeds/packages/lang/node-serialport-bindings
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-serialport-bindings feeds/packages/lang/node-serialport-bindings
rm -rf ./feeds/packages/lang/node-yarn
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-yarn feeds/packages/lang/node-yarn
ln -sf ../../../feeds/packages/lang/node-yarn ./package/feeds/packages/node-yarn
svn export https://github.com/nxhack/openwrt-node-packages/trunk/node-serialport-bindings-cpp feeds/packages/lang/node-serialport-bindings-cpp
ln -sf ../../../feeds/packages/lang/node-serialport-bindings-cpp ./package/feeds/packages/node-serialport-bindings-cpp
# R8168驱动
git clone -b master --depth 1 https://github.com/BROBIRD/openwrt-r8168.git package/new/r8168
patch -p1 <../PATCH/r8168/r8168-fix_LAN_led-for_r4s-from_TL.patch
# R8152驱动
svn export https://github.com/immortalwrt/immortalwrt/branches/master/package/kernel/r8152 package/new/r8152
sed -i 's,kmod-usb-net-rtl8152,kmod-usb-net-rtl8152-vendor,g' target/linux/rockchip/image/armv8.mk
# UPX 可执行软件压缩
sed -i '/patchelf pkgconf/i\tools-y += ucl upx' ./tools/Makefile
sed -i '\/autoconf\/compile :=/i\$(curdir)/upx/compile := $(curdir)/ucl/compile' ./tools/Makefile
svn export https://github.com/coolsnowwolf/lede/trunk/tools/ucl tools/ucl
svn export https://github.com/coolsnowwolf/lede/trunk/tools/upx tools/upx

### 获取额外的 LuCI 应用、主题和依赖 ###
####luci-app-v2ray
cp -rf ../PACK/luci/applications/luci-app-v2ray package/luci-app-v2ray

# 更换 golang 版本
rm -rf ./feeds/packages/lang/golang
svn export https://github.com/openwrt/packages/trunk/lang/golang feeds/packages/lang/golang
# 访问控制
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-accesscontrol package/lean/luci-app-accesscontrol
svn export https://github.com/QiuSimons/OpenWrt-Add/trunk/luci-app-control-weburl package/new/luci-app-control-weburl

# MAC 地址与 IP 绑定
svn export https://github.com/immortalwrt/luci/trunk/applications/luci-app-arpbind feeds/luci/applications/luci-app-arpbind
ln -sf ../../../feeds/luci/applications/luci-app-arpbind ./package/feeds/luci/luci-app-arpbind
# 定时重启
#svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-autoreboot package/lean/luci-app-autoreboot
# Boost 通用即插即用
svn export https://github.com/QiuSimons/slim-wrt/branches/main/slimapps/application/luci-app-boostupnp package/new/luci-app-boostupnp
rm -rf ./feeds/packages/net/miniupnpd
#svn export https://github.com/msylgj/packages/branches/miniupnpd-nftables/net/miniupnpd feeds/packages/net/miniupnpd
svn export https://github.com/coolsnowwolf/packages/trunk/net/miniupnpd feeds/packages/net/miniupnpd
# CPU 控制相关
svn export https://github.com/immortalwrt/luci/trunk/applications/luci-app-cpufreq feeds/luci/applications/luci-app-cpufreq
ln -sf ../../../feeds/luci/applications/luci-app-cpufreq ./package/feeds/luci/luci-app-cpufreq
sed -i 's,1608,1800,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/cpufreq
sed -i 's,2016,2208,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/cpufreq
sed -i 's,1512,1608,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/cpufreq
svn export https://github.com/QiuSimons/OpenWrt-Add/trunk/luci-app-cpulimit package/lean/luci-app-cpulimit
svn export https://github.com/immortalwrt/packages/trunk/utils/cpulimit feeds/packages/utils/cpulimit
ln -sf ../../../feeds/packages/utils/cpulimit ./package/feeds/packages/cpulimit
# 动态DNS
#sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns
#svn export https://github.com/kiddin9/openwrt-packages/trunk/ddns-scripts-aliyun package/lean/ddns-scripts_dnspod
#svn export https://github.com/kiddin9/openwrt-packages/trunk/ddns-scripts-dnspod package/lean/ddns-scripts_aliyun
#svn export https://github.com/QiuSimons/OpenWrt_luci-app/trunk/luci-app-tencentddns package/lean/luci-app-tencentddns
#svn export https://github.com/kenzok8/openwrt-packages/trunk/luci-app-aliddns feeds/luci/applications/luci-app-aliddns
#ln -sf ../../../feeds/luci/applications/luci-app-aliddns ./package/feeds/luci/luci-app-aliddns
# Docker 容器
#rm -rf ./feeds/luci/applications/luci-app-dockerman
#svn export https://github.com/lisaac/luci-app-dockerman/trunk/applications/luci-app-dockerman feeds/luci/applications/luci-app-dockerman
#rm -rf ./feeds/luci/collections/luci-lib-docker
#svn export https://github.com/lisaac/luci-lib-docker/trunk/collections/luci-lib-docker feeds/luci/collections/luci-lib-docker
#sed -i 's/+docker/+docker \\\n\t+dockerd/g' ./feeds/luci/applications/luci-app-dockerman/Makefile
#sed -i '/sysctl.d/d' feeds/packages/utils/dockerd/Makefile
#sed -i 's,# CONFIG_BLK_CGROUP_IOCOST is not set,CONFIG_BLK_CGROUP_IOCOST=y,g' target/linux/generic/config-5.10
# DiskMan
mkdir -p package/new/luci-app-diskman && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile -O package/new/luci-app-diskman/Makefile
mkdir -p package/new/parted && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/Parted.Makefile -O package/new/parted/Makefile
# Dnsfilter
git clone --depth 1 https://github.com/kiddin9/luci-app-dnsfilter.git package/new/luci-app-dnsfilter
# Dnsproxy
svn export https://github.com/immortalwrt/packages/trunk/net/dnsproxy feeds/packages/net/dnsproxy
ln -sf ../../../feeds/packages/net/dnsproxy ./package/feeds/packages/dnsproxy
sed -i '/CURDIR/d' feeds/packages/net/dnsproxy/Makefile
svn export https://github.com/QiuSimons/OpenWrt-Add/trunk/luci-app-dnsproxy package/new/luci-app-dnsproxy
# Edge 主题
git clone -b master --depth 1 https://github.com/kiddin9/luci-theme-edge.git package/new/luci-theme-edge

# IPSec
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-ipsec-server package/lean/luci-app-ipsec-server
# IPv6 兼容助手
svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/ipv6-helper package/lean/ipv6-helper

# Mosdns
#svn export https://github.com/immortalwrt/packages/trunk/net/mosdns feeds/packages/net/mosdns
#ln -sf ../../../feeds/packages/net/mosdns ./package/feeds/packages/mosdns
#sed -i '/config.yaml/d' feeds/packages/net/mosdns/Makefile
#sed -i '/mosdns-init-openwrt/d' feeds/packages/net/mosdns/Makefile
svn export https://github.com/QiuSimons/openwrt-mos/trunk/mosdns package/new/mosdns
svn export https://github.com/QiuSimons/openwrt-mos/trunk/luci-app-mosdns package/new/luci-app-mosdns
svn export https://github.com/QiuSimons/openwrt-mos/trunk/v2ray-geodata package/new/v2ray-geodata
# ServerChan 微信推送
git clone -b master --depth 1 https://github.com/tty228/luci-app-serverchan.git package/new/luci-app-serverchan
# SmartDNS
rm -rf ./feeds/packages/net/smartdns
svn export https://github.com/Lienol/openwrt-packages/trunk/net/smartdns feeds/packages/net/smartdns
rm -rf ./feeds/luci/applications/luci-app-smartdns
svn export https://github.com/immortalwrt/luci/branches/openwrt-18.06/applications/luci-app-smartdns feeds/luci/applications/luci-app-smartdns
# ShadowsocksR Plus+ 依赖
rm -rf ./feeds/packages/net/kcptun
rm -rf ./feeds/packages/net/shadowsocks-libev
rm -rf ./feeds/packages/net/xray-core
svn export https://github.com/coolsnowwolf/packages/trunk/net/shadowsocks-libev package/lean/shadowsocks-libev
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/shadowsocksr-libev package/lean/shadowsocksr-libev
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/pdnsd-alt package/lean/pdnsd
svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/srelay package/lean/srelay
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/microsocks package/lean/microsocks
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/dns2socks package/lean/dns2socks
svn export https://github.com/coolsnowwolf/packages/trunk/net/redsocks2 package/lean/redsocks2
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/ipt2socks package/lean/ipt2socks
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/trojan package/lean/trojan
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/tcping package/lean/tcping
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/trojan-go package/lean/trojan-go
svn export https://github.com/fw876/helloworld/trunk/simple-obfs package/lean/simple-obfs
svn export https://github.com/fw876/helloworld/trunk/naiveproxy package/lean/naiveproxy
svn export https://github.com/fw876/helloworld/trunk/v2ray-core package/lean/v2ray-core
svn export https://github.com/fw876/helloworld/trunk/xray-core package/lean/xray-core
svn export https://github.com/fw876/helloworld/trunk/v2ray-plugin package/lean/v2ray-plugin
svn export https://github.com/fw876/helloworld/trunk/xray-plugin package/lean/xray-plugin
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/shadowsocks-rust feeds/packages/net/shadowsocks-rust
#svn export https://github.com/immortalwrt/packages/trunk/net/shadowsocks-rust feeds/packages/net/shadowsocks-rust
sed -i '/Build\/Compile/a\\t$(STAGING_DIR_HOST)/bin/upx --lzma --best $$(PKG_BUILD_DIR)/$(component)' feeds/packages/net/shadowsocks-rust/Makefile
ln -sf ../../../feeds/packages/net/shadowsocks-rust ./package/feeds/packages/shadowsocks-rust
svn export https://github.com/immortalwrt/packages/trunk/net/kcptun feeds/packages/net/kcptun
ln -sf ../../../feeds/packages/net/kcptun ./package/feeds/packages/kcptun
# ShadowsocksR Plus+
svn export https://github.com/fw876/helloworld/trunk/luci-app-ssr-plus package/lean/luci-app-ssr-plus
rm -rf ./package/lean/luci-app-ssr-plus/po/zh_Hans
pushd package/lean
#wget -qO - https://github.com/fw876/helloworld/pull/656.patch | patch -p1
wget -qO - https://github.com/fw876/helloworld/commit/5bbf6e7.patch | patch -p1
#wget -qO - https://github.com/fw876/helloworld/commit/ea3b4bd.patch | patch -p1
popd
pushd package/lean/luci-app-ssr-plus
sed -i 's,default n,default y,g' Makefile
sed -i '/trojan-go/d' Makefile
sed -i '/v2ray-core/d' Makefile
sed -i '/v2ray-plugin/d' Makefile
sed -i '/xray-plugin/d' Makefile
sed -i '/shadowsocks-libev-ss-redir/d' Makefile
sed -i '/shadowsocks-libev-ss-server/d' Makefile
sed -i '/shadowsocks-libev-ss-local/d' Makefile
sed -i '/result.encrypt_method/a\result.fast_open = "1"' root/usr/share/shadowsocksr/subscribe.lua
sed -i 's,ispip.clang.cn/all_cn,gh.404delivr.workers.dev/https://github.com/QiuSimons/Chnroute/raw/master/dist/chnroute/chnroute,' root/etc/init.d/shadowsocksr
sed -i 's,YW5vbnltb3Vz/domain-list-community/release/gfwlist.txt,Loyalsoldier/v2ray-rules-dat/release/gfw.txt,' root/etc/init.d/shadowsocksr
sed -i '/Clang.CN.CIDR/a\o:value("https://gh.404delivr.workers.dev/https://github.com/QiuSimons/Chnroute/raw/master/dist/chnroute/chnroute.txt", translate("QiuSimons/Chnroute"))' luasrc/model/cbi/shadowsocksr/advanced.lua
popd
# v2raya
git clone --depth 1 https://github.com/zxlhhyccc/luci-app-v2raya.git package/new/luci-app-v2raya
rm -rf ./feeds/packages/net/v2raya
svn export https://github.com/openwrt/packages/trunk/net/v2raya feeds/packages/net/v2raya
ln -sf ../../../feeds/packages/net/v2raya ./package/feeds/packages/v2raya

# KMS 激活助手
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-vlmcsd package/lean/luci-app-vlmcsd
svn export https://github.com/coolsnowwolf/packages/trunk/net/vlmcsd package/lean/vlmcsd
# VSSR
git clone -b master --depth 1 https://github.com/jerrykuku/luci-app-vssr.git package/lean/luci-app-vssr
git clone -b master --depth 1 https://github.com/jerrykuku/lua-maxminddb.git package/lean/lua-maxminddb
pushd package/lean/luci-app-vssr
sed -i 's,default n,default y,g' Makefile
sed -i '/trojan-go/d' Makefile
sed -i '/v2ray-core/d' Makefile
sed -i '/v2ray-plugin/d' Makefile
sed -i '/xray-plugin/d' Makefile
sed -i 's,+shadowsocks-libev-ss-local ,,g' Makefile
popd
sed -i '/result.encrypt_method/a\result.fast_open = "1"' package/lean/luci-app-vssr/root/usr/share/vssr/subscribe.lua
sed -i 's,ispip.clang.cn/all_cn.txt,raw.sevencdn.com/QiuSimons/Chnroute/master/dist/chnroute/chnroute.txt,g' package/lean/luci-app-vssr/luasrc/controller/vssr.lua
sed -i 's,ispip.clang.cn/all_cn.txt,raw.sevencdn.com/QiuSimons/Chnroute/master/dist/chnroute/chnroute.txt,g' package/lean/luci-app-vssr/root/usr/share/vssr/update.lua
#exit 0
