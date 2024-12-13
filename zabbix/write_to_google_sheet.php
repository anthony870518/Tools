<?php
require_once '/opt/google-api/vendor/autoload.php';

//print_r($_GET);

// 建立 Google Client
$client = new \Google_Client();
$client->setApplicationName('Google Sheets and PHP');
// 設定權限
$client->setScopes([\Google_Service_Sheets::SPREADSHEETS]);
$client->setAccessType('offline');
// 引入金鑰
$client->setAuthConfig('xxxxxxxxxx.json');

// 建立 Google Sheets Service
$service = new \Google_Service_Sheets($client);

// Google Sheet ID
$spreadsheetId = 'xxxxxxxxxxxxxxxxx';
// 取得 Sheet 範圍
$values = $_GET;
$range = "$values[0]$values[1]";
$updateRange = "'Zabbix alerts'!$range";
// 值
print_r($_GET[0],$_GET[1]);

$update_value=array_slice($values,2);
// Update Sheet
$body = new \Google_Service_Sheets_ValueRange([
    'values' => [$update_value]
]);

$params = [
    'valueInputOption' => 'USER_ENTERED'
];

$updateSheet = $service->spreadsheets_values->update($spreadsheetId, $updateRange, $body, $params);

exit;
?>
