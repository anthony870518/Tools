#!/bin/bash
jira_url='https://jira.com/rest/api/2/search'
jira_user='username'
jira_password='password'
startdate=`date --date="7 days ago" +"%Y-%m-%d"`
enddate=`date +"%Y-%m-%d"`
initial_results_path='/opt/tools/auto_weekly_report/jira_tickets/initial_result.txt'
final_results_path='/opt/tools/auto_weekly_report/jira_tickets/final_results_from_jiraAPI.txt'

# query and fields for Parent tickets last week
# customfield_11001 = Region, customfield_10802 = start date, customfield_10803 = end date,
#customfield_11011 = root cause, customfield_11006 = duration, customfield_11200 = player impact(%)
query_for_parents='project = GIN AND issuetype = Incident AND \"Start Time\" >= \"'$startdate'\" AND \"Start Time\" < \"'$enddate'\" ORDER BY issuetype DESC, cf[11200] ASC'
fields_for_parents='["customfield_11001", "components", "summary", "customfield_10802", "customfield_10803", "customfield_11011", "customfield_11006", "customfield_11200"]'


# Using curl to fetch data and store it in a variable
data_for_parents=$(curl -X POST "$jira_url" \
     -u "$jira_user:$jira_password" \
     -H "Content-type: application/json" \
     -d "{\"jql\": \"$query_for_parents\", \"fields\": $fields_for_parents, \"validateQuery\": false, \"maxResults\": 50}" \
     --insecure --silent)
# Using jq to parse and transform the data manually without join, and append it to output.tsv
echo "$data_for_parents" | jq -r '.issues[] | [
    .key,
    (.fields.customfield_11001[0].value // "N/A"),
    (.fields.components | map(.name) | reduce .[] as $item (""; if . == "" then $item else . + "," + $item end)) // "N/A",
    .fields.summary,
    .fields.customfield_10802,
	.fields.customfield_10803,
    (.fields.customfield_11011[0].value // "N/A"),
    (.fields.customfield_11006 // "N/A" | tostring),
    (if .fields.customfield_11200 == null then "N/A" else .fields.customfield_11200 | tostring end)
   ] | map(tostring) | .[0] + "\t" + .[1] + "\t" + .[2] + "\t" + .[3] + "\t" + .[4] + "\t" + .[5] + "\t" + .[6] + "\t" + .[7] + "\t" + .[8]' > $initial_results_path
echo "" > $final_results_path

# Process each line in the input file
while IFS=$'\t' read -r ticket_num region product summary start_date end_date root_cause duration impact_percentage; do
	# Date formating
    startDate="${start_date%%T*} ${start_date#*T}"
	startDate="${startDate%:*}"
	endDate="${end_date%%T*} ${end_date#*T}"
	endDate="${endDate%:*}"

    last_col=$impact_percentage

    if [[ "$last_col" == "0" || "$last_col" == "N/A" ]]; then
        echo "$ticket_num is a parent"

        # List sub tickets of the parent ticket
        query_subs="key = $ticket_num"
        fields_subs='["subtasks"]'

        # Fetch data using curl
        getsubdata=$(curl -X POST "$jira_url" \
             -u "$jira_user:$jira_password" \
             -H "Content-type: application/json" \
             -d "{\"jql\": \"$query_subs\", \"fields\": $fields_subs, \"validateQuery\": false, \"maxResults\": 50}" \
             --insecure --silent)

        # Extract subtask keys
        subtickets=$(echo "$getsubdata" | jq -r '.issues[] | .fields.subtasks[] | .key')

        if [[ -z "$subtickets" ]]; then
          echo "No subtasks found for $ticket_num."
        else
          combined_info=""
          first_subticket=true
          echo "Subtasks for $ticket_num:"
          for ticket in $subtickets; do
                # Get player impact of each sub ticket
                sub_query="key = $ticket"
                sub_fields='["components","customfield_11200"]'

                # Fetch data for subtask using curl
                sub_data=$(curl -X POST "$jira_url" \
                     -u "$jira_user:$jira_password" \
                     -H "Content-type: application/json" \
                     -d "{\"jql\": \"$sub_query\", \"fields\": $sub_fields, \"validateQuery\": false, \"maxResults\": 50}" \
                     --insecure --silent)

                # Extract components and impact for subtask
                sub_component=$(echo $sub_data | jq -r '.issues[] | .fields.components[0] | .name | tostring')
                sub_impact=$(echo $sub_data | jq -r '.issues[] | .fields.customfield_11200 | tostring')

                if $first_subticket; then
                    combined_info+="$sub_component: $sub_impact"
                    first_subticket=false
                else
                    combined_info+=", $sub_component: $sub_impact"
                fi
          done
          echo -e "$ticket_num\t$region\t$product\t$summary\t$startDate\t$endDate\t$root_cause\t$duration\t$combined_info" >> $final_results_path
        fi
    else
        echo -e "$ticket_num\t$region\t$product\t$summary\t$startDate\t$endDate\t$root_cause\t$duration\t$impact_percentage" >> $final_results_path
    fi
done < "$initial_results_path"