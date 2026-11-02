function checkAirPlayReceiver() {

    local humanReadableCheckName="AirPlay Receiver"
    local footerCheckIcon="SF=airplayvideo.circle.fill"
    local footerStatusColor="${statusColorSuccess}"
    notice "Checking ${humanReadableCheckName} status …"

    dialogUpdate "icon: SF=airplayvideo.circle.fill,${organizationColorScheme}"
    dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill $(echo "${organizationColorScheme}" | tr ',' ' '), iconalpha: 1, status: wait, statustext: Checking …"
    dialogUpdate "progress: increment"
    dialogUpdate "progresstext: Evaluating ${humanReadableCheckName} configuration …"

    sleep "${anticipationDuration}"
    
    # Key names and missing-key responses have changed across macOS versions.
    local result=""
    local keyFound=""
    local candidateKey=""
    local -a preferenceKeys=(
        "AirplayReceiverEnabled"
        "AirplayRecieverEnabled"
        "AirplayReceiverAdvertising"
    )

    for candidateKey in "${preferenceKeys[@]}"; do
        result=$( captureRunAsUserOutput /usr/bin/defaults -currentHost read com.apple.controlcenter "${candidateKey}" )
        if [[ "${result}" != *"does not exist"* ]] && \
           [[ "${result}" != *"Could not find key"* ]] && \
           [[ "${result}" != *"Domain 'com.apple.controlcenter' not found"* ]]; then
            keyFound="${candidateKey}"
            break
        fi
    done
    
    # Evaluate the result
    if [[ -z "${keyFound}" ]]; then
        # No key found:
        # - macOS 15.7.x and macOS 27 default to Enabled
        # - macOS 15.6.1 and earlier, and macOS 26, default to Disabled
        if [[ ( "${osMajorVersion}" -eq 15 && "${osMinorVersion}" -ge 7 ) || "${osMajorVersion}" -ge 27 ]]; then
            errorOut "${humanReadableCheckName}: Enabled (no ${keyFound:-AirplayReceiverEnabled} key; default behavior on macOS ${osMajorVersion}.${osMinorVersion})"
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorFail}, iconalpha: 1, subtitle: System Settings > General > AirDrop & Continuity > AirPlay Receiver > Disable, status: fail, statustext: Enabled"
            overallHealth+="${humanReadableCheckName}; "
            footerStatusColor="${statusColorFail}"
        else
            info "${humanReadableCheckName}: Disabled (key not found on macOS ${osMajorVersion}.${osMinorVersion})"
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=semibold colour=${statusColorSuccess}, iconalpha: 0.9, subtitle: ${organizationBoilerplateComplianceMessage}, status: success, statustext: Disabled"
        fi

    elif [[ "${result}" == "0" ]]; then
        # Value is 0, disabled (compliant)
        info "${humanReadableCheckName}: Disabled (${keyFound}=${result})"
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=semibold colour=${statusColorSuccess}, iconalpha: 0.9, subtitle: ${organizationBoilerplateComplianceMessage}, status: success, statustext: Disabled"

    elif [[ "${result}" == "1" ]]; then
        # Value is 1, enabled (non-compliant)
        errorOut "${humanReadableCheckName}: Enabled (${keyFound}=${result})"
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorFail}, iconalpha: 1, subtitle: System Settings > General > AirDrop & Continuity > AirPlay Receiver > Disable, status: fail, statustext: Enabled"
        overallHealth+="${humanReadableCheckName}; "
        footerStatusColor="${statusColorFail}"

    elif [[ "${result}" == "2" ]]; then
        # Value is 2 (Contacts Only mode in some versions)
        info "${humanReadableCheckName}: Contacts Only (${keyFound}=${result})"
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=semibold colour=${statusColorSuccess}, iconalpha: 0.9, subtitle: ${organizationBoilerplateComplianceMessage}, status: success, statustext: Contacts Only"

    else
        # Unexpected value
        warning "${humanReadableCheckName}: Unexpected value (${keyFound}=${result})"
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorError}, iconalpha: 1, subtitle: System Settings > General > AirDrop & Continuity > AirPlay Receiver > Disable, status: error, statustext: Status Unknown"
        footerStatusColor="${statusColorError}"
    fi

    dialogUpdate "icon: ${footerCheckIcon},weight=semibold,colour=${footerStatusColor}"
    sleep $((anticipationDuration / 2))

}
