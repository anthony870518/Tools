#bin/bash
#functions

exclude_ips=("$@")


# Define a function named "seatalknotifier" responsible for sending a notification to a specified URL if the previous command succeeds
#舊bot: seatalknotifier(){
#        if [[ $? -eq 0 ]]; then
#                curl -s -X POST "10.59.74.187:8123" --data-urlencode "uid=10038" --data-urlencode "message=$message" --data-urlencode "mode=single"
#        fi
#}
send_seatalk() {
    local message="$1"
    local json_msg=$(jq -nc \
        --arg msg "$message" \
        --arg gid "NTY0ODEyNzM3ODk5" \
        '{message: $msg, group_id: $gid}')

    curl -s -X POST "http://10.59.74.107:8520/seatalk/send" \
         -H "Content-Type: application/json" \
         -d "$json_msg"
}

# Define a function named "statusReport" to check the status of a specific process using SSH and handle different scenarios
statusReport(){
        # Check the process using SSH and store the result in the "checkProcess" variable
        checkProcess=`$SSH "ps -aux 2>/dev/null | grep $process_config | grep -v grep"`
        case $? in
                0)
                        if [[ -z "$checkProcess" ]] # if check is null
                        then
                                echo "$process_config status(0=normal): $?"
                                status="down"
                                # Debug
                                echo "$(date +%Y/%m/%d-%H:%M:%S) $hostname : $check"
                        else
                                status="running"
                        fi
                        ;;

                1)
                        echo "$process_config status(0=normal): $?"
                        status="down"
                        ;;

                *)
                        if [[ $try -gt 3 ]]
                        then
                                echo "$process_config status(0=normal): $?"
                                message="(Auto check)Jenkins unable to ssh $hostname."
                                send_seatalk "$message"
                                exit
                        else
                                echo "$process_config status(0=normal): $?"
                                ((try=try+1))
                                sleep 5
                                statusReport
                        fi;;
        esac
}

# Define a function named "proccess_checker" to check the status of a process and take appropriate actions
proccess_checker(){
        statusReport
        if [[ $status == 'down' ]]
        then
                message="(Auto check)$process_config for $hostname is $status, trying to pull up proccess"
                echo $message
                send_seatalk "$message"
                # Trying to pull up process
                echo "$SSH sudo $proccesspuller"
                $SSH sudo $proccesspuller

                # Double checking if the process is working
                statusReport
                sleep 2

                # Still not working
                if [[ $status == 'down' ]]
                then
                        message="(Auto check)Pull up failed, $process_config for $hostname is still $status."
                        send_seatalk "$message"
                # Pull up succeed
                elif [[ $status == 'running' ]]
                then
                        message="(Auto check)Pull up succeed for $process_config."
                        send_seatalk "$message"
                # Exceptions
                else
                        messge="(Auto check)Unexpected error while checking $process_config for $hostname."
                        send_seatalk "$message"
                fi
        # Process is working
        elif [[ $status == 'running' ]]
        then
                message="(Auto check)$process_config for $hostname is $status"
        # Exceptions
        else
                messge="(Auto check)Unexpected error while checking $process_config for $hostname."
                send_seatalk "$message"
        fi
}

# Fetch a list of proxy IP addresses from a file
proxy_iplist=`cat /opt/jenkins/common/host_list | grep -i Proxy | grep -iv 'Disable' | cut -f3`

if [ "${#exclude_ips[@]}" -gt 0 ]; then
  for ip in "${exclude_ips[@]}"; do
    proxy_iplist=$(echo "$proxy_iplist" | grep -v "$ip")
  done
fi



# Iterate over each proxy IP address
for proxy in $proxy_iplist
do
        if [[ "$proxy" == *":"*  ]]
        then
                # If the proxy contains a port number, extract the IP and PORT
		IP=`echo "$proxy"|cut -d: -f1`
                PORT=`echo "$proxy"|cut -d: -f2`
        else
                # If no port is specified, use the default PORT 22
                IP=$proxy
                PORT=22
        fi

        # Fetch the hostname corresponding to the IP address
        hostname=`cat /opt/jenkins/common/host_list | grep $IP | cut -f2`
        echo "$hostname $IP -p $PORT"

        # SSH command to connect to the proxy using the specified key, user, IP, and port
        SSH="ssh -i /var/lib/jenkins/.ssh/id_rsa noc_jenkins@$IP -p $PORT -o StrictHostKeyChecking=no"

        # Find the process configuration file path for the proxy using SSH
        findproxyconfig=`$SSH "sudo find /opt/ \( -name '*v602*' -o -name '*v449*' \) | grep '.conf' | grep -iv 'disable' | grep -iv '.swp'"`

        # Iterate over each found process configuration file path
        for process_config_path in $findproxyconfig
        do
        	try=0

                # Extract the process configuration name from the path
                process_config=`echo "$process_config_path" | cut -d'/' -f5`

                # Check the version of the process and set the appropriate process puller command
		version_chk=`$SSH "sudo find /opt/  -name '*v602*'  | grep '.conf' | grep -iv 'disable' | grep -iv '.swp'"`
		if [[ -z "$version_chk" ]] #if not v602
		then
			proccesspuller="/opt/zabbix_proxy_v449/sbin/zabbix_proxy -c /opt/zabbix_proxy_v449/etc/$process_config"
		else
	                proccesspuller="/opt/zabbix_proxy_v602/sbin/zabbix_proxy -c /opt/zabbix_proxy_v602/etc/$process_config"
		fi

                # Perform the process check
                proccess_checker
                echo "$process_config status(0=normal): $?"
        done

        # Check the Zabbix agent process
        try=0
        process_config="zabbix_agentd.conf"
	version_chk=`$SSH "sudo find /opt/ -name 'zabbix_agentd.conf' | grep 'v602' | grep -iv 'disable | grep -iv '.swp''"`
	if [[ -z "$version_chk" ]] # If it's not v602
	then
		proccesspuller="/opt/zabbix_proxy_v449/sbin/zabbix_agentd -c /opt/zabbix_proxy_v449/etc/$process_config"
	else
		proccesspuller="/opt/zabbix_proxy_v602/sbin/zabbix_agentd -c /opt/zabbix_proxy_v602/etc/$process_config"
	fi
        proccess_checker
        echo "agent status(0=normal): $?"
done