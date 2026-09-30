# 
# Copyright (C) 2025-2026 The AviumUI Project
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

TOP=$(gettop)

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

function get_gms() {
    if [ -z "$TOP" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return 1
    fi

    local cli_mode=0
    local cli_update_local_manifests=0
    local cli_run_sync=0
    local arg=""

    for arg in "$@"; do
        if [ "$arg" = "--cli" ]; then
            cli_mode=1
            break
        fi
    done

    if [ "$cli_mode" -eq 1 ]; then
        for arg in "$@"; do
            case "$arg" in
                --cli)
                    ;;
                --update-local-manifests)
                    cli_update_local_manifests=1
                    ;;
                --run-sync)
                    cli_run_sync=1
                    ;;
                *)
                    echo -e "${RED}error:${RESET} unknown get_gms argument: $arg"
                    echo "Usage: avium get_gms [--cli [--update-local-manifests] [--run-sync]]"
                    return 1
                    ;;
            esac
        done
    fi

    local SRC_XML="$TOP/vendor/avium/manifest_snippets/pixel.xml"
    local DST_DIR="$TOP/.repo/local_manifests"
    local DST_XML="$DST_DIR/pixel.xml"

    if [ ! -f "$SRC_XML" ]; then
        echo -e "${RED}error:${RESET} source manifest not found:"
        echo "  $SRC_XML"
        return 1
    fi

    mkdir -p "$DST_DIR"

    local force_sync=0

    if [ -f "$DST_XML" ]; then
        if diff -q "$SRC_XML" "$DST_XML" >/dev/null; then
            echo -e "${GREEN}pixel.xml already up to date.${RESET}"
        else
            echo -e "${YELLOW}Local manifest differs from source:${RESET}"
            echo "  $DST_XML"
            echo
            force_sync=1

            if [ "$cli_mode" -eq 1 ]; then
                if [ "$cli_update_local_manifests" -eq 1 ]; then
                    answer="y"
                else
                    answer="n"
                fi
            elif [ -t 0 ]; then
                echo -ne "${YELLOW}Overwrite with new pixel.xml? [y/N] ${RESET}"
                IFS= read -r answer
            else
                answer="n"
            fi

            case "$answer" in
                y|Y)
                    cp "$SRC_XML" "$DST_XML"
                    echo -e "${GREEN}pixel.xml updated.${RESET}"
                    ;;
                *)
                    echo -e "${BLUE}Keeping existing pixel.xml.${RESET}"
                    ;;
            esac
        fi
    else
        cp "$SRC_XML" "$DST_XML"
        echo -e "${GREEN}pixel.xml installed into local_manifests.${RESET}"
    fi

    echo

    if [ "$cli_mode" -eq 1 ]; then
        if [ "$cli_run_sync" -eq 1 ]; then
            sync_answer="y"
        else
            sync_answer="n"
        fi
    elif [ -t 0 ]; then
        echo -ne "${YELLOW}Sync GMS repositories now? [y/N] ${RESET}"
        IFS= read -r sync_answer
    else
        sync_answer="n"
    fi

    case "$sync_answer" in
        y|Y)
            echo
            echo -e "${BLUE}Executing repo sync command...${RESET}"
            echo

            repo sync \
                vendor/pixel/clocks \
                vendor/pixel/sounds \
                vendor/pixel/gms \
                -c -j5 \
                $( [ "$force_sync" -eq 1 ] && echo "--force-sync" )

            local sync_ret=$?

            echo
            if [ $sync_ret -eq 0 ]; then
                echo -e "${GREEN}repo sync finished.${RESET}"
		echo -e "${BLUE}Merging file parts...${RESET}"
		merge_files
            else
                echo -e "${RED}repo sync failed (exit code $sync_ret).${RESET}"
                return $sync_ret
            fi
            ;;
        *)
            echo -e "${BLUE}repo sync skipped.${RESET}"
            echo -e "${BLUE}You can run 'avium get_gms' to download GMS.${RESET}"
            ;;
    esac
}

function remove_gms() {
    if ! [ -n "$TOP" ];then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return 1
        exit 1
    fi
    # Due to some historical reasons, some builders still remain old
    # method to download the gms.
    # TODO: Remove this when capable.
    rm -rf "$TOP/.repo/local_manifests/pixel.xml"
    rm -rf "$TOP/vendor/gms"
    echo "GMS files removed. You can run 'avium get_gms' to download them again."
}

function merge_file_parts() {
    target_file="$1"
    remerge_mode=0

    if [ -z "$target_file" ]; then
        echo -e "merge_file_parts(): ${RED}ERROR: merge_file_parts() requires a target file path.${RESET}" >&2
        return 1
    fi

    if [ -f "$target_file" ]; then
        rm -rf $target_file
        remerge_mode=1
    fi

    part_prefix="$target_file"
    found_part=0

    for part in "${part_prefix}".*.part; do
        [ -e "$part" ] || continue

        if [ "$found_part" -eq 0 ]; then
            : > "$target_file"
            found_part=1
        fi
        cat "$part" >> "$target_file"
    done

    [ "$found_part" -eq 0 ] && return 0

    if [ "$remerge_mode" != "1" ]; then
    if [ -s "$target_file" ]; then
        echo -e "merge_file_parts(): ${GREEN}Merged: $target_file${RESET}"
    fi
    fi
}

function avium_build() {
    local avium_device="$1"
    local avium_variant="$2"
    local -a avium_targets=("${@:3}")

    if [ -z "$avium_device" ]; then
        echo -e "Usage: avium build <device> <variant> <target>"
        echo -e "       device  - Device codename (e.g., thyme)"
        echo -e "       variant - Build variant (user, userdebug, eng)"
        echo -e "       target  - Build target (default: bacon)"
        echo -e
        echo -e "<target> options:"
        echo -e "  bacon            - Build the ROM (default)"
        echo -e "  fastbootpackage  - Build the Fastboot package(Use fastboot update <file> to flash)"
        echo -e "  recoveryimage    - Build only recovery image(if available)"
        echo -e "  bootimage        - Build only boot image"
        return 1
        exit 1
    fi
    if [ ${#avium_targets[@]} -eq 0 ]; then
        echo "No build target specified. Defaulting to 'bacon'."
        avium_targets=(bacon)
    fi
    if [ -z "$avium_variant" ]; then
        echo "No build variant specified. Defaulting to 'userdebug'."
        avium_variant="userdebug"
    fi
    if ! [ -n "$TOP" ];then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return 1
        exit 1
    fi
    source ${ANDROID_BUILD_TOP}/vendor/lineage/vars/aosp_target_release
    lunch lineage_$avium_device-$aosp_target_release-$avium_variant
    if ! [ $? -eq 0 ]; then
        echo "ERROR: Unable to locate device configuration for $avium_device" 
        echo "       Please ensure the device codename is correct and the device tree is present."
        return 1
        exit 1
    fi
    mka "${avium_targets[@]}" -j$(nproc --all)
}
function avium_gerrit() {
    local subcommand="$1"
    shift

    case "$subcommand" in
        init)
            avium_gerrit_init
            ;;
        push_for_review)
            avium_gerrit_push_for_review
            ;;
        *)
            echo "Usage: avium gerrit [init|push_for_review]"
            echo "       init - Initialize git user info and Avium Gerrit config"
            echo "       push_for_review - Push changes to Avium Gerrit for review"
            ;;
    esac
}

function avium_gerrit_init() {
    if ! [ -n "$TOP" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "git is not installed or not on PATH."
        return 1
    fi

    echo "AviumUI Gerrit URL is https://review.aviumui.org"
    git config --global avium.gerrit.host "review.aviumui.org:29418"

    echo "Configure global git user information and Avium Gerrit username."
    echo "This information is used for commits and Gerrit interactions."
    echo "You can leave any field empty to keep the current value or use the default."
    echo "Press Ctrl+C to skip configuration or if you want to set these manually later."
    echo "Note: The Avium Gerrit username need you to register on the Avium Gerrit web interface first before using it here."
    echo "So if you haven't registered yet, you can just press Enter to use the default value and update it later after registration."
    echo
    sleep 3s
  
    local prompts=(
        "Git user name"
        "Git user email"
        "AviumUI Gerrit username"
    )
    local defaults=(
        "${AVIUM_GERRIT_NAME:-Avium Gerrit User}"
        "${AVIUM_GERRIT_EMAIL:-avium@example.com}"
        "${AVIUM_GERRIT_USERNAME:-avium}"
    )
    local keys=(
        "user.name"
        "user.email"
        "avium.gerrit.username"
    )

    for i in "${!keys[@]}"; do
        echo "${prompts[$i]} (current: $(git config --global --get "${keys[$i]}" 2>/dev/null || "not set"))"
    done

    local key current value answer

    for i in "${!keys[@]}"; do
        key="${keys[$i]}"
        current=$(git config --global --get "$key" 2>/dev/null || true)

        if [ -n "$current" ]; then
            echo "$key already configured as '$current'."
            echo -n "Keep this value? [Y/n] "
            IFS= read -r answer
            if [ -z "$answer" ] || [[ "$answer" =~ ^[Yy]$ ]]; then
                echo "Keeping $key='$current'"
                continue
            fi
            echo -n "Enter new ${prompts[$i]} (leave empty to keep current): "
            IFS= read -r value
            if [ -z "$value" ]; then
                echo "Keeping $key='$current'"
                continue
            fi
        else
            local default="${defaults[$i]}"
            echo -n "Enter ${prompts[$i]} [${default}]: "
            IFS= read -r value
            if [ -z "$value" ]; then
                value="$default"
            fi
        fi

        git config --global "$key" "$value"
        echo "Configured $key = '$value'"
    done

    echo "Git and Avium Gerrit configuration complete."
}

function avium_gerrit_push_for_review() {
    if ! [ -n "$TOP" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "git is not installed or not on PATH."
        return 1
    fi

    local gerrit_host=$(git config --global --get avium.gerrit.host)
    if [ -z "$gerrit_host" ]; then
        echo "Avium Gerrit host is not configured. Please run 'avium gerrit init' first."
        return 1
    fi

    local gerrit_user=$(git config --global --get avium.gerrit.username)
    if [ -z "$gerrit_user" ] || [ "$gerrit_user" = "avium" ]; then
        echo "Avium Gerrit username is not configured. Please run 'avium gerrit init' first."
        return 1
    fi

    # Try to get repository name from multiple sources
    local repo_name=""
    
    # Method 1: Try from git remote origin URL
    local remote_url=$(git config --get remote.avium.url 2>/dev/null || true)
    if [ -n "$remote_url" ]; then
        repo_name=$(basename "$remote_url" | sed 's/\.git$//')
    fi
    
    
    # Method 2: Prompt user if unable to determine
    if [ -z "$repo_name" ] || [ "$repo_name" = "unknown" ]; then
        echo "Could not automatically determine repository name."
        echo "Please enter the repository name (e.g., 'android_manifests'):"
        read -r repo_name
        if [ -z "$repo_name" ]; then
            echo "No repository name provided. Aborting."
            return 1
        fi
    fi
    
    local gerrit_remote_url="ssh://$gerrit_user@$gerrit_host/$repo_name"
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [ -z "$current_branch" ]; then
        echo "Unable to determine current git branch."
        echo "Please input the branch you want to push for review:"
        read -r current_branch
        if [ -z "$current_branch" ]; then
            echo "No branch specified. Aborting."
            return 1
        fi
    fi
    local push_ref="HEAD:refs/for/$current_branch"
    
    echo "Repository name: $repo_name"
    echo "Gerrit URL: $gerrit_remote_url"
    echo "Pushing current branch '$current_branch' to Avium Gerrit for review..."
    git push "$gerrit_remote_url" "$push_ref"
}



function gen_keys() {
    if ! [ -n "$TOP" ];then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return 1
        exit 1
    fi
    local subject='/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=android@android.com'
    mkdir ~/.avium-certs
    for cert in bluetooth cyngn-app media networkstack nfc platform releasekey sdk_sandbox shared testcert testkey verity; do
    ./development/tools/make_key ~/.avium-certs/$cert "$subject"; \
    done
    cp ./development/tools/make_key ~/.avium-certs/
    sed -i 's|2048|4096|g' ~/.avium-certs/make_key
    for apex in com.android.adbd com.android.adservices com.android.adservices.api com.android.appsearch com.android.appsearch.apk com.android.art com.android.bluetooth com.android.btservices com.android.cellbroadcast com.android.compos com.android.configinfrastructure com.android.connectivity.resources com.android.conscrypt com.android.devicelock com.android.extservices com.android.graphics.pdf com.android.hardware.authsecret com.android.hardware.biometrics.face.virtual com.android.hardware.biometrics.fingerprint.virtual com.android.hardware.boot com.android.hardware.cas com.android.hardware.neuralnetworks com.android.hardware.rebootescrow com.android.hardware.wifi com.android.healthfitness com.android.hotspot2.osulogin com.android.i18n com.android.ipsec com.android.media com.android.media.swcodec com.android.mediaprovider com.android.nearby.halfsheet com.android.networkstack.tethering com.android.neuralnetworks com.android.nfcservices com.android.ondevicepersonalization com.android.os.statsd com.android.permission com.android.profiling com.android.resolv com.android.rkpd com.android.runtime com.android.safetycenter.resources com.android.scheduling com.android.sdkext com.android.support.apexer com.android.telephony com.android.telephonymodules com.android.tethering com.android.tzdata com.android.uwb com.android.uwb.resources com.android.virt com.android.vndk.current com.android.vndk.current.on_vendor com.android.wifi com.android.wifi.dialog com.android.wifi.resources com.google.pixel.camera.hal com.google.pixel.vibrator.hal com.qorvo.uwb; do \
    subject='/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN='$apex'/emailAddress=android@android.com'
    ~/.avium-certs/make_key ~/.avium-certs/$apex "$subject"
    openssl pkcs8 -in ~/.avium-certs/$apex.pk8 -inform DER -nocrypt -out ~/.avium-certs/$apex.pem
    done
}

function avium() {
    local T=$(gettop)
    if [ -z "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return 1
        exit 1
    fi
    case "$1" in
        get_gms)
            shift
            get_gms "$@"
            ;;
        remove_gms)
            remove_gms
            ;;
        build)
            shift
            avium_build "$@"
            ;;
        gerrit)
            avium_gerrit "$2" "$3" "$4" "$5" "$6" "$7" "$8"
            ;;
        *)
            echo "Usage: avium [build|get_gms|remove_gms|gerrit] [options]"
            echo "       build       - Build Avium for a specific device and variant"
            echo "       get_gms     - Download GMS files"
            echo "                     CLI mode: avium get_gms --cli [--update-local-manifests] [--run-sync]"
            echo "       remove_gms  - Remove GMS files"
            echo "       gerrit      - Gerrit utilities for AviumUI development"
            ;;
    esac
}

function merge_files() {
merge_file_parts "packages/apps/DepthWallpaperHelper/DepthWallpaperHelper.apk"
merge_file_parts "vendor/pixel/gms/common/proprietary/product/app/Maps/Maps.apk"
merge_file_parts "vendor/pixel/gms/common/proprietary/product/app/Photos/Photos.apk"
merge_file_parts "vendor/pixel/gms/common/proprietary/product/app/PrebuiltGmail/PrebuiltGmail.apk"
merge_file_parts "vendor/pixel/gms/common/proprietary/product/priv-app/DevicePersonalizationPrebuiltPixel2024-playstore_aiai_20250306.00_RC10/DevicePersonalizationPrebuiltPixel2024-playstore_aiai_20250306.00_RC10.apk"
merge_file_parts "vendor/pixel/gms/common/proprietary/product/priv-app/PrebuiltBugle/PrebuiltBugle.apk"
merge_file_parts "vendor/pixel/gms/common/proprietary/product/priv-app/PrebuiltGmsCoreVic/PrebuiltGmsCoreVic.apk"
merge_file_parts "vendor/pixel/gms/common/proprietary/product/priv-app/Velvet/Velvet.apk"
}

merge_files
