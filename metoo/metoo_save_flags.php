<?php

header("Content-type: text/plan");
include_once("./common.php");
include_once("./mods/metoo/metoo.php");

$message_id = $_POST["messageID"];
if(!($message_id > 0)) {
    header("Status: 500 Internal error");
    echo("Message ID not set\n");
    exit();
}

$add_flags = split(",", $_POST["addFlags"]);
$remove_flags = split(",", $_POST["removeFlags"]);

phorum_mod_metoo_set_flags(array(
    "message_id" => $message_id,
    "add_flags" => $add_flags,
    "remove_flags" => $remove_flags
));

?>
