package htmlutils;

# Big sack of crap that I used before biting the bullet and using
# CGI.pm instead.  Should be phased out.

use Exporter   ();
use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA         = qw(Exporter);
@EXPORT      = qw(&formSelect &formCheckbox &htmlParams &htmlImage &htmlLink &formName &formPasswd);

sub formSelect
{
        my($name,$default,$c)=@_;

        my $options,$defaultDesc;
        while(my ($id,@rest)=$c->fetchrow()) {
                if($default eq $id) {
                        $defaultDesc=join(" ",@rest);
                } else {
                        $options.="\n<OPTION value=$id>".join(" ",@rest) unless $default eq $id;
                }
        }
        return "<SELECT name=$name><OPTION value=$default>$defaultDesc $options</SELECT>\n";
}

sub urlEncode
{
        $_=$_[0];
        s/ /+/g;
        return $_;
}
                          


sub urlParams
{
        my(%h)=@_;
        return join(";", map( $_."=".urlEncode($h{$_}), keys %h ) );
}


sub formCheckbox
{
        my($value,%h)=@_;
        $_=$value;
        my $checked="CHECKED" if /on/i or /1/;
        return "<INPUT TYPE=checkbox ".htmlParams(%h)." $checked>\n";
}

sub htmlParams
{
        my(%h)=@_;
        return join(" ",map(uc($_)."=\"$h{$_}\"", keys %h));
}

sub formName
{
        my(%h)=@_;
        $h{name}||="anonymous";
        return "<INPUT TYPE=name ".htmlParams(%h).">\n";
}                     


sub formPasswd
{
        my(%h)=@_;
        $h{name}||="anonymous";
        return "<INPUT TYPE=password ".htmlParams(%h).">\n";
}

sub htmlImage
{
        my(%h)=@_;
        return "<IMG ".htmlParams(%h).">";
}

sub htmlLink
{
        my($linktext,%h)=@_;
        return "<A ".htmlParams(%h).">$linktext</A>\n";
}                         
