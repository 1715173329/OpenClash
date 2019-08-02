<h1 align="center">
  <img src="https://github.com/Dreamacro/clash/raw/master/docs/logo.png" alt="Clash" width="200">
  <br>OpenClash<br>

</h1>

  <p align="center">
	<a target="_blank" href="https://github.com/Dreamacro/clash/releases/tag/v0.15.0">
    <img src="https://img.shields.io/badge/Clash-v0.15.0-blue.svg">
  </a>
  <a target="_blank" href="https://github.com/vernesong/OpenClash/tree/v0.33.3-beta">
    <img src="https://img.shields.io/badge/source code-v0.33.3--beta-green.svg">
  </a>
  <a target="_blank" href="https://github.com/vernesong/OpenClash/releases/tag/v0.33.3-beta">
    <img src="https://img.shields.io/badge/NewRelease-v0.33.3--beta-orange.svg">
  </a>
  </p>
  

<p align="center">
本软件包是一个可运行在 OpenWrt 上的<a href="https://github.com/Dreamacro/clash" target="_blank"> Clash </a>客户端
</p>
<p align="center">
兼容 Shadowsocks、Vmess 等协议，根据灵活的规则配置实现策略代理
</p>


下载地址
---


* IPK [前往下载](https://github.com/vernesong/OpenClash/releases)


依赖
---

* luci
* luci-base
* iptables
* coreutils
* coreutils-nohup
* bash
* wget


配置
---


* 安装后先在设置页面选择`内核编译版本`
* 上传或订阅配置文件
* 启动客户端


编译
---


从 OpenWrt 的 [SDK](http://wiki.openwrt.org/doc/howto/obtain.firmware.sdk) 编译
```bash
# 解压下载好的 SDK
tar xjf OpenWrt-SDK-ar71xx-for-linux-x86_64-gcc-4.8-linaro_uClibc-0.9.33.2.tar.bz2
cd OpenWrt-SDK-ar71xx-*

# Clone 项目
mkdir package/luci-app-openclash
cd package/luci-app-openclash
git init
git remote add -f origin https://github.com/vernesong/OpenClash.git
git config core.sparsecheckout true
echo "luci-app-openclash" >> .git/info/sparse-checkout
git pull origin master
git branch --set-upstream-to=origin/master master

# 编译 po2lmo (如果有po2lmo可跳过)
pushd package/luci-app-openclash/luci-app-openclash/tools/po2lmo
make && sudo make install
popd

# 您也可以直接拷贝 `luci-app-openclash` 文件夹至 `OpenWrt` 项目的 `Package` 目录下

# 选择要编译的包 LuCI -> Applications -> luci-app-openclash
make menuconfig

# 开始编译
make package/luci-app-openclash/luci-app-openclash/compile V=99
```


许可
---


* [MIT License](https://github.com/vernesong/OpenClash/blob/master/LICENSE)
* [clash](https://github.com/Dreamacro/clash) by [Dreamacro](https://github.com/Dreamacro)
* Codes Based on [Luci For Clash](https://github.com/frainzy1477/luci-app-clash) by [frainzy1477](https://github.com/frainzy1477)
* [GeoLite2](https://dev.maxmind.com/geoip/geoip2/geolite2/) by [MaxMind](https://www.maxmind.com)
* [MyIP](https://github.com/SukkaW/MyIP) by [SukkaW](https://github.com/SukkaW)
* [clash-dashboard](https://github.com/Dreamacro/clash-dashboard) by [Dreamacro](https://github.com/Dreamacro)
* [yacd](https://github.com/haishanh/yacd) by [haishanh](https://github.com/haishanh)


预览
---


* 运行状态
<p align="center">
    <img src="https://github.com/vernesong/OpenClash/raw/master/img/state.png">
</p>

* 接管设置
<p align="center">
    <img src="https://github.com/vernesong/OpenClash/raw/master/img/settings.png">
</p>

* 配置文件
<p align="center">
    <img src="https://github.com/vernesong/OpenClash/raw/master/img/config.png">
</p>

* 运行日志
<p align="center">
    <img src="https://github.com/vernesong/OpenClash/raw/master/img/log.png">
</p>

