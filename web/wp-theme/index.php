<?php get_header(); ?>

	<div id="content" class="narrowcolumn">

	<?php if (have_posts()) : ?>

		<?php while (have_posts()) : the_post(); ?>

			<div class="post" id="post-<?php the_ID(); ?>">
				<h2><a href="<?php the_permalink() ?>" rel="bookmark" title="Permanent Link to <?php the_title_attribute(); ?>"><?php the_title(); ?></a></h2>

				<div class="entry">
					<?php the_content(''); ?>
				</div>

				<p class="postmetadata">
<?php 
      $morewords = "XXX more words; ";
      if(comments_open()) {
        comments_popup_link($morewords . '0 comments', $morewords . '1 comment', $morewords . '% comments');
        echo " &ndash; ";
      }
?>
<a href="<?php the_permalink(); ?>" title="Permanent Link to <?php the_title_attribute(); ?>">&infin;</a> &ndash; 
<? the_date(); echo " "; the_time(); ?> &ndash; 
[<?php 
       echo "<span class=\"post_categories\">"; the_category(', '); echo "</span>";
       if(the_tags(', ', ', ', '')) {
         echo ", ";
         the_tags('', ', ', '');
       }
?>]</p>
			</div>

                         <?
                           global $wp_query;
                           if($wp_query->current_post + 1 < $wp_query->post_count) echo "<hr>";
                           endwhile;
                         ?>

		<div class="navigation">
			<div class="alignleft"><?php next_posts_link('&laquo; Older Entries') ?></div>
			<div class="alignright"><?php previous_posts_link('Newer Entries &raquo;') ?></div>
		</div>

	<?php else : ?>

		<h2 class="center">Not Found</h2>
		<p class="center">Sorry, but you are looking for something that isn't here.</p>
		<?php include (TEMPLATEPATH . "/searchform.php"); ?>

	<?php endif; ?>

	</div>

<?php get_sidebar(); ?>

<?php get_footer(); ?>
