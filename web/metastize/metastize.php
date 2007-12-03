<?php
/*
Plugin Name: Metastize
Plugin URI: http://zevils.com/#
Description: Combination pages, flexo-archives, and search widget.
Author: Matthew Sachs
Version: 1.0
Author URI: http://zevils.com/
*/

define("metastize_version", "1.0.0");

function metastize_widget($args) {
	extract($args);
	
	echo $before_widget;

	printf("%s%s%s", $before_title, "Meta", $after_title);
	echo "<ul>";
	wp_list_pages('title_li=&include=6,32');

	if(is_day() || is_month() || is_year()) {
		$class = 'current_page_item';
	} else {
		$class = 'page_item';
	}
	printf('<li class="%s">', $class);
	echo '<a href="" id="flexo-archives-header">Archives</a> <ul id="flexo-archives">';
	flexo_widget_archives(array());
	echo '</ul></li>';
	
	wp_meta();

	echo '<li>';
	include(TEMPLATEPATH . '/searchform.php');
	echo "</li></ul>$after_widget";
}

function metastize_init() {
	if(!function_exists('register_sidebar_widget')) return;
	register_sidebar_widget('Metastize', 'metastize_widget');
}

add_action('widgets_init', 'metastize_init');

?>
