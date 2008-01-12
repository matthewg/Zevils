<?php

if(!defined("PHORUM")) return;

//{HOOK tpl_display_metoo_flags MESSAGE}
function phorum_mod_metoo_display_flags($data) {
    global $PHORUM;
    
    if(!isset($PHORUM["mod_metoo"]) || !is_array($PHORUM["mod_metoo"])) {
        return $data;
    }

    $flags = $PHORUM["mod_metoo"]["flags"];
    if(!isset($flags) || !count($flags)) {
        return $data;;
    }

    $message = $data[0];
    $message_id = $message["message_id"];
    $message_flags = array();
    if(isset($message["mod_metoo"])) {
        $message_flags = $message["mod_metoo"];
    }

    $user = $PHORUM["user"];
    $user_message_flags = array();
    if(isset($user["mod_metoo"]) && isset($user["mod_metoo"][$message_id])) {
        $user_message_flags = $user["mod_metoo"][$message_id];
    }

    echo('<div class="metoo_flags" id="metoo_post_flags_' . $message_id . '>');
    foreach($flags as $flag_group) {
        echo('<div class="metoo_flag_group">');
        foreach($flag_group as $flag) {
            $flag_value = 0;
            if(isset($message_flags[$flag])) {
                $flag_value = $message_flags[$flag];
            }
            
            if($user_message_flags[$flag]) {
                echo('<div class="metoo_flag metoo_flag_selected">');
            } else {
                echo('<div class="metoo_flag metoo_flag_unselected">');
            }

            echo('<div class="metoo_flag_name">' . $flag . '</div>');
            echo(' <div class="metoo_flag_value">(' . $flag_value . ')</div>');
            
            echo('</div>');
        }
        echo('</div>');
    }
    echo('</div>');
}

function phorum_mod_metoo_javascript_register($data) {
    $data[] = array(
        "module" => "metoo",
        "source" => "file(mods/metoo/jquery.js)"
    );

    $data[] = array(
        "module" => "metoo",
        "source" => "file(mods/metoo/metoo_activate_flags.js)"
    );

    return $data;
}

function phorum_mod_metoo_set_flags($data) {
    global $PHORUM;
    $user = $PHORUM["user"];
    if(!isset($user["user_id"])) return;

    $message_id = $data["message_id"];
    if(!$message_id) {
        return;
    }
    
    $user_data = array();
    if(isset($user["mod_metoo"])) {
        $user_data = $user["mod_metoo"];
    }
    $user_message_data = array();
    if(isset($user_data[$message_id])) {
        $user_message_data = $user_data[$message_id];
    }

    $message = phorum_db_get_message($message_id);
    $meta = $message["meta"];
    if(!isset($meta["mod_metoo"]) || !is_array($meta["mod_metoo"])) {
        $meta["mod_metoo"] = array();
    }
    $message_data = $meta["mod_metoo"];
    
    foreach($data["add_flags"] as $add_flag) {
        $metoo_message_data[$add_flag] = true;
        if(isset($message_data[$add_flag])) {
            $message_data[$add_flag] += 1;
        } else {
            $message_data[$add_flag] = 1;
        }
    }
    foreach($data["remove_flags"] as $remove_flag) {
        unset($metoo_message_data[$remove_flag]);
        $message_data[$remove_flag] -= 1;
        if($message_data[$remove_flag] == 0) {
            unset($message_data[$remove_flag]);
        }
    }
    $user_data[$message_id] = $user_message_data;
    
    $userdata = array(
        "user_id" => $user_id,
        "mod_metoo" => $user_data
    );
    phorum_api_user_save($userdata);
    
    phorum_db_update_message($message_id, array("meta" => $meta));
}

?>