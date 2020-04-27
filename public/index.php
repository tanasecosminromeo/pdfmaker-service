<?php

$token = $_POST['token'] ?? $_GET['token'] ?? $_SERVER['HTTP_TOKEN'];
if ($token !== getenv('APP_TOKEN')){ echo "Invalid Token"; exit; }

ob_start();
error_reporting(E_ALL);

$loader = require '../vendor/autoload.php';
use mikehaertl\wkhtmlto\Pdf;

$path = str_replace("/index.php", "/", __FILE__);

$filename = "/tmp/".sha1(@$_SERVER['REMOTE_ADDR'].":".@$_SERVER['HTTP_REFERER'].time().rand(0,9999));
$url = null;

if (isset($_POST['html'])){
	$content = str_replace("£", "&pound", $_POST['html']);

	file_put_contents($filename.".html", $content);
	$url = $filename.".html";
} elseif (isset($_POST['url'])){
	$url = $_POST['url'];
} else {
	echo "Please specify the file you want to convert";
	exit;
}

if ($url!=null){
	$pdf = new Pdf();

	if (!empty($_POST['landscape'])){
		$pdf->setOptions(array(
			'orientation' => 'landscape'
		));
	}
	$pdf->addPage($url);

	if (!$pdf->saveAs($filename.".pdf")) {
		echo $pdf->getError();
	} else {
		echo "PDF GENERATED";
	}
}

$result = ob_get_contents();
ob_end_clean();

if (!strstr($result, "PDF GENERATED")){
	@unlink($filename.".html");
	@unlink($filename.".pdf");
	$filename = "error";
	echo $result;
	exit;
}

$preFiles = isset($_POST['pre']) ? explode(',', $_POST['pre']) : [];
$postFiles = isset($_POST['post']) ? explode(',', $_POST['post']) : [];

if (count($preFiles)>0 || count($postFiles)>0){
	rename($filename.".pdf", $filename.".original.pdf");

	foreach ($preFiles as $i => $file){
		$local = "/tmp/".sha1($preFiles[$i]).".pdf";
		file_put_contents($local, file_get_contents($preFiles[$i]));
		$preFiles[$i] = $local;
	}

	foreach ($postFiles as $i => $file){
		$local = "/tmp/".sha1($preFiles[$i]).".pdf";
		file_put_contents($local, file_get_contents($postFiles[$i]));
		$postFiles[$i] = $local;
	}

	$cmd = "gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=".$filename.".pdf ".implode(" ", array_merge($preFiles, [$filename.".original.pdf"], $postFiles));
	exec($cmd, $output);

	file_put_contents(
		"/code/var/logs/gs-output.log",
		$cmd." ".implode("\n", $output)."\n\n",
		FILE_APPEND | LOCK_EX
	);
	unlink($filename.".original.pdf");
	foreach (array_merge($preFiles, $postFiles) as $file){
		unlink($file);
	}
}

header('Content-Type: application/pdf');
header('Content-Disposition: attachment; filename="'.(isset($_POST['filename']) ? $_POST['filename'] : "pdfmaker-".time()).'.pdf"');
echo file_get_contents($filename.".pdf");

@unlink($filename.".html");
@unlink($filename.".pdf");
