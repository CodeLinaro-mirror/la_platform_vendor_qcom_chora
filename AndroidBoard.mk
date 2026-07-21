LOCAL_PATH := $(call my-dir)

#----------------------------------------------------------------------
# Host compiler configs
#----------------------------------------------------------------------
TARGET_HOST_COMPILER_PREFIX_OVERRIDE := prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/bin/x86_64-linux-
TARGET_HOST_CC_OVERRIDE := $(TARGET_HOST_COMPILER_PREFIX_OVERRIDE)gcc
TARGET_HOST_CXX_OVERRIDE := $(TARGET_HOST_COMPILER_PREFIX_OVERRIDE)g++
TARGET_HOST_AR_OVERRIDE := $(TARGET_HOST_COMPILER_PREFIX_OVERRIDE)ar
TARGET_HOST_LD_OVERRIDE := $(TARGET_HOST_COMPILER_PREFIX_OVERRIDE)ld

#----------------------------------------------------------------------
# Compile (L)ittle (K)ernel bootloader and the nandwrite utility
#----------------------------------------------------------------------
ifneq ($(strip $(TARGET_NO_BOOTLOADER)),true)
ifneq ($(strip $(TARGET_SIGNONLY_BOOTLOADER)),true)

# Compile
include bootable/bootloader/edk2/AndroidBoot.mk

$(INSTALLED_BOOTLOADER_MODULE): $(TARGET_EMMC_BOOTLOADER) | $(ACP)
else
TARGET_EMMC_BOOTLOADER := $(TARGET_BOARD_UNSIGNED_ABL_DIR)/unsigned_abl.elf
SIGN_ABL := $(PRODUCT_OUT)/abl.elf

SECTOOLSV2_BIN := $(QCPATH)/sectools/Linux/sectools

# Unified signed-image generator.
# Usage: $(call sec-image-generate,<outfile>,<security-profile>,<log-suffix>)
#   $(1) - output signed ELF path
#   $(2) - sectools security-profile XML(s), space-separated
#   $(3) - log/description suffix (empty string for the base ABL variant)
define sec-image-generate
        echo "Generating signed appsbl$(if $(3), ($(3) suffix),) using secimagev2 tool"
        rm -rf $(1)
        ( $(SECTOOLSV2_BIN) secure-image $(TARGET_EMMC_BOOTLOADER) \
                --outfile $(1) \
                --image-id ABL \
                --security-profile $(2) \
                --sign \
                --signing-mode TEST \
                > $(PRODUCT_OUT)/secimage$(if $(3),_$(3),).log 2>&1 )
        echo "Completed secimagev2 signed appsbl (ABL$(if $(3), $(3),)) (logs in $(PRODUCT_OUT)/secimage$(if $(3),_$(3),).log)"
endef

# Base ABL signed image
$(SIGN_ABL): $(TARGET_EMMC_BOOTLOADER)
	$(call sec-image-generate,$(SIGN_ABL),$(SECTOOLS_SECURITY_PROFILE),)

# Extra signed ABL images — auto-discovered from BoardConfig.mk.
# Any variable named SECTOOLS_SECURITY_PROFILE_EXTRA_ABL_<suffix> triggers
# a new signed target abl-<suffix>.elf using the listed security-profile XMLs.
# No separate registry variable is needed; presence of the variable is enough.
_EXTRA_ABL_VARS    := $(filter SECTOOLS_SECURITY_PROFILE_EXTRA_ABL_%,$(.VARIABLES))
_EXTRA_ABL_SUFFIXES := $(patsubst SECTOOLS_SECURITY_PROFILE_EXTRA_ABL_%,%,$(_EXTRA_ABL_VARS))
$(foreach _sfx,$(_EXTRA_ABL_SUFFIXES), \
  $(eval _extra_out := $(PRODUCT_OUT)/abl-$(_sfx).elf) \
  $(eval $(_extra_out): $(TARGET_EMMC_BOOTLOADER) ; \
    $$(call sec-image-generate,$$@,$$(SECTOOLS_SECURITY_PROFILE_EXTRA_ABL_$(_sfx)),$(_sfx))) \
  $(eval $(BUILT_TARGET_FILES_PACKAGE): $(_extra_out)) \
  $(eval droidcore: $(_extra_out)) \
  $(eval droidcore-unbundled: $(_extra_out)) \
)

$(INSTALLED_BOOTLOADER_MODULE): $(SIGN_ABL) | $(ACP)
endif

#   $(transform-prebuilt-to-target)
$(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_BOOTLOADER_MODULE)
$(BUILT_TARGET_FILES_PACKAGE): $(SIGN_ABL_SPF)

droidcore: $(INSTALLED_BOOTLOADER_MODULE)
droidcore-unbundled: $(INSTALLED_BOOTLOADER_MODULE)
droidcore: $(SIGN_ABL_SPF)
droidcore-unbundled: $(SIGN_ABL_SPF)
endif

#----------------------------------------------------------------------
# Copy additional target-specific files
#----------------------------------------------------------------------
include $(CLEAR_VARS)
LOCAL_MODULE       := init.target.rc
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_SRC_FILES    := $(LOCAL_MODULE)
LOCAL_MODULE_PATH  := $(TARGET_OUT_VENDOR_ETC)/init/hw
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := fstab.qcom
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := ETC
ifeq ($(ENABLE_AB), true)
    LOCAL_SRC_FILES := fstab.qcom
else
    LOCAL_SRC_FILES := fstab_non_AB.qcom
endif
LOCAL_MODULE_PATH  := $(TARGET_OUT_VENDOR_ETC)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE       := charger_fstab.qcom
LOCAL_MODULE_TAGS  := optional
LOCAL_MODULE_CLASS := ETC
ifeq ($(ENABLE_AB), true)
    LOCAL_SRC_FILES := charger_fstab.qcom
else
    LOCAL_SRC_FILES := charger_fstab_non_AB.qcom
endif
LOCAL_MODULE_PATH  := $(TARGET_OUT_VENDOR_ETC)
include $(BUILD_PREBUILT)

include device/qcom/vendor-common/MergeConfig.mk

#----------------------------------------------------------------------
# Radio image
#----------------------------------------------------------------------
ifeq ($(ADD_RADIO_FILES), true)
radio_dir := $(LOCAL_PATH)/radio
RADIO_FILES := $(notdir $(wildcard $(radio_dir)/*))
$(foreach f, $(RADIO_FILES), \
    $(call add-radio-file,radio/$(f)))
endif

#----------------------------------------------------------------------
# Configs common to AndroidBoard.mk for all targets
#----------------------------------------------------------------------
include vendor/qcom/opensource/core-utils/build/AndroidBoardCommon.mk

$(warning his is to print target out vendor $(TARGET_OUT_VENDOR))
VENDOR_VM_SYSTEM_MOUNT_POINT := $(TARGET_OUT_VENDOR)/vm-system
ALL_DEFAULT_INSTALLED_MODULES += $(VENDOR_VM_SYSTEM_MOUNT_POINT)
$(VENDOR_VM_SYSTEM_MOUNT_POINT):
	@echo "Creating $(VENDOR_VM_SYSTEM_MOUNT_POINT)"
	@mkdir -p $(TARGET_OUT_VENDOR)/vm-system
