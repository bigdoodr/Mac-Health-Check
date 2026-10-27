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
        errorOut "${humanReadableCheckName}: Discoverable by Everyone (value: ${result})"
        dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorFail}, iconalpha: 1, subtitle: System Settings > General > AirDrop & Continuity > AirDrop > No One / Contacts Only, status: fail, statustext: Everyone"
        overallHealth+="${humanReadableCheckName}; "
        footerStatusColor="${statusColorFail}"
    fi

    dialogUpdate "icon: ${footerCheckIcon},weight=semibold,colour=${footerStatusColor}"
    sleep $((anticipationDuration / 2))

}
