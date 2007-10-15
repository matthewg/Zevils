<?php
/*
Plugin Name: AJAX Category Filter
Plugin URI: http://zevils.com/#
Description: Modify the standard category list to let users show and hide individual categories on the front page and provides a link to a custom RSS feed containing only posts from the selected categories.
Author: Matthew Sachs
Version: 1.0
Author URI: http://zevils.com/
*/

define("ajax_category_filter_version", "1.0.0");

function ajax_category_filter_do() {
	if(is_attachment() || is_feed() || is_category() || is_page() || is_single())
		return;
	
	/*
	Find #categories-1 > ul or .categories > ul
	li class="cat-item cat-item-N"
	add checkbox; get checked status from cookie
	hide posts: get next N posts from categories to show
	show posts: get posts from the category, insert them at the proper point
	add link to custom RSS feed
	*/
	
	echo $before_widget;

	printf("<h2>%s%s%s</h2>", $before_title, "Categories", $after_title);
	echo '<ul class="category_list">';

	$categories = get_categories(array('hide_empty' => 1));
	ajax_category_filter_show_categories($categories);

	echo "</ul>$after_widget";
}

add_action('wp_footer', 'ajax_category_filter_do');

?>