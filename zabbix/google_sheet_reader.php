<?php
require_once '/opt/google-api/vendor/autoload.php';
// 建立 Google Client
$client = new \Google_Client();
$client->setApplicationName('Google Sheets and PHP');
// 設定權限
$client->setScopes([\Google_Service_Sheets::SPREADSHEETS]);
$client->setAccessType('offline');
// 引入金鑰
$client->setAuthConfig('xxxxxxxxxxxxxxxxx.json');
// 建立 Google Sheets Service
$service = new \Google_Service_Sheets($client);
try{

    $spreadsheetId = 'xxxxxxxxxxxxxxxxx';
    $range = 'Integrated SSL list(DO NOT EDIT)!A2:E1000';
    $response = $service->spreadsheets_values->get($spreadsheetId, $range);
    $values = $response->getValues();

    if (empty($values)) {
        print "No data found.\n";
    } else {
        foreach ($values as $row) {
            // Print columns A and E, which correspond to indices 0 and 4.
            //printf("%s|%s|%s|%s\n", $row[0], $row[1], $row[2], $row[4]);
                printf(
                    "%s|%s|%s|%s\n",
                    isset($row[0]) ? $row[0] : '',
                    isset($row[1]) ? $row[1] : '',
                    isset($row[2]) ? $row[2] : '',
                    isset($row[4]) ? $row[4] : ''
                );
        }
    }
}
catch(Exception $e) {
    echo 'Message: ' .$e->getMessage();
}
exit;
?>