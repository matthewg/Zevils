#!/usr/bin/perl
use CPAN;
use Config qw(config_sh);
use File::Path;
use File::Copy;
use Cwd;

@docs = qw(CONTRIBUTORS COPYING EXAMPLE HISTORY INSTALL
		README RELNOTES mp3gui.1.html mp3id3.1.html mp3index.1.html
		mp3info.1.html);
@sampledocs = qw(samples/datfile samples/mp3format);
@manpages = qw(mp3gui.1 mp3id3.1 mp3index.1 mp3info.1);
@cgiscripts = qw(mp3play.cgi);
@programs = qw(mp3gui mp3id3 mp3index mp3info);

print "Welcome to the mp3tools installer.\n";
$initdir = cwd;
die "This installer must be run from the directory you extracted the mp3tools archive into!\n" unless -f "$initdir/README";

$havemodules = 0;
$deftkmodule = 1;
while(!$havemodules) {
	$tkmodule = 0;
	print "mp3tools requires the File::KGlob and MPEG::MP3Info modules\n";
	print "mp3gui also requires the Tk module.\n";
	print "Include Tk in list of required modules (say yes if you plan on using mp3gui - default is yes)? ";
	chomp($tkmodule = <STDIN>);
	$tkmodule ||= $deftkmodule;
	$tkmodule = 0 if $tkmodule =~ /^\s*[n0]/i;
	print "Would you like to:\n";
		print "\t[a]bort the installation\n";
		print "\t[c]heck to see if you have these modules installed\n";
		print "\t[l]et the CPAN module download these for you\n";
		print "\t[s]kip installation of these modules\n";
		print "\t(please type the first letter of the option you want)\n";
	chomp ($selection = <STDIN>);
	$selection = lc(substr($selection, 0, 1));
	exit if $selection eq "a";
	if($selection eq "c") {
		$str = "perl -MFile::KGlob -MMPEG::MP3Info ";
		$str .= "-MTk " if $tkmodule;
		$str .= " -e 'exit;'";
		$return = system($str);
		if($return == 0) {
			print "You appear to have the required modules.\n";
			$havemodules = 1;
		} else {
			print "You do not appear to have the required modules.\n";
		}
	} elsif ($selection eq "s") {
		print "Skipping... mp3tools will not work unless File::KGlob and MPEG::MP3Info are installed!\n";
		$havemodules = 1;
	} elsif ($selection eq "l") {
		print "You are going to be asked some questions in a moment.\n";
		print "YMMV, but I was able to just take the defaults.\n";
		print "The only question that you will definately need to give an answer to is\n";
		print "the one where it asks for your preferred CPAN site.  You can select a\n";
		print "CPAN site from the list at http://www.perl.com/CPAN-local/SITES.html\n";
		print "Oh, and you must be online.\n\n";
		for $mod (qw(File::KGlob MPEG::MP3Info)) {
			my $obj = CPAN::Shell->expand('Module', $mod);
			$obj->install;
		}
		(CPAN::Shell->expand('Module', 'Tk'))->install if $tkmodule;
		$havemodules = 1;
	} else {
		print "I do not understand your selection.\n";
	}
}

# install docs (including samples/)
# install mp3play.cgi

$conf = config_sh();
$conf =~ /^installsitebin=(.*)$/m;
$defbin = $1; $defbin =~ s/^'(.*)'/$1/;
$conf =~ /^installman1dir=(.*)$/m;
$defman = $1; $defman =~ s/^'(.*)'/$1/;
$win32 = 0; $mac = 0;
if($^O =~ /Win/i) {
	$defdoc = "c:\\Program Files\\mp3tools";
	$defcgi = "c:\\Program Files\\Apache Group\\Apache\\htdocs\\cgi-bin";
	$defman = "none";
	$pathsep = "\\";
	$win32 = 1;
} elsif($^O =~ /Mac/i) {
	$defdoc = "Macintosh HD:mp3tools";
	$defcgi = "none";
	$defman = "none";
	$pathsep = ":";
	$mac = 1;
} else {
	$defdoc = "/usr/share/doc/mp3tools";
	$defcgi = "/var/htdocs/cgi-bin";
	$pathsep = "/";
}

umask 0002 unless $mac or $win32;

print "Okay, I need to ask you some more questions.\n";
print "To take the defaults, just hit enter.\n";
print "If you don't want to install any of the things I ask about, say 'none'\n";
while (1 == 1) {
	print "Where would you like the programs to go [$defbin]? ";
	chomp ($bin = <STDIN>);
	$bin ||= $defbin;
	last if lc($bin) eq "none";
	unless (-d $bin) {
		print "Warning! $bin is not a valid directory!\n";
		print "Would you like me to create it? ";
		chomp($docreate = <STDIN>);
		if($docreate and $docreate !~ /^\s*n/i) {
			mkpath($bin, false, 0755);
			last;
		}
	} else { last; }
}

while (1 == 1) {
	print "Where would you like the manual pages to go [$defman]? ";
	chomp ($man = <STDIN>);
	$man ||= $defman;
	last if lc($man) eq "none";
	unless (-d $man) {
		print "Warning! $man is not a valid directory!\n";
		print "Would you like me to create it? ";
		chomp($docreate = <STDIN>);
		if($docreate and $docreate !~ /^\s*n/i) {
			mkpath($man, false, 0755);
			last;
		}
	} else { last; }
}

while (1 == 1) {
	print "Where would you like the documentation to go [$defdoc]? ";
	chomp ($doc = <STDIN>);
	$doc ||= $defdoc;
	last if lc($doc) eq "none";
	unless (-d $doc) {
		print "Warning! $doc is not a valid directory!\n";
		print "Would you like me to create it? ";
		chomp($docreate = <STDIN>);
		if($docreate and $docreate !~ /^\s*n/i) {
			mkpath($doc, false, 0755);
			last;
		}
	} else { last; }
}

while (1 == 1) {
	print "Where would you like the CGI scripts to go [$defcgi]? ";
	chomp ($cgi = <STDIN>);
	$cgi ||= $defcgi;
	last if lc($cgi) eq "none";
	unless (-d $cgi) {
		print "Warning! $cgi is not a valid directory!\n";
		print "Would you like me to create it? ";
		chomp($docreate = <STDIN>);
		if($docreate and $docreate !~ /^\s*n/i) {
			mkpath($cgi, false, 0755);
			last;
		}
	} else { last; }
}

# do install $bin, $man, $doc, $cgi
# unless they =~ /^\s*none\s*$/i

unless($bin =~ /^\s*none\s*$/i) {
	print "Installing programs...\n";
	chdir $bin;
	foreach $program (@programs) {
		print "Installing $program in $bin\n";
		copy("$initdir$pathsep$program", $program);
		chmod 0755, $program;
	}
}

unless($doc =~ /^\s*none\s*$/i) {
	print "Installing documentation...\n";
	chdir $doc;
	mkdir "samples", 0755;
	foreach $docfile (@docs) {
		print "Installing $docfile in $doc\n";
		copy("$initdir$pathsep$docfile", $docfile);
	}
	chdir "samples";
	foreach $docfile (@sampledocs) {
		print "Installing $docfile in $docsampdir\n";
		copy("$initdir$pathsep$docfile", $docfile);
	}
}

unless($man =~ /^\s*none\s*$/i) {
	print "Installing manual pages...\n";
	chdir $man;
	foreach $manpage (@manpages) {
		print "Installing $manpage in $man\n";
		copy("$initdir$pathsep$manpage", $manpage);
	}
}

unless($cgi =~ /^\s*none\s*$/i) {
	print "Installing CGI scripts...\n";
	chdir $cgi;
	foreach $cgiscript (@cgiscripts) {
		print "Installing $cgiscript in $cgi\n";
		copy("$initdir$pathsep$cgiscript", $cgiscript);
	}
}
