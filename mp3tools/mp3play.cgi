#!/usr/bin/perl

use CGI qw(:standard);
my $file = param("url");

$file =~ s/ /%20/g;
$file =~ s/&/%26/g;
$file =~ s/'/%27/g;
$file =~ s/\(/%28/g;
$file =~ s/\)/%29/g;
$file =~ s/#/%23/g;
$file =~ s/\[/%5b/g;
$file =~ s/]/%5d/g;
$file =~ s/-/%2d/g;

print "Content-Type: audio/mpeg-url\n\n$file\n";

