<?php get_header(); ?>

	<div id="content" class="narrowcolumn">

	<?php if (have_posts()) : ?>

		<?php while (have_posts()) : the_post(); ?>

			<div class="post" id="post-<?php the_ID(); ?>">
				<? 
                                  if(!((count(get_the_category()) == 1) && in_category(6))) {
                                ?>
                                  <h1 class="index-post-title"><a href="<?php the_permalink() ?>" rel="bookmark" title="Permanent Link to <?php the_title_attribute(); ?>"><?php the_title(); ?></a></h1>
                                <? } ?>

				<div class="entry">
					<?php the_content(''); ?>
				</div>

				<p class="postmetadata"><? zevish_post_metadata(); ?></p>
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
