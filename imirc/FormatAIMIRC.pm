package HTML::FormatAIMIRC;

use HTML::FormatText;
@ISA = qw(HTML::FormatText);

#Since we want to be able to trap all tags, we define a custom AUTOLOAD and format
sub AUTOLOAD {
	my $sub = $AUTOLOAD;
	my $elem = shift;
	my $attr;
	my $output;

	$sub =~ s/^.+::(.+)_(start|end)$/$1/ or return 0;

	if($2 eq "end") {
		if($elem->{_original_html} =~ m!/$sub!) {
			#Ooh, now this is a fun hack.
			#It's not smart enough to know whether to make unknown tags containers.
			#So, if someone grins at you: <g> you'll still get a g_end call.
			#Which normally would do produce <g></g>
			#
			#But what about those times when you really want the closing tags?
			#Well we store the original HTML in the FormatAIMIRC object and use that to check.

			push @{$elem->{output}}, "</$sub>";
		}
	} else {
		#Get all attributes (<tag attr=val attr2=val2>)
		foreach $attr(keys %{$_[0]}) {
			next if $attr =~ /^_/;
			$output .= " $attr=$_[0]->{$attr}";
		}
		$output ||= "";
		push @{$elem->{output}}, "<$sub$output>";
	}
	return $elem;
}

sub format {
	my($self, $html) = @_;
	$self->begin();
	$html->traverse(sub {
		my($node, $start, $depth) = @_;

		#The check for ^[a-z] stops an odd bug.
		#<What's> would crash aimirc without it.
		#It would use What's as the tag name.
		#And that's not a valid Perl identifier...
		#So it would die on $self->$func ($func is constructed from $tag)
		#
		#But we still have to get the text from outside the object.

		if (ref $node and $node->tag =~ /[^a-z]/i) {
			return if not $start;

			my $tag = $node->tag;

			#BUG!!
			#<Hi Matt.><Hi Jayson.> -> <Hi Matt.><Hi Matt.>

			$self->{_original_html} =~ /(<.*?$tag.*?>)/i;
			$self->textflow($1);
		} elsif(ref $node) {
			my $tag = $node->tag;
			print "tag=\"$tag\", start=\"$start\"\n";
			my $func = $tag . '_' . ($start ? "start" : "end");
			return $self->$func($node);
		} else {  
			$self->textflow($node);
		}
		1;
	});
	$self->end();
	join('', @{$self->{output}});
}

sub hr_start {
	my $self = shift;
	$self->vspace(1);
	$self->out("=" x 30);
	$self->vspace(1);
}

sub img_start {
	my($self, $elem) = @_;

	$self->out("[IMAGE " . ($elem->attr('alt') || $elem->attr('src')) . "]");
}

#We can't get at the HREF inside of sub out, so set it here.
sub a_start {
	my ($self, $elem, $href, $text) = @_;

	$self->{anchor}++;
	push @{$self->{output}}, " " x $self->{hspace};

	$href = $elem->attr('href');
	$text = gettext($elem->{_content});
	push @{$self->{output}}, "{" unless $href eq $text;
	$self->{hspace} = 0;
	1;
}

sub a_end {
	my($self, $elem, $href, $text) = @_;

	$self->{anchor}--;
	$href = $elem->attr('href');
	$text = gettext($elem->{_content});
	push @{$self->{output}}, "} {" . $elem->attr('href') . "}" unless $href eq $text;
}

#Mostly ripped straight from HTML::FormatText, with a few critical additions.
sub out {
	my($self, $text) = @_;
	my($bold, $italic, $underline, $color) = (chr(2), chr(oct(26)), chr(oct(37)), chr(3));
			
	if ($text =~ /^\s*$/) { 
		$self->{hspace} = 1;
		return;
	}
	
	#open(TMP, ">>/tmp/aimirc.html.txt");
	#print TMP "out $text:\n" . Data::Dumper::Dumper($self);
	#close TMP;

	#Translate HTML formatting to IRC formatting
	$text = "$bold$text$bold" if $self->{bold};
	$text = "$italic$text$italic" if $self->{italic};
	$text = "$underline$text$underline" if $self->{underline};
	#$text = "{$text" if $self->{anchstart} and $self->{anchor};
	#$text = "$text} {$self->{href}}" if $self->{anchstart} and not $self->{anchor}; #So we can see link addresses...
	
	if (defined $self->{vspace}) {
		if ($self->{out}) {
			$self->nl while $self->{vspace}-- >= 0;
		}
		$self->goto_lm;
		$self->{vspace} = undef;
		$self->{hspace} = 0;
	}

	if ($self->{hspace}) {
		if ($self->{curpos} + length($text) > $self->{rm}) {
			# word will not fit on line; do a line break
			$self->nl;
			$self->goto_lm;
		} else {
			# word fits on line; use a space
			$self->collect(' ');
			++$self->{curpos};
		}
		$self->{hspace} = 0;
	}

	$self->collect($text);
	my $pos = $self->{curpos} += length $text;
	$self->{maxpos} = $pos if $self->{maxpos} < $pos;

	$self->{'out'}++;
}
	
sub gettext {
	my($elem, $telem) = shift;

	$telem = $elem;
	$telem = $telem->[0] while ref $telem eq "ARRAY";
	return $telem;
}

1;
