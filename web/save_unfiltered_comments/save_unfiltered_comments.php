<?php
/*
Plugin Name: Save Unfiltered Comments
Plugin URI: http://zevils.com/#
Description: Save the unfiltered comment text.
Author: Matthew Sachs
Version: 1.0
Author URI: http://zevils.com/
*/

define("save_unfiltered_comments_db_version", 1);
define("save_unfiltered_comments_version", "1.0.0");
if(isset($table_prefix)) {
	define("save_unfiltered_comments_table", $table_prefix . "save_unfiltered_comments_table");
} else {
	define("save_unfiltered_comments_table", "save_unfiltered_comments_table");
}

function save_unfiltered_comments_install() {
	global $wpdb;
	
	add_option('save_unfiltered_comments_opt', array(), 
	$suc_opt = get_option('save_unfiltered_comments_opt');
	$cur_DB = (int)$suc_opt['DB_version'];
	if($cur_DB < save_unfiltered_comments_db_version) {
		$success = true;
		if($cur_DB == 0) {
			$query = sprintf("CREATE TABLE IF NOT EXISTS '%s' (comment_ID bigint(20) unsigned not null primary key, unfiltered_content text not null)", save_unfiltered_comments_table);
			$wpdb->query($query);
			if(mysql_error()) {
				$success = false;
			} else {
				$cur_DB = save_unfiltered_comments_DB_version;
			}
		}
		if($success) {
			$suc_opt['DB_version'] = $cur_DB;
			update_option('save_unfiltered_comments_opt', $suc_opt);
		}
	}
}

function save_unfiltered_comments_stash_content($content) {
	global $save_unfiltered_comments_text;
	$save_unfiltered_comments_text = $content;
	return $content;
}

function save_unfiltered_comments_store_data($commentID) {
	global $wpdb, $save_unfiltered_comments_text;
	if(isset($save_unfiltered_comments_text)) {
		@$wpdb->query(sprintf("INSERT INTO %s (comment_ID, unfiltered_content) VALUES (%s, %s)",
								save_unfiltered_comments_table,
								$commentID,
								$wpdb->escape($save_unfiltered_comments_text)));
		unset($save_unfiltered_comments_text);
	}
}

function save_unfiltered_comments_get_text($commentID) {
	global $wpdb;
	return $wpdb->get_var(sprintf("SELECT unfiltered_content FROM %s WHERE comment_id = %lu",
									save_unfiltered_comments_table,
									$commentID));
}

add_action('activate_plugindir/save_unfiltered_comments.php', 'save_unfiltered_comments_install');
add_filter('pre_comment_content', 'save_unfiltered_comments_stash_content', 1, 1);
add_action('comment_post', 'save_unfiltered_comments_store_data', 100, 1);

?>