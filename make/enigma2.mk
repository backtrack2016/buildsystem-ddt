#
# enigma2
#
ENIGMA2_DEPS  = $(D)/bootstrap $(D)/opkg $(D)/ncurses $(LIRC) $(D)/libcurl $(D)/libid3tag $(D)/libmad
ENIGMA2_DEPS += $(D)/libpng $(D)/libjpeg $(D)/giflib $(D)/freetype
ENIGMA2_DEPS += $(D)/alsa_utils $(D)/ffmpeg
ENIGMA2_DEPS += $(D)/libfribidi $(D)/libsigc_e2 $(D)/expat $(D)/libdvbsi $(D)/libusb
ENIGMA2_DEPS += $(D)/sdparm $(D)/minidlna $(D)/ethtool
ENIGMA2_DEPS += $(D)/avahi
ENIGMA2_DEPS += python-all
ENIGMA2_DEPS += $(D)/libdreamdvd $(D)/enigma2_tuxtxt32bpp $(D)/enigma2_hotplug_e2_helper
ENIGMA2_DEPS += $(LOCAL_ENIGMA2_DEPS)

ifeq ($(IMAGE), enigma2-wlandriver)
ENIGMA2_DEPS += $(D)/wpa_supplicant $(D)/wireless_tools
endif

ifeq ($(EXTERNAL_LCD), externallcd)
ENIGMA2_DEPS  += $(D)/graphlcd
E_CONFIG_OPTS += --with-graphlcd
endif

ifeq ($(EXTERNAL_LCD), lcd4linux)
ENIGMA2_DEPS += $(D)/lcd4linux
endif

ifeq ($(MEDIAFW), eplayer3)
ENIGMA2_DEPS  += $(D)/tools-libeplayer3
E_CONFIG_OPTS += --enable-libeplayer3
endif

ifeq ($(MEDIAFW), gstreamer)
ENIGMA2_DEPS  += $(D)/gst_plugins_dvbmediasink
E_CONFIG_OPTS += --with-gstversion=1.0 --enable-mediafwgstreamer
endif

ifeq ($(MEDIAFW), gst-eplayer3)
ENIGMA2_DEPS  += $(D)/tools-libeplayer3
ENIGMA2_DEPS  += $(D)/gst_plugins_dvbmediasink
E_CONFIG_OPTS += --with-gstversion=1.0 --enable-libeplayer3 --enable-mediafwgstreamer
endif

E_CONFIG_OPTS +=$(LOCAL_ENIGMA2_BUILD_OPTIONS)

E_CPPFLAGS    = -I$(DRIVER_DIR)/include
E_CPPFLAGS   += -I$(TARGET_DIR)/usr/include
E_CPPFLAGS   += -I$(KERNEL_DIR)/include
E_CPPFLAGS   += -I$(APPS_DIR)/tools/libeplayer3/include
E_CPPFLAGS   += -I$(APPS_DIR)/tools
E_CPPFLAGS   += $(LOCAL_ENIGMA2_CPPFLAGS)
E_CPPFLAGS   += $(PLATFORM_CPPFLAGS)

#
# yaud-enigma2
#
yaud-enigma2: yaud-none $(D)/enigma2 $(D)/enigma2-plugins $(D)/enigma2_release
	$(TUXBOX_YAUD_CUSTOMIZE)

#
# enigma2
#
ENIGMA2_PATCH  = enigma2-pli-nightly.$$DIFF.diff

REPO_REPLY_1=$(E2_GIT_REPO)

$(D)/enigma2.do_prepare: | $(ENIGMA2_DEPS)
	rm -rf $(SOURCE_DIR)/enigma2; \
	rm -rf $(SOURCE_DIR)/enigma2.org; \
	REVISION=""; \
	HEAD="master"; \
	DIFF="0"; \
	clear; \
	echo ""; \
	echo "Choose between the following revisions:"; \
	echo "========================================================================================================"; \
	echo " 0) Newest                 - E2 OpenPli gstreamer / libplayer3    (Can fail due to outdated patch)     "; \
	echo "========================================================================================================"; \
	echo " 1) Use your own e2 git dir without patchfile"; \
	echo "========================================================================================================"; \
	echo " 2) Mon, 17 Aug 2015 07:08 - E2 OpenPli gstreamer / libplayer3 cd5505a4b8aba823334032bb6fd7901557575455"; \
	echo "========================================================================================================"; \
	echo "Media Framework : $(MEDIAFW)"; \
	echo "External LCD    : $(EXTERNALLCD)"; \
	read -p "Select          : "; \
	[ "$$REPLY" == "0" ] && DIFF="0" && REVISION="" && REPO="https://github.com/OpenPLi/enigma2.git"; \
	[ "$$REPLY" == "1" ] && DIFF="1" && REVISION="" && REPO=$(REPO_REPLY_1); \
	[ "$$REPLY" == "2" ] && DIFF="2" && REVISION="cd5505a4b8aba823334032bb6fd7901557575455" && REPO="https://github.com/OpenPLi/enigma2.git"; \
	echo "Revision        : "$$REVISION; \
	echo "Selection       : "$$REPLY; \
	echo ""; \
	if [ "$$REPLY" != "1" ]; then \
		[ -d "$(ARCHIVE)/enigma2-pli-nightly.git" ] && \
		(cd $(ARCHIVE)/enigma2-pli-nightly.git; git pull; git checkout HEAD; cd "$(BUILD_TMP)";); \
		[ -d "$(ARCHIVE)/enigma2-pli-nightly.git" ] || \
		git clone -b $$HEAD $$REPO $(ARCHIVE)/enigma2-pli-nightly.git; \
		cp -ra $(ARCHIVE)/enigma2-pli-nightly.git $(SOURCE_DIR)/enigma2; \
		[ "$$REVISION" == "" ] || (cd $(SOURCE_DIR)/enigma2; git checkout "$$REVISION"; cd "$(BUILD_TMP)";); \
		cp -ra $(SOURCE_DIR)/enigma2 $(SOURCE_DIR)/enigma2.org; \
		set -e; cd $(SOURCE_DIR)/enigma2; \
			$(call post_patch,$(ENIGMA2_PATCH)); \
	else \
		[ -d "$(SOURCE_DIR)/enigma2" ] ; \
		git clone -b $$HEAD $$REPO $(SOURCE_DIR)/enigma2; \
	fi
	$(START_BUILD)
	@touch $@

$(SOURCE_DIR)/enigma2/config.status:
	cd $(SOURCE_DIR)/enigma2; \
		./autogen.sh $(SILENT_OPT); \
		sed -e 's|#!/usr/bin/python|#!$(HOST_DIR)/bin/python|' -i po/xml2po.py; \
		$(BUILDENV) \
		./configure $(SILENT_OPT) \
			--build=$(BUILD) \
			--host=$(TARGET) \
			$(E_CONFIG_OPTS) \
			--with-libsdl=no \
			--datadir=/usr/local/share \
			--libdir=/usr/lib \
			--bindir=/usr/local/bin \
			--prefix=/usr \
			--sysconfdir=/etc \
			--with-boxtype=none \
			PKG_CONFIG=$(PKG_CONFIG) \
			PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) \
			PY_PATH=$(TARGET_DIR)/usr \
			CPPFLAGS="$(E_CPPFLAGS)"

$(D)/enigma2.do_compile: $(SOURCE_DIR)/enigma2/config.status
	cd $(SOURCE_DIR)/enigma2; \
		$(MAKE) all
	@touch $@

$(D)/enigma2: $(D)/enigma2.do_prepare $(D)/enigma2.do_compile
	$(MAKE) -C $(SOURCE_DIR)/enigma2 install DESTDIR=$(TARGET_DIR)
	if [ -e $(TARGET_DIR)/usr/bin/enigma2 ]; then \
		$(TARGET)-strip $(TARGET_DIR)/usr/bin/enigma2; \
	fi
	if [ -e $(TARGET_DIR)/usr/local/bin/enigma2 ]; then \
		$(TARGET)-strip $(TARGET_DIR)/usr/local/bin/enigma2; \
	fi
	$(TOUCH)

enigma2-clean:
	rm -f $(D)/enigma2
	rm -f $(D)/enigma2.do_compile
	cd $(SOURCE_DIR)/enigma2; \
		$(MAKE) distclean

enigma2-distclean:
	rm -f $(D)/enigma2
	rm -f $(D)/enigma2.do_compile
	rm -f $(D)/enigma2.do_prepare
	rm -rf $(SOURCE_DIR)/enigma2
	rm -rf $(SOURCE_DIR)/enigma2.org
