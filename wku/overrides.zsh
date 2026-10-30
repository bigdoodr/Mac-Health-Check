####################################################################################################
#
# WKU Overrides
#
# Injected by the WKU build (github.com/bigdoodr/Mac-Health-Check, `wku` branch) just before
# upstream's "# Program" section, after every upstream function has been defined.
#
# Two kinds of override live here:
#
#   1. Wrappers: the upstream function is kept as wkuUpstream_<name> and the WKU version handles
#      only the checks WKU customizes, handing everything else back to upstream. These survive
#      upstream refactors as long as the function name and the check keys still exist.
#
#   2. Full replacements (checkVPN, checkAirDropSettings): the WKU version replaces the upstream
#      function outright. The build compares upstream's current copy of each of these against
#      wku/baselines/<name>.zsh and fails if upstream changed it, so a replacement is never
#      shipped on top of upstream logic nobody has reviewed.
#
####################################################################################################

function wkuWrapFunction() {
    local functionName="${1}"
    if (( ! ${+functions[${functionName}]} )); then
        print -u2 "WKU Overrides: upstream function ${functionName} not found; exiting."
        exit 1
    fi
    functions[wkuUpstream_${functionName}]="${functions[${functionName}]}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Inspect: problem text (short "what's wrong" line)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

wkuWrapFunction getInspectProblemTextByIndex

function getInspectProblemTextByIndex() {

    local index="${1}"
    local key="${checkKeyByIndex[${index}]}"
    local normalizedStatus="${checkNormalizedStatusByIndex[${index}]}"

    if [[ "${normalizedStatus}" != "healthy" ]]; then
        case "${key}" in
            "airdrop" )
                echo "Your current AirDrop settings makes your Mac visible to everyone."
                return
                ;;
            "airplay_receiver" )
                if [[ "${normalizedStatus}" == "fail" ]]; then
                    echo "Ensure AirPlay Receiver is disabled when not needed"
                    return
                fi
                ;;
        esac
    fi

    wkuUpstream_getInspectProblemTextByIndex "$@"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Inspect: remediation text (short "how to fix" line)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

wkuWrapFunction getInspectRemediationTextByIndex

function getInspectRemediationTextByIndex() {

    local index="${1}"
    local key="${checkKeyByIndex[${index}]}"
    local normalizedStatus="${checkNormalizedStatusByIndex[${index}]}"
    local remediation="${checkRemediationByIndex[${index}]}"

    if [[ "${normalizedStatus}" != "healthy" ]]; then
        case "${key}" in
            "vpn_client" )
                echo "Install Cisco Secure Client from Self-Service if VPN is needed"
                return
                ;;
            "homebrew_status" )
                echo "Open Terminal, run \"brew update && brew upgrade\" for formulae, then \"brew upgrade --cask\" for casks"
                return
                ;;
            "touch_id" )
                echo "Enroll a fingerprint in System Settings > Touch ID & Password. $( getInspectSupportFallbackText )"
                return
                ;;
            "filevault_encryption" )
                echo "Contact ${supportTeamName} for assistance enabling FileVault."
                return
                ;;
            "password_hint" )
                echo "Remove your password hint in System Settings > Users & Groups. $( getInspectSupportFallbackText )"
                return
                ;;
            "mosyle_mdm_profile" )
                echo "Contact ${supportTeamName} to reinstall the ${mdmVendor} MDM profile."
                return
                ;;
            "mosyle_mdm_certificate_expiration" )
                echo "Contact ${supportTeamName} if the certificate is expired or expiring soon."
                return
                ;;
            "mosyle_check_in" )
                echo "Contact ${supportTeamName} if your Mac hasn't checked in with Mosyle recently."
                return
                ;;
            "apple_push_notification_hosts" )
                echo "Check your network or VPN settings. $( getInspectSupportFallbackText )"
                return
                ;;
            "apple_device_management" )
                echo "Verify your network access. $( getInspectSupportFallbackText )"
                return
                ;;
            "apple_software_and_carrier_updates" )
                echo "Ensure you have Internet access. $( getInspectSupportFallbackText )"
                return
                ;;
            "apple_certificate_validation" )
                echo "Check your firewall/VPN settings. $( getInspectSupportFallbackText )"
                return
                ;;
            "apple_identity_and_content_services" )
                echo "Verify your network access. $( getInspectSupportFallbackText )"
                return
                ;;
            "electron_corner_mask" )
                if [[ -n "${remediation}" ]]; then
                    echo "${remediation}. Update or replace the affected apps, or contact ${supportTeamName} for guidance."
                else
                    echo "Update or replace the affected apps, or contact ${supportTeamName} for guidance."
                fi
                return
                ;;
        esac
    fi

    wkuUpstream_getInspectRemediationTextByIndex "$@"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Inspect: detail explanation (longer "why this matters" text)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

wkuWrapFunction getInspectDetailExplanationByIndex

function getInspectDetailExplanationByIndex() {

    local index="${1}"
    local key="${checkKeyByIndex[${index}]}"
    local normalizedStatus="${checkNormalizedStatusByIndex[${index}]}"
    local rawValue=""

    if [[ "${normalizedStatus}" != "healthy" ]]; then
        case "${key}" in
            "airdrop" )
                printf '%s' "Your current AirDrop settings makes your Mac visible to everyone."
                return
                ;;
            "airplay_receiver" )
                if [[ "${normalizedStatus}" == "fail" ]]; then
                    printf '%s' "Ensure AirPlay Receiver is disabled when not needed"
                    return
                fi
                ;;
            "vpn_client" )
                printf '%s' "WKU offers Cisco Secure Client VPN to access certain systems. It is not required unless your role or the systems you use require it."
                return
                ;;
            "homebrew_status" )
                rawValue="$( getInspectPreferredResultTextByIndex "${index}" )"
                printf '%s' "Homebrew-managed apps can also be targeted by attackers and should be kept patched, just like anything installed from the App Store or Self-Service."
                if [[ -n "${rawValue}" ]] && [[ "${rawValue}" != "Result unavailable" ]]; then
                    printf '\n\n%s' "**Current status:** ${rawValue}"
                fi
                return
                ;;
        esac
    fi

    wkuUpstream_getInspectDetailExplanationByIndex "$@"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Inspect: detail remediation (longer step-by-step fix)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

wkuWrapFunction getInspectDetailRemediationByIndex

function getInspectDetailRemediationByIndex() {

    local index="${1}"
    local key="${checkKeyByIndex[${index}]}"
    local normalizedStatus="${checkNormalizedStatusByIndex[${index}]}"

    if [[ "${normalizedStatus}" != "healthy" ]]; then
        case "${key}" in
            "airdrop" )
                printf '%s' "System Settings > General > AirDrop & Continuity > AirDrop > No One / Contacts Only"
                return
                ;;
            "airplay_receiver" )
                if [[ "${normalizedStatus}" == "fail" ]]; then
                    printf '%s' "System Settings > General > AirDrop & Continuity > AirPlay Receiver > Disable"
                    return
                fi
                ;;
            "vpn_client" )
                printf '%s' "Cisco Secure Client can be installed through the Self-Service app."
                return
                ;;
            "homebrew_status" )
                printf '%b' "1. Open **Terminal**.\n2. Run \`brew update && brew upgrade\` to update outdated Homebrew formulae.\n3. Run \`brew upgrade --cask\` to update outdated Homebrew casks.\n4. Run **Mac Health Check** again."
                return
                ;;
        esac
    fi

    wkuUpstream_getInspectDetailRemediationByIndex "$@"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check VPN (full replacement; baseline: wku/baselines/checkVPN.zsh)
#
# WKU: the VPN client is optional. "Not installed" and "Idle" are warnings (yellow), not failures,
# and do not add to overallHealth, so they never mark the Mac "Unhealthy".
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function checkVPN() {

    local footerCheckIcon="${vpnAppPath}"
    local footerStatusColor="${statusColorSuccess}"

    notice "Check ${vpnAppName} …"

    dialogUpdate "icon: ${vpnAppPath}"
    dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill $(echo "${organizationColorScheme}" | tr ',' ' '), iconalpha: 1, status: wait, statustext: Checking …"
    dialogUpdate "progress: increment"
    dialogUpdate "progresstext: Determining status of ${vpnAppName} …"

    # sleep "${anticipationDuration}"

    case ${vpnStatus} in

        *"NOT installed"* )
            # WKU: optional client, so this is a warning, not a failure
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorError}, iconalpha: 1, subtitle: Cisco Secure Client is not installed on this Mac, status: error, statustext: Not Installed"
            warning "${vpnAppName} Not Installed (optional)"
            footerCheckIcon="SF=exclamationmark.triangle.fill"
            footerStatusColor="${statusColorError}"
            ;;

        *"Idle"* )
            # WKU: installed but not connected is a warning, not a failure
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorError}, iconalpha: 1, subtitle: Cisco Secure Client is installed but not currently connected, status: error, statustext: Idle"
            info "${vpnAppName} idle"
            footerCheckIcon="SF=exclamationmark.triangle.fill"
            footerStatusColor="${statusColorError}"
            ;;

        "Connected"* | "${ciscoVPNIP}" )
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=semibold colour=${statusColorSuccess}, iconalpha: 0.9, subtitle: ${organizationBoilerplateComplianceMessage}, status: success, statustext: Connected"
            info "${vpnAppName} Connected"
            footerCheckIcon="SF=checkmark.circle"
            ;;

        "Internal" )
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=semibold colour=${statusColorSuccess}, iconalpha: 0.9, subtitle: On-campus / Internal network, status: success, statustext: Internal"
            info "${vpnAppName} Internal"
            footerCheckIcon="SF=checkmark.circle"
            ;;

        "Warning: Disconnected" | "Disconnected" )
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorError}, iconalpha: 1, status: error, statustext: Disconnected"
            warning "${vpnAppName} Disconnected"
            footerCheckIcon="SF=exclamationmark.triangle.fill"
            footerStatusColor="${statusColorError}"
            ;;

        "None" )
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorError}, iconalpha: 1, status: error, statustext: No VPN"
            info "No VPN"
            footerCheckIcon="SF=xmark.circle"
            footerStatusColor="${statusColorError}"
            ;;

        * )
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorError}, iconalpha: 1, status: error, statustext: Unknown"
            warning "${vpnAppName} Unknown"
            footerCheckIcon="SF=exclamationmark.triangle.fill"
            footerStatusColor="${statusColorError}"
            ;;

    esac

    dialogUpdate "icon: ${footerCheckIcon},weight=semibold,colour=${footerStatusColor}"
    sleep $((anticipationDuration / 2))

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check AirDrop Settings (full replacement; baseline: wku/baselines/checkAirDropSettings.zsh)
#
# WKU: AirDrop set to "Everyone" is a warning (yellow), not a failure, and does not add to
# overallHealth.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function checkAirDropSettings() {

    local humanReadableCheckName="AirDrop Settings"
    local footerCheckIcon="SF=airplayaudio.circle.fill"
    local footerStatusColor="${statusColorSuccess}"
    notice "Checking ${humanReadableCheckName} …"

    dialogUpdate "icon: SF=airplayaudio.circle.fill,${organizationColorScheme}"
    dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill $(echo "${organizationColorScheme}" | tr ',' ' '), iconalpha: 1, status: wait, statustext: Checking …"
    dialogUpdate "progress: increment"
    dialogUpdate "progresstext: Determining ${humanReadableCheckName} …"

    sleep "${anticipationDuration}"

    # Check AirDrop settings
    local result=$( captureRunAsUserOutput defaults read /Users/"${loggedInUser}"/Library/Preferences/com.apple.sharingd.plist DiscoverableMode )

    if [[ "${result}" != "Everyone" ]] || [[ -z "${result}" ]]; then
        info "${humanReadableCheckName}: Compliant"
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=semibold colour=${statusColorSuccess}, iconalpha: 0.9, subtitle: ${organizationBoilerplateComplianceMessage}, status: success, statustext: Compliant"
    else
        # WKU: warning, not a hard failure
        warning "${humanReadableCheckName}: Discoverable by Everyone (value: ${result})"
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorError}, iconalpha: 1, subtitle: System Settings > General > AirDrop & Continuity > AirDrop > No One / Contacts Only, status: error, statustext: Everyone"
        footerStatusColor="${statusColorError}"
    fi

    dialogUpdate "icon: ${footerCheckIcon},weight=semibold,colour=${footerStatusColor}"
    sleep $((anticipationDuration / 2))

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check Mosyle Check-In (full replacement; baseline: wku/baselines/checkMosyleCheckIn.zsh)
#
# WKU: upstream does arithmetic on the value of `defaults read com.mosyle.macos.manager.mdm
# MacCommandsReplyResultsSuccessDate`. When that domain or key is missing, the value is empty, zsh
# aborts with "bad math expression", the script exits, and in Self Service swiftDialog is left
# sitting on this step. Seen on test-group Macs in October 2026: current Mosyle agents keep this
# key in /var/root/Library/Preferences/com.mosyle.macos.mdm.daemon.plist (the "migration.6170"
# keys there suggest an agent update moved it), and the old domain is only sometimes present.
# This version reads both, keeps the newest, logs which one it used, and reports "Unknown" as a
# warning instead of exiting if neither has it. Submitted upstream as
# bigdoodr:bugfix/mosyle-check-in-unreadable; remove this override once Dan's release includes it.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function checkMosyleCheckIn() {

    local humanReadableCheckName="Last Mosyle check-in"
    local footerCheckIcon="SF=arrow.left.arrow.right.circle"
    local footerStatusColor="${statusColorSuccess}"
    local last_check_in_time=""
    local mosyleDomain=""
    notice "Checking ${humanReadableCheckName} …"

    dialogUpdate "icon: SF=arrow.left.arrow.right.circle,${organizationColorScheme}"
    dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill $(echo "${organizationColorScheme}" | tr ',' ' '), iconalpha: 1, status: wait, statustext: Checking …"
    dialogUpdate "progress: increment"
    dialogUpdate "progresstext: Determining ${humanReadableCheckName} …"

    sleep "${anticipationDuration}"

    # Number of seconds since action last occurred (86400 = 1 day)
    check_in_time_old=86400      # 1 day
    check_in_time_aging=28800    # 8 hours

    # WKU: read the current Mosyle agent's daemon plist and the older domain upstream reads, and keep
    # the newest (either can be stale); matches the fix submitted upstream
    local mosyleCheckInValue=""
    local mosyleCheckInSource=""
    for mosyleDomain in "/var/root/Library/Preferences/com.mosyle.macos.mdm.daemon" "com.mosyle.macos.manager.mdm"; do
        mosyleCheckInValue=$( defaults read "${mosyleDomain}" MacCommandsReplyResultsSuccessDate 2>/dev/null | cut -d. -f1 )
        [[ "${mosyleCheckInValue}" == <-> ]] || continue
        if (( mosyleCheckInValue > ${last_check_in_time:-0} )); then
            last_check_in_time="${mosyleCheckInValue}"
            mosyleCheckInSource="${mosyleDomain}"
        fi
    done

    if [[ -z "${last_check_in_time}" ]]; then
        # WKU: unreadable check-in time is a warning, not a crash
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorError}, iconalpha: 1, subtitle: Please contact ${supportTeamName}, status: error, statustext: Unknown"
        warning "${humanReadableCheckName}: Unknown (MacCommandsReplyResultsSuccessDate not found in com.mosyle.macos.mdm.daemon or com.mosyle.macos.manager.mdm)"
        footerStatusColor="${statusColorError}"
        dialogUpdate "icon: ${footerCheckIcon},weight=semibold,colour=${footerStatusColor}"
        sleep $((anticipationDuration / 2))
        return
    fi

    info "${humanReadableCheckName}: MacCommandsReplyResultsSuccessDate from ${mosyleCheckInSource}"

    # Convert last Mosyle check-in time to epoch
    last_check_in_time_epoch=$last_check_in_time
    currentTimeEpoch=$(date +%s)
    time_since_check_in_epoch=$(($currentTimeEpoch-$last_check_in_time_epoch))

    # Convert last Mosyle epoch to something easier to read
    eventDate=$( date -r "${last_check_in_time_epoch}" "+%Y-%m-%d" )
    todayDate=$( date "+%Y-%m-%d" )
    if [[ "${eventDate}" == "${todayDate}" ]]; then
        last_check_in_time_human_readable=$(date -r "${last_check_in_time_epoch}" "+%-l:%M %p" )
    else
        last_check_in_time_human_readable=$(date -r "${last_check_in_time_epoch}" "+%A %-l:%M %p")
    fi

    # Set status indicator for last check-in
    if [ ${time_since_check_in_epoch} -ge ${check_in_time_old} ]; then
        # check_in_status_indicator="🔴"
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorFail}, iconalpha: 1, status: fail, statustext: ${last_check_in_time_human_readable}"
        errorOut "${humanReadableCheckName}: ${last_check_in_time_human_readable}"
        overallHealth+="${humanReadableCheckName}; "
        footerStatusColor="${statusColorFail}"
    elif [ ${time_since_check_in_epoch} -ge ${check_in_time_aging} ]; then
        # check_in_status_indicator="🟠"
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorError}, iconalpha: 1, status: error, statustext: ${last_check_in_time_human_readable}"
        warning "${humanReadableCheckName}: ${last_check_in_time_human_readable}"
        overallHealth+="${humanReadableCheckName}; "
        footerStatusColor="${statusColorError}"
    elif [ ${time_since_check_in_epoch} -lt ${check_in_time_aging} ]; then
        # check_in_status_indicator="🟢"
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=semibold colour=${statusColorSuccess}, iconalpha: 0.9, subtitle: ${organizationBoilerplateComplianceMessage}, status: success, statustext: ${last_check_in_time_human_readable}"
        info "${humanReadableCheckName}: ${last_check_in_time_human_readable}"
    fi

    dialogUpdate "icon: ${footerCheckIcon},weight=semibold,colour=${footerStatusColor}"
    sleep $((anticipationDuration / 2))

}



####################################################################################################
# End WKU Overrides
####################################################################################################

