<?php // Do not delete these lines
	if ('comments.php' == basename($_SERVER['SCRIPT_FILENAME']))
		die ('Please do not load this page directly. Thanks!');

	if (!empty($post->post_password)) { // if there's a password
		if ($_COOKIE['wp-postpass_' . COOKIEHASH] != $post->post_password) {  // and it doesn't match the cookie
			?>

			<p class="nocomments">This post is password protected. Enter the password to view comments.</p>

			<?php
			return;
		}
	}

	/* This variable is for alternating comment background */
	$oddcomment = 'class="alt" ';
?>

<?php if ($comments) : ?>
	<h3 id="comments"><?php comments_number('No Responses', 'One Response', '% Responses' );?> to &#8220;<?php the_title(); ?>&#8221;</h3>

	<ol class="commentlist">

	<?php foreach ($comments as $comment) : ?>

		<li <?php echo $oddcomment; ?>id="comment-<?php comment_ID() ?>">
			<cite><?php comment_author_link() ?></cite> says:
			<?php if ($comment->comment_approved == '0') : ?>
			<em>Your comment is awaiting moderation.</em>
			<?php endif; ?>
			<br />

			<small class="commentmetadata"><a href="#comment-<?php comment_ID() ?>" title=""><?php comment_date('F jS, Y') ?> at <?php comment_time() ?></a> <?php edit_comment_link('edit','&nbsp;&nbsp;',''); ?></small>

			<?php comment_text() ?>

		</li>

	<?php
		/* Changes every other comment to a different class */
		$oddcomment = ( empty( $oddcomment ) ) ? 'class="alt" ' : '';
	?>

	<?php endforeach; /* end for each comment */ ?>

	</ol>

 <?php else : // this is displayed if there are no comments so far ?>

	<?php if ('open' == $post->comment_status) : ?>
	 <?php else : // comments are closed ?>
		<!-- If comments are closed. -->
		<p class="nocomments">Comments are closed.</p>

	<?php endif; ?>
<?php endif; ?>


<?php if ('open' == $post->comment_status) : ?>

<h3 id="respond">Leave a Reply</h3>

<?php if ( get_option('comment_registration') && !$user_ID ) : ?>
<p>You must be <a href="<?php echo get_option('siteurl'); ?>/wp-login.php?redirect_to=<?php echo urlencode(get_permalink()); ?>">logged in</a> to post a comment.</p>
<?php else : ?>

<div id="markdown_help">
<p>Use <a href="http://daringfireball.net/projects/markdown/syntax">Markdown</a>, a wiki-like syntax, to write your comment.  Basic HTML tags will also work.  For source code with syntax hilighting and line numbers, wrap the code in <tt>&lt;pre lang="<em>language</em>" <i>lineno="1"</i>&gt;...&lt;/pre&gt;</tt></p>
<p id="markdown_syntax_disclosure"><a href="">Show Markdown help.</a></p>
<div id="markdown_syntax">
<p>Write Markdown text as if you were writing a plain-text email.  Some examples:</p>
<?php function markdown_example($text) {
	printf("<table><tr><td><pre>%s</pre></td><td>%s</td></tr></table>", $text, Smartypants(Markdown($text)));
} ?>
<ul>
<li>Paragraphs: Blank lines between blocks of text</li>
<li>Links: <tt>[link text](http://url.example.com/)</tt> or <tt>[link text][ref]</tt></li>
<li>Bold and italic: <tt>*Single*</tt> and <tt>**double**</tt> asterisks respectively</li>
<li>Lists: List items start with <tt>*</tt> or <tt>1.</tt></li>
<li>Quoting: Like email, quoted lines start with <tt>&gt;</tt></li>
</ul>
<?php markdown_example("The rise of the [hamburger](http://hamburger.example.com/)
as a form of *currency* can be **attributed** to several
aspects of [Akkadian][akad] [civilization][civ].

   [akad]: http://icanhasgilgamesh.example.com/
   [civ]: http://uruk.example.com/

Yes, the most delicious hamburger of all is not brown, but
green. The green of money. Denominations of hamburger
(and current value in USD:)

* 1/4-pounder (\$3.79)
* Cuneiform, or \"Cuney\" (\$8.00)

Problems with the currency:

1. Deflation due to hunger
2. Fraud (soy fillers)
3. Hamburgers not invented yet

As Dr. Tabi said:
> Wallets became foetid and repulsive.
> This was quite the boon for the influential
> Guild of Wallet-Washers.
"); ?>
<ul>
</div>
</div>

<form action="<?php echo get_option('siteurl'); ?>/wp-comments-post.php" method="post" id="commentform">

<?php if ( $user_ID ) : ?>

<p>Logged in as <a href="<?php echo get_option('siteurl'); ?>/wp-admin/profile.php"><?php echo $user_identity; ?></a>. <a href="<?php echo get_option('siteurl'); ?>/wp-login.php?action=logout" title="Log out of this account">Logout &raquo;</a></p>

<?php else : ?>

<p><input type="text" name="author" id="author" value="<?php echo $comment_author; ?>" size="22" tabindex="1" />
<label for="author"><small>Name <?php if ($req) echo "(required)"; ?></small></label></p>

<p><input type="text" name="email" id="email" value="<?php echo $comment_author_email; ?>" size="22" tabindex="2" />
<label for="email"><small>Mail (will not be published) <?php if ($req) echo "(required)"; ?></small></label></p>

<p><input type="text" name="url" id="url" value="<?php echo $comment_author_url; ?>" size="22" tabindex="3" />
<label for="url"><small>Website</small></label></p>

<?php endif; ?>

<?php /*display_cryptographp();*/ ?>

<p><textarea name="comment" id="comment" cols="100%" rows="10" tabindex="4"></textarea></p>

<div id="comment_buttons">
<p><input name="submit" type="submit" id="submit" tabindex="5" value="Submit Comment" />
<input type="hidden" name="comment_post_ID" value="<?php echo $id; ?>" />
</p>
<?php do_action('comment_form', $post->ID); ?>
</div>
</form>
<?php show_manual_subscription_form(); ?>

<?php endif; // If registration required and not logged in ?>

<?php endif; // if you delete this the sky will fall on your head ?>
