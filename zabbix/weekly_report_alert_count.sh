#Combine logs
today=`date --date="$i days ago" +"%Y-%m-%d"`
path="/opt/tools/weekly_report_alert_stats/logs"
echo "" > $path/weekly_report_zabbix_alerts.txt
echo "" > $path/weekly_report_zabbix_details.txt
echo "$today" > $path/weekly_report_result.txt

echo "Including Seatalk bot alerts log for these dates."
for ((i=7;i>0;i--))
do
	date=`date --date="$i days ago" +"%Y-%m-%d"`
	echo "weekly_report_zabbix_alerts.txt will include log of /tmp/botlog/seatalk_bot_log_$date.txt"
	cat /tmp/botlog/seatalk_bot_log_$date.txt >> $path/weekly_report_zabbix_alerts.txt
done

echo "---------------------------------------------------------------------"

sev_counter(){
        severity_list=('Disaster' 'SEV1' 'SEV2' 'SEV3')
        for severity in "${severity_list[@]}";
        do
		declare $severity\_count=`cat $path/weekly_report_zabbix_alerts.txt | grep $filter -A 5 | grep \\\[$severity] | grep -v "CCU" | wc -l`
        done

	if  [[ "$Disaster_count" != 0 || "$SEV1_count" != 0 || "$SEV2_count" != 0 || "$SEV3_count" != 0 ]];
	then
		echo -e "$project\t$Disaster_count\t$SEV1_count\t$SEV2_count\t$SEV3_count" >> $path/weekly_report_result.txt
	fi
}

write_to_sheet(){
	declare project=`cat $path/weekly_report_result.txt | head -n $catline | tail -n 1 | cut -f1`
	declare Disaster_count=`cat $path/weekly_report_result.txt | head -n $catline | tail -n 1 | cut -f2`
	declare SEV1_count=`cat $path/weekly_report_result.txt | head -n $catline | tail -n 1 | cut -f3`
	declare SEV2_count=`cat $path/weekly_report_result.txt | head -n $catline | tail -n 1 | cut -f4`
	declare SEV3_count=`cat $path/weekly_report_result.txt | head -n $catline | tail -n 1 | cut -f5`

	php-cgi -f /opt/tools/weekly_report_alert_stats/write_to_google_sheet.php 0=$sheet_column 1=$sheet_row 2=$project 3=$Disaster_count 4=$SEV1_count 5=$SEV2_count 6=$SEV3_count
	echo -e "$project\t$Disaster_count\t$SEV1_count\t$SEV2_count\t$SEV3_count"
	sheet_row=$((sheet_row+1))
}

#Cleaning Sheet
echo -e "Cleaning sheet"
switch=$((24/2+2))
line=2
row=3
for ((i=2;i<=24;i+=1))
do
	if [[ $line -lt $switch ]];
        then
                sheet_column="A"
                php-cgi -f /opt/tools/weekly_report_alert_stats/write_to_google_sheet.php 0=$sheet_column 1=$row 2=" " 3="" 4="" 5="" 6=""
		row=$((row+1))
        else
                if [[ $line -eq $switch ]]
                then
                        row=3
                fi
                sheet_column="G"
                php-cgi -f /opt/tools/weekly_report_alert_stats/write_to_google_sheet.php 0=$sheet_column 1=$row 2=" " 3="" 4="" 5="" 6=""
		row=$((row+1))
        fi
        line=$((line+1))
done

project_list=(
	'ProjectA'
	'ProjectB')

for project in "${project_list[@]}";
do
	if [ "$project" == "ProjectA" ]
	then
		filter="AliasB\]\|AliasA\]"
	else
		filter="$project\]"
	fi
	sev_counter
	if [ "$project" == "ProjectC" ]
        then
        	cat $path/weekly_report_zabbix_alerts.txt | grep Alert | grep -v TPE | grep $project | grep -v UDP >> $path/weekly_report_zabbix_details.txt
	else
	        cat $path/weekly_report_zabbix_alerts.txt | grep Alert | grep -v TPE | grep $project >> $path/weekly_report_zabbix_details.txt
	fi
done

#print on Google sheet
declare linecount=`cat $path/weekly_report_result.txt | wc -l`
switchpoint=$((linecount/2+2))

catline=2
sheet_row=3
for ((i=2;i<=$linecount;i+=1))
do
	if [[ $catline -lt $switchpoint ]];
	then
		sheet_column="A"
		write_to_sheet
	else
		if [[ $catline -eq $switchpoint ]]
		then
			sheet_row=3
		fi
		sheet_column="G"
		write_to_sheet
	fi
	catline=$((catline+1))
done
echo "Congrats, you've completed the report!"