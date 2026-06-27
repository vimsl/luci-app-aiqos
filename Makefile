include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-aiqos
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=vimsl
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-aiqos
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=AIQoS - Intelligent QoS for 5G CPE
  DEPENDS:=+luci-base +kmod-sched-cake +cake-autorate +uqmi
  PKGARCH:=all
endef

define Package/luci-app-aiqos/description
  AIQoS (AI-powered QoS) is an intelligent Quality of Service
  management system designed for 5G CPE routers.
  
  Features:
  - SINR-aware bandwidth adjustment
  - Night-time cell locking for optimal signal
  - Auto-detection of WiFi, eBPF, eqos-mtk capabilities
  - 7-toggle SimpleForm LuCI interface with preset scenarios
  - Hardware acceleration (HNAT) compatible
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-aiqos/conffiles
/etc/config/aiqos
endef

define Package/luci-app-aiqos/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./root/usr/bin/sinr_injector.sh $(1)/usr/bin/sinr_injector.sh
	$(INSTALL_BIN) ./root/usr/bin/night_lock.sh $(1)/usr/bin/night_lock.sh
	$(INSTALL_BIN) ./root/usr/bin/condition_detect.sh $(1)/usr/bin/condition_detect.sh
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/aiqosd $(1)/etc/init.d/aiqosd
	
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./root/etc/config/aiqos $(1)/etc/config/aiqos
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/aiqos.lua $(1)/usr/lib/lua/luci/controller/aiqos.lua
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/aiqos.lua $(1)/usr/lib/lua/luci/model/cbi/aiqos.lua
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/aiqos
	$(INSTALL_DATA) ./luasrc/view/aiqos/status.htm $(1)/usr/lib/lua/luci/view/aiqos/status.htm
endef

define Package/luci-app-aiqos/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/aiqosd enable
	/etc/init.d/aiqosd start
}
exit 0
endef

define Package/luci-app-aiqos/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/aiqosd stop
	/etc/init.d/aiqosd disable
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-aiqos))
