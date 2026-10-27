function checkMosyleCheckIn() {

    local humanReadableCheckName="Last Mosyle check-in"
    local footerCheckIcon="SF=arrow.left.arrow.right.circle"
    local footerStatusColor="${statusColorSuccess}"
    notice "Checking ${humanReadableCheckName} …"

    dialogUpdate "icon: SF=arrow.left.arrow.right.circle,${organizationColorScheme}"
    dialogUpdate "listitem: index: ${1}, icon: SF=$(printf "%02d" $(($1+1))).circle.fill $(echo "${organizationColorScheme}" | tr ',' ' '), iconalpha: 1, status: wait, statustext: Checking …"
    dialogUpdate "progress: increment"
    dialogUpdate "progresstext: Determining ${humanReadableCheckName} …"

    sleep "${anticipationDuration}"

    # Number of seconds since action last occurred (86400 = 1 day)
    check_in_time_old=86400      # 1 day
    check_in_time_aging=28800    # 8 hours

	last_check_in_time=$(defaults read com.mosyle.macos.manager.mdm MacCommandsReplyResultsSuccessDate | cut -d. -f1)

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
