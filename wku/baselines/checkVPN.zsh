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
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorFail}, iconalpha: 1, subtitle: Please contact ${supportTeamName}, status: fail, statustext: Failed"
            errorOut "${vpnAppName} Failed"
            overallHealth+="${vpnAppName}; "
            footerCheckIcon="SF=xmark.circle"
            footerStatusColor="${statusColorFail}"
            ;;

        *"Idle"* )
            dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill weight=bold colour=${statusColorError}, iconalpha: 1, status: error, statustext: Idle"
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
