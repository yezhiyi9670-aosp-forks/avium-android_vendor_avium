# 
# Copyright (C) 2025 The AviumUI Project
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Avium Version
AVIUM_MAJOR_VERSION := 16
AVIUM_MINOR_VERSION := 2
AVIUM_PATCH_VERSION := 2

AVIUM_VER := AviumUI-$(AVIUM_MAJOR_VERSION).$(AVIUM_MINOR_VERSION).$(AVIUM_PATCH_VERSION)-$(LINEAGE_BUILD)

# Date format
ifeq ($(AVIUM_VERSION_APPEND_TIME_OF_DAY),true)
    AVIUM_BUILD_DATE := $(shell date -u +%Y%m%d_%H%M%S)
else
    AVIUM_BUILD_DATE := $(shell date -u +%Y%m%d)
endif

# Display version
AVIUM_DISPLAY_VERSION := $(AVIUM_VER)-$(AVIUM_BUILD_DATE)

# Full version
# Because some devices have 'mtdoops.fingerprint' in cmdline.
# Some device tree use LINEAGE_VERSION as default value.
ifeq ($(AVIUM_IS_OFFICIAL),true)
    AVIUM_VERSION := $(AVIUM_VER)-$(AVIUM_BUILD_DATE)-Official
    LINEAGE_VERSION := AviumUI-Official-$(LINEAGE_BUILD)-$(AVIUM_BUILD_DATE)
else
    AVIUM_VERSION := $(AVIUM_VER)-$(AVIUM_BUILD_DATE)-Unofficial
    LINEAGE_VERSION := AviumUI-Unofficial-$(LINEAGE_BUILD)-$(AVIUM_BUILD_DATE)
endif

# Package name
ifeq ($(AVIUM_IS_OFFICIAL),true)
    AVIUM_PACKAGE_NAME := $(AVIUM_DISPLAY_VERSION)-Official
else
    AVIUM_PACKAGE_NAME := $(AVIUM_DISPLAY_VERSION)-Unofficial
endif

# GMS Status
ifeq ($(WITH_GMS), true)
    AVIUM_VERSION := $(AVIUM_VERSION)-GMS
    AVIUM_PACKAGE_NAME := $(AVIUM_PACKAGE_NAME)-GMS
else
    AVIUM_VERSION := $(AVIUM_VERSION)-Vanilla
    AVIUM_PACKAGE_NAME := $(AVIUM_PACKAGE_NAME)-Vanilla
endif

# AviumUI version properties
PRODUCT_PRODUCT_PROPERTIES += \
	ro.avium.build.version=$(AVIUM_MAJOR_VERSION).$(AVIUM_MINOR_VERSION).$(AVIUM_PATCH_VERSION) \
	ro.avium.display.version=$(AVIUM_DISPLAY_VERSION) \
	ro.avium.gms_status=$(WITH_GMS) \
	ro.avium.maintainer=$(AVIUM_MAINTAINER) \
	ro.avium.is_official=$(AVIUM_IS_OFFICIAL) \
	ro.avium.version=$(AVIUM_VER)
	
