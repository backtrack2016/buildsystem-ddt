# set up environment for other makefiles
# print '+' before each executed command
# SHELL := $(SHELL) -x

CONFIG_SITE =
export CONFIG_SITE

LD_LIBRARY_PATH =
export LD_LIBRARY_PATH

BASE_DIR             := $(shell pwd)

ARCHIVE               = $(HOME)/Archive
APPS_DIR              = $(BASE_DIR)/apps
BUILD_TMP             = $(BASE_DIR)/build_tmp
DRIVER_DIR            = $(BASE_DIR)/driver
FLASH_DIR             = $(BASE_DIR)/flash
SOURCE_DIR            = $(BASE_DIR)/source

-include $(BASE_DIR)/config

# for local extensions
-include $(BASE_DIR)/config.local

# default platform...
ifeq ($(BOXARCH), sh4)
CCACHE_DIR            = $(HOME)/.ccache-bs-sh4
export CCACHE_DIR
TARGET               ?= sh4-linux
BOXARCH              ?= sh4
else
CCACHE_DIR            = $(HOME)/.ccache-bs-arm
export CCACHE_DIR
TARGET               ?= arm-cortex-linux-gnueabihf
BOXARCH              ?= arm
endif

GIT_PROTOCOL         ?= http
ifneq ($(GIT_PROTOCOL), http)
GITHUB               ?= git://github.com
else
GITHUB               ?= https://github.com
endif
GIT_NAME             ?= Duckbox-Developers
GIT_NAME_DRIVER      ?= Duckbox-Developers
GIT_NAME_APPS        ?= Duckbox-Developers
GIT_NAME_FLASH       ?= Duckbox-Developers

TUFSBOX_DIR           = $(BASE_DIR)/tufsbox
CROSS_BASE            = $(BASE_DIR)/cross/$(BOXARCH)
TARGET_DIR            = $(TUFSBOX_DIR)/cdkroot
BOOT_DIR              = $(TUFSBOX_DIR)/cdkroot-tftpboot
CROSS_DIR             = $(TUFSBOX_DIR)/cross
HOST_DIR              = $(TUFSBOX_DIR)/host
RELEASE_DIR           = $(TUFSBOX_DIR)/release

CONTROL_DIR           = $(BASE_DIR)/pkgs/control
PACKAGE_DIR           = $(BASE_DIR)/pkgs/opkg
PKG_DIR               = $(BUILD_TMP)/pkg

CUSTOM_DIR            = $(BASE_DIR)/custom
OWN_BUILD             = $(BASE_DIR)/own_build
PATCHES               = $(BASE_DIR)/Patches
SCRIPTS_DIR           = $(BASE_DIR)/scripts
SKEL_ROOT             = $(BASE_DIR)/root
D                     = $(BASE_DIR)/.deps
# backwards compatibility
DEPDIR                = $(D)

SUDOCMD               = echo $(SUDOPASSWD) | sudo -S

WHOAMI               := $(shell id -un)
MAINTAINER           ?= $(shell whoami)

CCACHE                = /usr/bin/ccache

BUILD                ?= $(shell /usr/share/libtool/config.guess 2>/dev/null || /usr/share/libtool/config/config.guess 2>/dev/null || /usr/share/misc/config.guess 2>/dev/null)

OPTIMIZATIONS        ?= size
TARGET_CFLAGS         = -pipe
ifeq ($(OPTIMIZATIONS), size)
TARGET_CFLAGS        += -Os
TARGET_EXTRA_CFLAGS   = -ffunction-sections -fdata-sections
TARGET_EXTRA_LDFLAGS  = -Wl,--gc-sections
endif
ifeq ($(OPTIMIZATIONS), normal)
TARGET_CFLAGS        += -O2
TARGET_EXTRA_CFLAGS   =
TARGET_EXTRA_LDFLAGS  =
endif
ifeq ($(OPTIMIZATIONS), kerneldebug)
TARGET_CFLAGS        += -O2
TARGET_EXTRA_CFLAGS   =
TARGET_EXTRA_LDFLAGS  =
endif
ifeq ($(OPTIMIZATIONS), debug)
TARGET_CFLAGS        += -O0 -g
TARGET_EXTRA_CFLAGS   =
TARGET_EXTRA_LDFLAGS  =
endif


TARGET_LIB_DIR        = $(TARGET_DIR)/usr/lib
TARGET_INCLUDE_DIR    = $(TARGET_DIR)/usr/include

TARGET_CFLAGS        += $(TARGET_EXTRA_CFLAGS) -I$(TARGET_INCLUDE_DIR)
TARGET_CPPFLAGS       = $(TARGET_CFLAGS)
TARGET_CXXFLAGS       = $(TARGET_CFLAGS)
TARGET_LDFLAGS        = -Wl,-rpath -Wl,/usr/lib -Wl,-rpath-link -Wl,$(TARGET_LIB_DIR) -L$(TARGET_LIB_DIR) -L$(TARGET_DIR)/lib $(TARGET_EXTRA_LDFLAGS)
LD_FLAGS              = $(TARGET_LDFLAGS)
PKG_CONFIG            = $(HOST_DIR)/bin/$(TARGET)-pkg-config
PKG_CONFIG_PATH       = $(TARGET_LIB_DIR)/pkgconfig

VPATH                 = $(D)

PATH                 := $(HOST_DIR)/bin:$(CROSS_DIR)/bin:$(CROSS_BASE)/bin:$(PATH):/sbin:/usr/sbin:/usr/local/sbin

TERM_RED             := \033[00;31m
TERM_RED_BOLD        := \033[01;31m
TERM_GREEN           := \033[00;32m
TERM_GREEN_BOLD      := \033[01;32m
TERM_YELLOW          := \033[00;33m
TERM_YELLOW_BOLD     := \033[01;33m
TERM_NORMAL          := \033[0m

MAKEFLAGS            += --no-print-directory
# To put more focus on warnings, be less verbose as default
# Use 'make V=1' to see the full commands
ifeq ("$(origin V)", "command line")
KBUILD_VERBOSE        = $(V)
endif
ifndef KBUILD_VERBOSE
KBUILD_VERBOSE        = 0
endif

# If KBUILD_VERBOSE equals 0 then the above command will be hidden.
# If KBUILD_VERBOSE equals 1 then the above command is displayed.
ifeq ($(KBUILD_VERBOSE),1)
SILENT_PATCH          =
SILENT_OPT            =
SILENT                =
WGET_SILENT_OPT       =
else
SILENT_PATCH          = -s
SILENT_OPT           := >/dev/null 2>&1
SILENT                = @
WGET_SILENT_OPT       = -o /dev/null
MAKEFLAGS            += --silent
endif

# helper-"functions":
REWRITE_LIBTOOL       = sed -i "s,^libdir=.*,libdir='$(TARGET_DIR)/usr/lib'," $(TARGET_DIR)/usr/lib
REWRITE_LIBTOOLDEP    = sed -i -e "s,\(^dependency_libs='\| \|-L\|^dependency_libs='\)/usr/lib,\ $(TARGET_DIR)/usr/lib,g" $(TARGET_DIR)/usr/lib
REWRITE_PKGCONF       = sed -i "s,^prefix=.*,prefix='$(TARGET_DIR)/usr',"
REWRITE_LIBTOOL_OPT   = sed -i "s,^libdir=.*,libdir='$(TARGET_DIR)/opt/pkg/lib'," $(TARGET_DIR)/opt/pkg/lib
REWRITE_PKGCONF_OPT   = sed -i "s,^prefix=.*,prefix='$(TARGET_DIR)/opt/pkg',"

export RM=$(shell which rm) -f

# unpack tarballs, clean up
UNTAR                 = $(SILENT)tar -C $(BUILD_TMP) -xf $(ARCHIVE)
REMOVE                = $(SILENT)rm -rf $(BUILD_TMP)
RM_PKG_DIR            = $(SILENT)rm -rf $(PKG_DIR)

#
split_deps_dir=$(subst ., ,$(1))
DEPS_DIR              = $(subst $(D)/,,$@)
PKG_NAME              = $(word 1,$(call split_deps_dir,$(DEPS_DIR)))
PKG_NAME_HELPER       = $(shell echo $(PKG_NAME) | sed 's/.*/\U&/')
PKG_VER_HELPER        = A$($(PKG_NAME_HELPER)_VER)A
PKG_VER               = $($(PKG_NAME_HELPER)_VER)

START_BUILD           = @echo "=============================================================="; \
                        echo; \
                        if [ $(PKG_VER_HELPER) == "AA" ]; then \
                            echo -e "Start build of $(TERM_GREEN_BOLD)$(PKG_NAME)$(TERM_NORMAL)"; \
                        else \
                            echo -e "Start build of $(TERM_GREEN_BOLD)$(PKG_NAME) $(PKG_VER)$(TERM_NORMAL)"; \
                        fi

TOUCH                 = @touch $@; \
                        echo "--------------------------------------------------------------"; \
                        if [ $(PKG_VER_HELPER) == "AA" ]; then \
                            echo -e "Build of $(TERM_GREEN_BOLD)$(PKG_NAME)$(TERM_NORMAL) completed"; \
                        else \
                            echo -e "Build of $(TERM_GREEN_BOLD)$(PKG_NAME) $(PKG_VER)$(TERM_NORMAL) completed"; \
                        fi; \
                        echo

#
PATCH                 = patch -p1 $(SILENT_PATCH) -i $(PATCHES)
APATCH                = patch -p1 $(SILENT_PATCH) -i
define post_patch
    for i in $(1); do \
        if [ -d $$i ]; then \
            for p in $$i/*; do \
                if [ $${p:0:1} == "/" ]; then \
                    echo -e "==> $(TERM_RED)Applying Patch:$(TERM_NORMAL) $$p"; $(APATCH) $$p; \
                else \
                    echo -e "==> $(TERM_RED)Applying Patch:$(TERM_NORMAL) $$p"; $(PATCH)/$$p; \
                fi; \
            done; \
        else \
            if [ $${i:0:1} == "/" ]; then \
                echo -e "==> $(TERM_RED)Applying Patch:$(TERM_NORMAL) $$i"; $(APATCH) $$i; \
            else \
                echo -e "==> $(TERM_RED)Applying Patch:$(TERM_NORMAL) $$i"; $(PATCH)/$$i; \
            fi; \
        fi; \
    done; \
    if [ $(PKG_VER_HELPER) == "AA" ]; then \
        echo -e "Patching $(TERM_GREEN_BOLD)$(PKG_NAME)$(TERM_NORMAL) completed"; \
    else \
        echo -e "Patching $(TERM_GREEN_BOLD)$(PKG_NAME) $(PKG_VER)$(TERM_NORMAL) completed"; \
    fi; \
    echo
endef

#
#
#
OPKG_SH_ENV  = PACKAGE_DIR=$(PACKAGE_DIR)
OPKG_SH_ENV += STRIP=$(TARGET)-strip
OPKG_SH_ENV += MAINTAINER="$(MAINTAINER)"
OPKG_SH_ENV += ARCH=$(BOXARCH)
OPKG_SH_ENV += SOURCE=$(PKG_DIR)
OPKG_SH_ENV += BUILD_TMP=$(BUILD_TMP)
OPKG_SH = $(OPKG_SH_ENV) opkg.sh

# wget tarballs into archive directory
WGET = wget --progress=bar:force --no-check-certificate $(WGET_SILENT_OPT) -t6 -T20 -c -P $(ARCHIVE)

TUXBOX_YAUD_CUSTOMIZE = [ -x $(CUSTOM_DIR)/$(notdir $@)-local.sh ] && KERNEL_VER=$(KERNEL_VER) && BOXTYPE=$(BOXTYPE) && $(CUSTOM_DIR)/$(notdir $@)-local.sh $(RELEASE_DIR) $(TARGET_DIR) $(BASE_DIR) $(SOURCE_DIR) $(FLASH_DIR) $(BOXTYPE) || true
TUXBOX_CUSTOMIZE      = [ -x $(CUSTOM_DIR)/$(notdir $@)-local.sh ] && KERNEL_VER=$(KERNEL_VER) && BOXTYPE=$(BOXTYPE) && $(CUSTOM_DIR)/$(notdir $@)-local.sh $(RELEASE_DIR) $(TARGET_DIR) $(BASE_DIR) $(FLASH_DIR) $(BOXTYPE) || true

#
#
#
CONFIGURE_OPTS = \
	--build=$(BUILD) \
	--host=$(TARGET) \

BUILDENV = \
	CC=$(TARGET)-gcc \
	CXX=$(TARGET)-g++ \
	LD=$(TARGET)-ld \
	NM=$(TARGET)-nm \
	AR=$(TARGET)-ar \
	AS=$(TARGET)-as \
	RANLIB=$(TARGET)-ranlib \
	STRIP=$(TARGET)-strip \
	OBJCOPY=$(TARGET)-objcopy \
	OBJDUMP=$(TARGET)-objdump \
	LN_S="ln -s" \
	CFLAGS="$(TARGET_CFLAGS)" \
	CPPFLAGS="$(TARGET_CPPFLAGS)" \
	CXXFLAGS="$(TARGET_CXXFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	PKG_CONFIG_PATH="$(PKG_CONFIG_PATH)"

CONFIGURE = \
	test -f ./configure || ./autogen.sh $(SILENT_OPT) && \
	$(BUILDENV) \
	./configure $(SILENT_OPT) $(CONFIGURE_OPTS)

CONFIGURE_TOOLS = \
	./autogen.sh $(SILENT_OPT) && \
	$(BUILDENV) \
	./configure $(SILENT_OPT) $(CONFIGURE_OPTS)

MAKE_OPTS := \
	CC=$(TARGET)-gcc \
	CXX=$(TARGET)-g++ \
	LD=$(TARGET)-ld \
	NM=$(TARGET)-nm \
	AR=$(TARGET)-ar \
	AS=$(TARGET)-as \
	RANLIB=$(TARGET)-ranlib \
	STRIP=$(TARGET)-strip \
	OBJCOPY=$(TARGET)-objcopy \
	OBJDUMP=$(TARGET)-objdump \
	LN_S="ln -s" \
	ARCH=sh \
	CROSS_COMPILE=$(TARGET)-

#
# image
#
ifeq ($(IMAGE), enigma2)
BUILD_CONFIG       = build-enigma2
else ifeq ($(IMAGE), enigma2-wlandriver)
BUILD_CONFIG       = build-enigma2
WLANDRIVER         = WLANDRIVER=wlandriver
else ifeq ($(IMAGE), neutrino)
BUILD_CONFIG       = build-neutrino
else ifeq ($(IMAGE), neutrino-wlandriver)
BUILD_CONFIG       = build-neutrino
WLANDRIVER         = WLANDRIVER=wlandriver
else
BUILD_CONFIG       = build-neutrino
endif

#
#
#
ifeq ($(MEDIAFW), eplayer3)
EPLAYER3           = 1
else ifeq ($(MEDIAFW), gstreamer)
gstreamer          = 1
else ifeq ($(MEDIAFW), gst-eplayer3)
EPLAYER3           = 1
gst-eplayer3       = 1
else
buildinplayer      = 1
endif

#
# multicom
#
ifeq ($(MULTICOM_VER), 324)
MULTICOM324        = multicom324
MULTICOM_LINK      = multicom-3.2.4
else
MULTICOM406        = multicom406
MULTICOM_LINK      = multicom-4.0.6
endif

#
# player 2
#
ifeq ($(PLAYER_VER), 191)
PLAYER2            = PLAYER191=player191
PLAYER191          = 1
PLAYER_VER_DRIVER  = 191
PLAYER2_LINK       = player2_191
else ifeq ($(PLAYER_VER), 191_test)
PLAYER2            = PLAYER191=player191
PLAYER191          = 1
PLAYER_VER_DRIVER  = 191
PLAYER2_LINK       = player2_191_test
endif

#
DRIVER_PLATFORM   := $(PLAYER2) $(WLANDRIVER)

#
ifeq ($(BOXTYPE), ufs910)
KERNEL_PATCHES_24  = $(UFS910_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_UFS910
DRIVER_PLATFORM   += UFS910=ufs910
E_CONFIG_OPTS     += --enable-ufs910
endif
ifeq ($(BOXTYPE), ufs912)
KERNEL_PATCHES_24  = $(UFS912_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_UFS912
DRIVER_PLATFORM   += UFS912=ufs912
E_CONFIG_OPTS     += --enable-ufs912
endif
ifeq ($(BOXTYPE), ufs913)
KERNEL_PATCHES_24  = $(UFS913_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_UFS913
DRIVER_PLATFORM   += UFS913=ufs913
E_CONFIG_OPTS     += --enable-ufs913
endif
ifeq ($(BOXTYPE), ufs922)
KERNEL_PATCHES_24  = $(UFS922_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_UFS922
DRIVER_PLATFORM   += UFS922=ufs922
E_CONFIG_OPTS     += --enable-ufs922
endif
ifeq ($(BOXTYPE), ufc960)
KERNEL_PATCHES_24  = $(UFC960_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_UFC960
DRIVER_PLATFORM   += UFC960=ufc960
E_CONFIG_OPTS     += --enable-ufc960
endif
ifeq ($(BOXTYPE), tf7700)
KERNEL_PATCHES_24  = $(TF7700_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_TF7700
DRIVER_PLATFORM   += TF7700=tf7700
E_CONFIG_OPTS     += --enable-tf7700
endif
ifeq ($(BOXTYPE), hl101)
KERNEL_PATCHES_24  = $(HL101_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HL101
DRIVER_PLATFORM   += HL101=hl101
E_CONFIG_OPTS     += --enable-hl101
endif
ifeq ($(BOXTYPE), spark)
KERNEL_PATCHES_24  = $(SPARK_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_SPARK
DRIVER_PLATFORM   += SPARK=spark
E_CONFIG_OPTS     += --enable-spark
endif
ifeq ($(BOXTYPE), spark7162)
KERNEL_PATCHES_24  = $(SPARK7162_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_SPARK7162
DRIVER_PLATFORM   += SPARK7162=spark7162
E_CONFIG_OPTS     += --enable-spark7162
endif
ifeq ($(BOXTYPE), fortis_hdbox)
KERNEL_PATCHES_24  = $(FORTIS_HDBOX_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_FORTIS_HDBOX
DRIVER_PLATFORM   += FORTIS_HDBOX=fortis_hdbox
E_CONFIG_OPTS     += --enable-fortis_hdbox
endif
ifeq ($(BOXTYPE), hs7110)
KERNEL_PATCHES_24  = $(HS7110_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HS7110
DRIVER_PLATFORM   += HS7110=hs7110
E_CONFIG_OPTS     += --enable-hs7110
endif
ifeq ($(BOXTYPE), hs7119)
KERNEL_PATCHES_24  = $(HS7119_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HS7119
DRIVER_PLATFORM   += HS7119=hs7119
E_CONFIG_OPTS     += --enable-hs7119
endif
ifeq ($(BOXTYPE), hs7420)
KERNEL_PATCHES_24  = $(HS7420_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HS7420
DRIVER_PLATFORM   += HS7420=hs7420
E_CONFIG_OPTS     += --enable-hs7420
endif
ifeq ($(BOXTYPE), hs7429)
KERNEL_PATCHES_24  = $(HS7429_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HS7429
DRIVER_PLATFORM   += HS7429=hs7429
E_CONFIG_OPTS     += --enable-hs7429
endif
ifeq ($(BOXTYPE), hs7810a)
KERNEL_PATCHES_24  = $(HS7810A_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HS7810A
DRIVER_PLATFORM   += HS7810A=hs7810a
E_CONFIG_OPTS     += --enable-hs7810a
endif
ifeq ($(BOXTYPE), hs7819)
KERNEL_PATCHES_24  = $(HS7819_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HS7819
DRIVER_PLATFORM   += HS7819=hs7819
E_CONFIG_OPTS     += -enable-hs7819
endif
ifeq ($(BOXTYPE), atemio520)
KERNEL_PATCHES_24  = $(ATEMIO520_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_ATEMIO520
DRIVER_PLATFORM   += ATEMIO520=atemio520
E_CONFIG_OPTS     += --enable-atemio520
endif
ifeq ($(BOXTYPE), atemio530)
KERNEL_PATCHES_24  = $(ATEMIO530_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_ATEMIO530
DRIVER_PLATFORM   += ATEMIO530=atemio530
E_CONFIG_OPTS     += --enable-atemio530
endif
ifeq ($(BOXTYPE), atevio7500)
KERNEL_PATCHES_24  = $(ATEVIO7500_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_ATEVIO7500
DRIVER_PLATFORM   += ATEVIO7500=atevio7500
E_CONFIG_OPTS     += --enable-atevio7500
endif
ifeq ($(BOXTYPE), octagon1008)
KERNEL_PATCHES_24  = $(OCTAGON1008_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_OCTAGON1008
DRIVER_PLATFORM   += OCTAGON1008=octagon1008
E_CONFIG_OPTS     += --enable-octagon1008
endif
ifeq ($(BOXTYPE), adb_box)
KERNEL_PATCHES_24  = $(ADB_BOX_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_ADB_BOX
DRIVER_PLATFORM   += ADB_BOX=adb_box
E_CONFIG_OPTS     += --enable-adb_box
endif
ifeq ($(BOXTYPE), ipbox55)
KERNEL_PATCHES_24  = $(IPBOX55_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_IPBOX55
DRIVER_PLATFORM   += IPBOX55=ipbox55
E_CONFIG_OPTS     += --enable-ipbox55
endif
ifeq ($(BOXTYPE), ipbox99)
KERNEL_PATCHES_24  = $(IPBOX99_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_IPBOX99
DRIVER_PLATFORM   += IPBOX99=ipbox99
E_CONFIG_OPTS     += --enable-ipbox99
endif
ifeq ($(BOXTYPE), ipbox9900)
KERNEL_PATCHES_24  = $(IPBOX9900_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_IPBOX9900
DRIVER_PLATFORM   += IPBOX9900=ipbox9900
E_CONFIG_OPTS     += --enable-ipbox9900
endif
ifeq ($(BOXTYPE), cuberevo)
KERNEL_PATCHES_24  = $(CUBEREVO_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO
DRIVER_PLATFORM   += CUBEREVO=cuberevo
E_CONFIG_OPTS     += --enable-cuberevo
endif
ifeq ($(BOXTYPE), cuberevo_mini)
KERNEL_PATCHES_24  = $(CUBEREVO_MINI_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_MINI
DRIVER_PLATFORM   += CUBEREVO_MINI=cuberevo_mini
E_CONFIG_OPTS     += --enable-cuberevo
endif
ifeq ($(BOXTYPE), cuberevo_mini2)
KERNEL_PATCHES_24  = $(CUBEREVO_MINI2_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_MINI2
DRIVER_PLATFORM   += CUBEREVO_MINI2=cuberevo_mini2
E_CONFIG_OPTS     += --enable-cuberevo
endif
ifeq ($(BOXTYPE), cuberevo_mini_fta)
KERNEL_PATCHES_24  = $(CUBEREVO_MINI_FTA_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_MINI_FTA
DRIVER_PLATFORM   += CUBEREVO_MINI_FTA=cuberevo_mini_fta
E_CONFIG_OPTS     += --enable-cuberevo
endif
ifeq ($(BOXTYPE), cuberevo_250hd)
KERNEL_PATCHES_24  = $(CUBEREVO_250HD_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_250HD
DRIVER_PLATFORM   += CUBEREVO_250HD=cuberevo_250hd
E_CONFIG_OPTS     += --enable-cuberevo
endif
ifeq ($(BOXTYPE), cuberevo_2000hd)
KERNEL_PATCHES_24  = $(CUBEREVO_2000HD_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_2000HD
DRIVER_PLATFORM   += CUBEREVO_2000HD=cuberevo_2000hd
E_CONFIG_OPTS     += --enable-cuberevo
endif
ifeq ($(BOXTYPE), cuberevo_3000hd)
KERNEL_PATCHES_24  = $(CUBEREVO_3000HD_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_3000HD
DRIVER_PLATFORM   += CUBEREVO_3000HD=cuberevo_3000hd
E_CONFIG_OPTS     += --enable-cuberevo
endif
ifeq ($(BOXTYPE), cuberevo_9500hd)
KERNEL_PATCHES_24  = $(CUBEREVO_9500HD_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_9500HD
DRIVER_PLATFORM   += CUBEREVO_9500HD=cuberevo_9500hd
E_CONFIG_OPTS     += --enable-cuberevo
endif
ifeq ($(BOXTYPE), vitamin_hd5000)
KERNEL_PATCHES_24  = $(VITAMIN_HD5000_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_VITAMIN_HD5000
DRIVER_PLATFORM   += VITAMIN_HD5000=vitamin_hd5000
E_CONFIG_OPTS     += --enable-vitamin_hd5000
endif
ifeq ($(BOXTYPE), sagemcom88)
KERNEL_PATCHES_24  = $(SAGEMCOM88_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_SAGEMCOM88
DRIVER_PLATFORM   += SAGEMCOM88=sagemcom88
E_CONFIG_OPTS     += --enable-sagemcom88
endif
ifeq ($(BOXTYPE), arivalink200)
KERNEL_PATCHES_24  = $(ARIVALINK200_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_ARIVALINK200
DRIVER_PLATFORM   += ARIVALINK200=arivalink200
E_CONFIG_OPTS     += --enable-arivalink200
endif

