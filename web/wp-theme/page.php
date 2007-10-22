<?php get_header(); ?>

	<div id="content" class="narrowcolumn">

		<?php if (have_posts()) : while (have_posts()) : the_post(); ?>
		<div class="post" id="post-<?php the_ID(); ?>">
		<h1 id="post-title"><?php the_title(); ?></h1>
		<?
			global $post;
			$parent_id = $post->post_parent;
			if($parent_id > 0) {
				$parent = get_post($parent_id);
				$parent_title = $parent->post_title;
				$parent_uri = get_page_uri($parent_id);
				printf('<p id="page-parent">[<a href="/%s/">&laquo; Return to %s</a>]</p>', $parent_uri, $parent_title);
			}
		?>
			<div class="entry">
				<?php the_content('<p class="serif">Read the rest of this page &raquo;</p>'); ?>

				<?php wp_link_pages(array('before' => '<p><strong>Pages:</strong> ', 'after' => '</p>', 'next_or_number' => 'number')); ?>

			</div>
		</div>
		<?php endwhile; endif; ?>
	<?php edit_post_link('Edit this entry.', '<p>', '</p>'); ?>
	</div>

<?php get_sidebar(); ?>

<?php get_footer(); ?>