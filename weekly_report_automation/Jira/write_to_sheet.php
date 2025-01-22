<?php
require_once '/opt/google-api/vendor/autoload.php';

$filePath = '/opt/tools/auto_weekly_report/jira_tickets/final_results_from_jiraAPI.txt';

// Read the file into an array, each element is a line
$final_data = file($filePath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

// Google Sheets setup
$client = new \Google_Client();
$client->setApplicationName('Google Sheets and PHP');
$client->setScopes([\Google_Service_Sheets::SPREADSHEETS]);
$client->setAccessType('offline');
$client->setAuthConfig('google-api_json_key');
$service = new \Google_Service_Sheets($client);

// Google Sheet ID and initial row
$spreadsheetId = 'spreadsheetId'; // Adjust as needed
$googleSheet_row = 2; // Starting row
#$googleSheet_column = 'A'; // Column from URL parameter

$rows_to_clean = 20;
for ($i = 1; $i < $rows_to_clean; $i++) {
	$update_values = ["", "", "", "", "", "", "", ""];
	$range = "A" . ($i + 1);;
	$updateRange = "'Tickets_overview'!$range";
	$body = new \Google_Service_Sheets_ValueRange(['values' => [$update_values]]);
	$params = ['valueInputOption' => 'USER_ENTERED'];
	$updateSheet = $service->spreadsheets_values->update($spreadsheetId, $updateRange, $body, $params);
}

// Loop through the combined data and update the Google Sheet
foreach ($final_data as $row) {
    $parts = explode("\t", $row); // Assuming each line is tab-separated values

    if (count($parts) == 9) {
        // Replace commas with newlines in the 'impact' field
        $parts[8] = str_replace(",", "\n", $parts[8]);

        // Prepare the update values
        $update_values = [$parts[1], $parts[2], $parts[3], $parts[4], $parts[5], $parts[6], $parts[7], $parts[8]]; // Adjust the indices as needed

        // Construct the range for the current row
        $range = "A$googleSheet_row";
        $updateRange = "'Tickets_overview'!$range";

        // Prepare the values to be updated
        $body = new \Google_Service_Sheets_ValueRange(['values' => [$update_values]]);
        $params = ['valueInputOption' => 'USER_ENTERED']; // This is important for interpreting \n as a newline

        // Update the sheet
        $updateSheet = $service->spreadsheets_values->update($spreadsheetId, $updateRange, $body, $params);

        // Increment the row counter
        $googleSheet_row++;
	}
	else {
		echo "Wrong amount of columns.";
    }
}

echo "Google Sheet updated successfully.";
try {
    $service->spreadsheets_values->update($spreadsheetId, $updateRange, $body, $params);
} catch (Exception $e) {
    error_log("Error updating Google Sheets: " . $e->getMessage());
}

?>