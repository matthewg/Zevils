<?php

if(!defined("PHORUM")) return;

require_once("./include/api/custom_profile_fields.php");

function phorum_mod_metoo_default_flags() {
    return array(array("Interesting"),
                 array("Informative"),
                 array("Entertaining"),
                 array("Agree", "Disagree"),
                 array("Good", "Evil"));
}

function phorum_mod_metoo_common($data) {
    global $PHORUM;

    if(phorum_page == 'metoo_ajax') return;

    if(empty($PHORUM["mod_metoo"]["mod_metoo_installed"])) {
        $field = phorum_api_custom_profile_field_byname("mod_metoo");
        if(!empty($field['deleted'])) {
            phorum_api_custom_profile_field_restore($field['id']);
            $id = $field['id'];
        } elseif(!empty($field)) {
            $id = $field['id'];
        } else {
            $id = NULL;
        }

        phorum_api_custom_profile_field_configure(array(
            'id' => $id,
            'name' => 'mod_metoo',
            'length' => 65000,
            'html_disabled' => 0
        ));

        $config = array();
        if(isset($PHORUM["mod_metoo"])) {
            $config = $PHORUM["mod_metoo"];
        }
        if(!isset($config["flags"])) {
            $config["flags"] = phorum_mod_metoo_default_flags();
        }
        phorum_db_update_settings(array("mod_metoo" => $config));
    }
}

//{HOOK tpl_mod_metoo_display_flags MESSAGES}
function phorum_mod_metoo_display_flags($data) {
    global $PHORUM;

    if(!isset($PHORUM["mod_metoo"]) || !is_array($PHORUM["mod_metoo"])) {
        return $data;
    }

    $flags = $PHORUM["mod_metoo"]["flags"];
    if(!isset($flags) || !count($flags)) {
        return $data;
    }

    $message = $data;
    $message_id = $message["message_id"];
    $message_flags = array();
    if(isset($message["meta"]["mod_metoo"])) {
        $message_flags = $message["meta"]["mod_metoo"];
    }
    
    $user = $PHORUM["user"];
    $user_message_flags = array();
    if(isset($user["mod_metoo"]) && isset($user["mod_metoo"][$message_id])) {
        $user_message_flags = $user["mod_metoo"][$message_id];
    }

    echo('<div class="metoo_flags" metoo_message_id="' . $message_id . '">' . "\n");
    
    foreach($flags as $flag_group) {
        echo("\t" . '<span class="metoo_flag_group">' . "\n");
        foreach($flag_group as $flag) {
            $flag_value = 0;
            if(isset($message_flags[$flag])) {
                $flag_value = $message_flags[$flag];
            }

            echo("\t\t");
            if($user_message_flags[$flag]) {
                echo('<span class="metoo_flag metoo_flag_selected">');
            } else {
                echo('<span class="metoo_flag metoo_flag_unselected">');
            }
            echo("\n");

            echo('<span class="metoo_flag_name">' . $flag . '</span>');
            echo(' (<span class="metoo_flag_value">' . $flag_value . '</span>)');
            
            echo("\n\t\t" . '</span>' . "\n");
        }
        echo("\t" . '</span>' . "\n");
    }
    echo('</div>' . "\n");
}

function phorum_mod_metoo_javascript_register($data) {
    global $PHORUM;
    if(!$PHORUM["user"]["user_id"]) return;    

    $data[] = array(
        "module" => "metoo",
        "source" => "file(mods/metoo/jquery.js)"
    );

    $data[] = array(
        "module" => "metoo",
        "source" => "file(mods/metoo/metoo_activate_flags.php)"
    );

    return $data;
}

function phorum_mod_metoo_set_flags($data) {
    global $PHORUM;
    if(!$PHORUM["user"]["user_id"]) return;
    if(!phorum_api_user_session_restore(PHORUM_FORUM_SESSION)) return;
    $user = $PHORUM["user"];

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
        $user_message_data[$add_flag] = true;
        if(isset($message_data[$add_flag])) {
            $message_data[$add_flag] += 1;
        } else {
            $message_data[$add_flag] = 1;
        }
    }
    foreach($data["remove_flags"] as $remove_flag) {
        unset($user_message_data[$remove_flag]);
        $message_data[$remove_flag] -= 1;
        if($message_data[$remove_flag] <= 0) {
            unset($message_data[$remove_flag]);
        }
    }
    $user_data[$message_id] = $user_message_data;
    $meta["mod_metoo"] = $message_data;

    $user["mod_metoo"] = $user_data;
    phorum_api_user_save($user);
//    phorum_api_user_save(array(
//        "user_id" => $user_id,
//        "mod_metoo" => $user_data
//    ));
    
    phorum_db_update_message($message_id, array("meta" => $meta));
}

?>