#!/usr/bin/perl


my ($op,$data)=("/","");

$_=$ENV{SCRIPT_NAME};

if(/\/(.*?)\/(.*).shtml/) {
        ($op,$data)=($1,$2);
} elsif(/\/(.*).shtml/) {
        $op=$1;
} 

$data=~s/_F//;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime();
$mon++;
my $l=sprintf("log%02d%02d%02d.txt",$mon,$mday,$year);                

if (open(FHandle, ">>/home/slash/logs/".$l)){
      print (FHandle $ENV{REMOTE_ADDR}."\t".localtime(time)."\t".
      $ENV{HTTP_USER_AGENT}."\t".$op."\t".$data."\n");
}  
close FHandle;
