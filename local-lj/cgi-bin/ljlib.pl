#!/usr/bin/perl
#
# <LJDEP>
# lib: DBI::, Digest::MD5, URI::URL
# lib: cgi-bin/ljconfig.pl, cgi-bin/ljlang.pl, cgi-bin/ljpoll.pl
# lib: cgi-bin/cleanhtml.pl
# link: htdocs/paidaccounts/index.bml, htdocs/users, htdocs/view/index.bml
# hook: canonicalize_url, name_caps, name_caps_short, post_create
# hook: validate_get_remote
# </LJDEP>

package LJ;

use strict;
use Carp;
use lib "$ENV{'LJHOME'}/cgi-bin";
use DBI;
use DBI::Role;
use DBIx::StateKeeper;
use Digest::MD5 ();
use HTTP::Date ();
use LJ::MemCache;
use Time::Local ();
use Storable ();
use Compress::Zlib ();
use DateTime;
use DateTime::TimeZone;

do "$ENV{'LJHOME'}/cgi-bin/ljconfig.pl";
do "$ENV{'LJHOME'}/cgi-bin/ljdefaults.pl";

require "$ENV{'LJHOME'}/cgi-bin/ljlib-local.pl"
    if -e "$ENV{'LJHOME'}/cgi-bin/ljlib-local.pl";

# if this is a dev server, alias LJ::D to Data::Dumper::Dumper
if ($LJ::IS_DEV_SERVER) {
    eval "use Data::Dumper ();";
    *LJ::D = \&Data::Dumper::Dumper;
}

$LJ::DBIRole = new DBI::Role {
    'timeout' => $LJ::DB_TIMEOUT,
    'sources' => \%LJ::DBINFO,
    'default_db' => "livejournal",
    'time_check' => 60,
    'time_report' => \&dbtime_callback,
};

LJ::MemCache::init();

# $LJ::PROTOCOL_VER is the version of the client-server protocol
# used uniformly by server code which uses the protocol.
$LJ::PROTOCOL_VER = ($LJ::UNICODE ? "1" : "0");

# user.dversion values:
#    0: unclustered  (unsupported)
#    1: clustered, not pics (unsupported)
#    2: clustered
#    3: weekuserusage populated
#    4: userproplite2 clustered, and cldversion on userproplist table
#    5: overrides clustered, and style clustered
$LJ::MAX_DVERSION = 5;

# constants
use constant ENDOFTIME => 2147483647;
$LJ::EndOfTime = 2147483647;  # for string interpolation

# width constants. BMAX_ constants are restrictions on byte width,
# CMAX_ on character width (character means byte unless $LJ::UNICODE,
# in which case it means a UTF-8 character).

use constant BMAX_SUBJECT => 255; # *_SUBJECT for journal events, not comments
use constant CMAX_SUBJECT => 100;
use constant BMAX_COMMENT => 9000;
use constant CMAX_COMMENT => 4300;
use constant BMAX_MEMORY  => 150;
use constant CMAX_MEMORY  => 80;
use constant BMAX_NAME    => 100;
use constant CMAX_NAME    => 50;
use constant BMAX_KEYWORD => 80;
use constant CMAX_KEYWORD => 40;
use constant BMAX_PROP    => 255;   # logprop[2]/talkprop[2]/userproplite (not userprop)
use constant CMAX_PROP    => 100;
use constant BMAX_GRPNAME => 60;
use constant CMAX_GRPNAME => 30;
use constant BMAX_EVENT   => 65535;
use constant CMAX_EVENT   => 65535;
use constant BMAX_INTEREST => 100;
use constant CMAX_INTEREST => 50;

# declare views (calls into ljviews.pl)
@LJ::views = qw(lastn friends calendar day);
%LJ::viewinfo = (
                 "lastn" => {
                     "creator" => \&LJ::S1::create_view_lastn,
                     "des" => "Most Recent Events",
                 },
                 "calendar" => {
                     "creator" => \&LJ::S1::create_view_calendar,
                     "des" => "Calendar",
                 },
                 "day" => {
                     "creator" => \&LJ::S1::create_view_day,
                     "des" => "Day View",
                 },
                 "friends" => {
                     "creator" => \&LJ::S1::create_view_friends,
                     "des" => "Friends View",
                     "owner_props" => ["opt_usesharedpic", "friendspagetitle"],
                 },
                 "friendsfriends" => {
                     "creator" => \&LJ::S1::create_view_friends,
                     "des" => "Friends of Friends View",
                     "styleof" => "friends",
                 },
                 "data" => {
                     "creator" => \&LJ::Feed::create_view,
                     "des" => "Data View (RSS, etc.)",
                     "owner_props" => ["opt_whatemailshow", "no_mail_alias"],
                 },
                 "rss" => {  # this is now provided by the "data" view.
                     "des" => "RSS View (XML)",
                 },
                 "res" => {
                     "des" => "S2-specific resources (stylesheet)",
                 },
                 "info" => {
                     # just a redirect to userinfo.bml for now.
                     # in S2, will be a real view.
                     "des" => "Profile Page",
                 }
                 );

## we want to set this right away, so when we get a HUP signal later
## and our signal handler sets it to true, perl doesn't need to malloc,
## since malloc may not be thread-safe and we could core dump.
## see LJ::clear_caches and LJ::handle_caches
$LJ::CLEAR_CACHES = 0;

## if this library is used in a BML page, we don't want to destroy BML's
## HUP signal handler.
if ($SIG{'HUP'}) {
    my $oldsig = $SIG{'HUP'};
    $SIG{'HUP'} = sub {
        &{$oldsig};
        LJ::clear_caches();
    };
} else {
    $SIG{'HUP'} = \&LJ::clear_caches;
}

# given two db roles, returns true only if the two roles are for sure
# served by different database servers.  this is useful for, say,
# the moveusercluster script:  you wouldn't want to select something
# from one db, copy it into another, and then delete it from the
# source if they were both the same machine.
# <LJFUNC>
# name: LJ::use_diff_db
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub use_diff_db {
    $LJ::DBIRole->use_diff_db(@_);
}

sub get_blob_domainid
{
    my $name = shift;
    my $id = {
        "userpic" => 1,
        "phonepost" => 2,
        "captcha_audio" => 3,
        "captcha_image" => 4,
    }->{$name};
    # FIXME: add hook support, so sites can't define their own
    # general code gets priority on numbers, say, 1-200, so verify
    # hook returns a number 201-255
    return $id if $id;
    die "Unknown blob domain: $name";
}

# <LJFUNC>
# name: LJ::get_dbh
# class: db
# des: Given one or more roles, returns a database handle.
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub get_dbh {
    my $opts = ref $_[0] eq "HASH" ? shift : {};
    # supported options:
    #    'raw':  don't return a DBIx::StateKeeper object

    if ($LJ::DEBUG{'get_dbh'} && $_[0] ne "logs") {
        my $errmsg = "get_dbh(@_) at \n";
        my $i = 0;
        while (my ($p, $f, $l) = caller($i++)) {
            next if $i > 3;
            $errmsg .= "  $p, $f, $l\n";
        }
        warn $errmsg;
    }

    my $mapping;
  ROLE:
    foreach my $role (@_) {
        if (($mapping = $LJ::WRAPPED_DB_ROLE{$role}) && ! $opts->{raw}) {
            return $LJ::REQ_DBIX_KEEPER{$role} if $LJ::REQ_DBIX_KEEPER{$role};
            my ($canl_role, $dbname) = @$mapping;
            my $tracker;
            # DBIx::StateTracker::new will die if it can't connect to the database,
            # so it's wrapper in an eval
            eval {
                $tracker = 
                    $LJ::REQ_DBIX_TRACKER{$canl_role} ||=
                    DBIx::StateTracker->new(sub { $LJ::DBIRole->get_dbh({unshared=>1},
                                                                        $canl_role) });
            };
            if ($tracker) {
                my $keeper = DBIx::StateKeeper->new($tracker, $dbname);
                $LJ::REQ_DBIX_KEEPER{$role} = $keeper;
                return $keeper;
            }
            next ROLE;
        }
        my $db = $LJ::DBIRole->get_dbh($role);
        return $db if $db;
    }
    return undef;
}

# <LJFUNC>
# name: LJ::get_newids
# des: Lookup an old global ID and see what journal it belongs to and its new ID.
# info: Interface to [dbtable[oldids]] table (URL compatability)
# returns: Undef if non-existent or unconverted, or arrayref of [$userid, $newid].
# args: area, oldid
# des-area: The "area" of the id.  Legal values are "L" (log), to lookup an old itemid,
#           or "T" (talk) to lookup an old talkid.
# des-oldid: The old globally-unique id of the item.
# </LJFUNC>
sub get_newids
{
    my $sth;
    my $db = LJ::get_dbh("oldids") || LJ::get_db_reader();
    return $db->selectrow_arrayref("SELECT userid, newid FROM oldids ".
                                   "WHERE area=? AND oldid=?", undef,
                                   $_[0], $_[1]);
}

sub get_groupmask
{
    my ($journal, $remote) = @_;
    return 0 unless $journal && $remote;
    my $jid = want_userid($journal);
    my $fid = want_userid($remote);
    return 0 unless $jid && $fid;
    my $memkey = [$jid,"frgmask:$jid:$fid"];
    my $mask = LJ::MemCache::get($memkey);
    unless (defined $mask) {
        my $dbr = LJ::get_db_reader();
        $mask = $dbr->selectrow_array("SELECT groupmask FROM friends ".
                                      "WHERE userid=? AND friendid=?",
                                      undef, $jid, $fid);
        LJ::MemCache::set($memkey, $mask+0, time()+60*15);
    }
    return $mask+0;  # force it to a numeric scalar
}

#
# returns a row from log2, trying memcache
# accepts $u + $jitemid
# returns hash with: posterid, eventtime, logtime, 
# security, allowmask, journalid, jitemid, anum.

sub get_log2_row
{
    my ($u, $jitemid) = @_;
    my $jid = $u->{'userid'};

    my $memkey = [$jid, "log2:$jid:$jitemid"];
    my ($row, $item);

    $row = LJ::MemCache::get($memkey);

    if ($row) {
        @$item{'posterid', 'eventtime', 'logtime', 'allowmask', 'ditemid'} = unpack("NNNNN", $row);
        $item->{'security'} = ($item->{'allowmask'} == 0 ? 'private' :
                               ($item->{'allowmask'} == 2**31 ? 'public' : 'usemask'));
        $item->{'journalid'} = $jid;
        @$item{'jitemid', 'anum'} = ($item->{'ditemid'} >> 8, $item->{'ditemid'} % 256);
        $item->{'eventtime'} = LJ::mysql_time($item->{'eventtime'}, 1);
        $item->{'logtime'} = LJ::mysql_time($item->{'logtime'}, 1);

        return $item;
    }
    
    my $db = LJ::get_cluster_master($u);
    my $sql = "SELECT posterid, eventtime, logtime, security, allowmask, " .
              "anum FROM log2 WHERE journalid=? AND jitemid=?";

    $item = $db->selectrow_hashref($sql, undef, $jid, $jitemid);
    return undef unless $item;
    $item->{'journalid'} = $jid;
    $item->{'jitemid'} = $jitemid;

    my ($sec, $ditemid, $eventtime, $logtime);
    $sec = $item->{'allowmask'};
    $sec = 0 if $item->{'security'} eq 'private';
    $sec = 2**31 if $item->{'security'} eq 'public';
    $ditemid = $jitemid*256 + $item->{'anum'};
    $eventtime = LJ::mysqldate_to_time($item->{'eventtime'}, 1);
    $logtime = LJ::mysqldate_to_time($item->{'logtime'}, 1);

    $row = pack("NNNNN", $item->{'posterid'}, $eventtime, $logtime, $sec, $ditemid);
    LJ::MemCache::set($memkey, $row);
    
    return $item;
}

# get 2 weeks worth of recent items, in rlogtime order,
# using memcache
# accepts $u or ($jid, $clusterid) + $notafter - max value for rlogtime
# $update is the timeupdate for this user, as far as the caller knows,
# in UNIX time.
# returns hash keyed by $jitemid, fields:
# posterid, eventtime, rlogtime,
# security, allowmask, journalid, jitemid, anum.

sub get_log2_recent_log
{
    my ($u, $cid, $update, $notafter) = @_;
    my $jid = LJ::want_userid($u);
    $cid ||= $u->{'clusterid'} if ref $u;

    my $DATAVER = "3"; # 1 char

    my $memkey = [$jid, "log2lt:$jid"];
    my $lockkey = $memkey->[1];
    my ($rows, $ret);

    $rows = LJ::MemCache::get($memkey);
    $ret = [];

    my $rows_decode = sub {
        return 0
            unless $rows && substr($rows, 0, 1) eq $DATAVER;
        my $tu = unpack("N", substr($rows, 1, 4));

        # if update time we got from upstream is newer than recorded
        # here, this data is unreliable
        return 0 if $update > $tu;

        my $n = (length($rows) - 5 )/20;
        for (my $i=0; $i<$n; $i++) {
            my ($posterid, $eventtime, $rlogtime, $allowmask, $ditemid) =
                unpack("NNNNN", substr($rows, $i*20+5, 20));
            next if $notafter and $rlogtime > $notafter;
            $eventtime = LJ::mysql_time($eventtime, 1);
            my $security = $allowmask == 0 ? 'private' :
                ($allowmask == 2**31 ? 'public' : 'usemask');
            my ($jitemid, $anum) = ($ditemid >> 8, $ditemid % 256);
            my $item = {};
            @$item{'posterid','eventtime','rlogtime','allowmask','ditemid',
                   'security','journalid', 'jitemid', 'anum'} =
                       ($posterid, $eventtime, $rlogtime, $allowmask,
                        $ditemid, $security, $jid, $jitemid, $anum);
            $item->{'ownerid'} = $jid;
            $item->{'itemid'} = $jitemid;
            push @$ret, $item;
        }
        return 1;
    };

    return $ret
        if $rows_decode->();
    $rows = "";

    my $db = LJ::get_cluster_master($cid);
    # if we use slave or didn't get some data, don't store in memcache
    my $dont_store = 0; 
    unless ($db) {
        $db = LJ::get_cluster_reader($cid); 
        $dont_store = 1;
        return undef unless $db;
    }

    my $lock = $db->selectrow_array("SELECT GET_LOCK(?,10)", undef, $lockkey);
    return undef unless $lock;

    $rows = LJ::MemCache::get($memkey);
    if ($rows_decode->()) {
        $db->selectrow_array("SELECT RELEASE_LOCK(?)", undef, $lockkey);
        return $ret;
    }
    $rows = "";

    # get reliable update time from the db
    # TODO: check userprop first
    my $tu;
    my $dbh = LJ::get_db_writer();
    if ($dbh) {
        $tu = $dbh->selectrow_array("SELECT UNIX_TIMESTAMP(timeupdate) " .
                                    "FROM userusage WHERE userid=?",
                                    undef, $jid);
        # if no mistake, treat absence of row as tu==0 (new user)
        $tu = 0 unless $tu || $dbh->err;

        LJ::MemCache::set([$jid, "tu:$jid"], pack("N", $tu), 30*60)
            if defined $tu;
        # TODO: update userprop if necessary
    }
    
    # if we didn't get tu, don't bother to memcache
    $dont_store = 1 unless defined $tu;

    # get reliable log2lt data from the db
    
    my $max_age = $LJ::MAX_FRIENDS_VIEW_AGE || 3600*24*14; # 2 weeks default
    
    my $sql = "SELECT jitemid, posterid, eventtime, rlogtime, " .
        "security, allowmask, anum, replycount FROM log2 " .
        "USE INDEX (rlogtime) WHERE journalid=? AND " .
        "rlogtime <= ($LJ::EndOfTime - UNIX_TIMESTAMP()) + $max_age";
    
    my $sth = $db->prepare($sql);
    $sth->execute($jid);
    my @row;
    push @row, $_ while $_ = $sth->fetchrow_hashref;
    @row = sort { $a->{'rlogtime'} <=> $b->{'rlogtime'} } @row;
    my $itemnum = 0;

    foreach my $item (@row) {
        $item->{'ownerid'} = $item->{'journalid'} = $jid;
        $item->{'itemid'} = $item->{'jitemid'};
        push @$ret, $item;

        my ($sec, $ditemid, $eventtime, $logtime);
        $sec = $item->{'allowmask'};
        $sec = 0 if $item->{'security'} eq 'private';
        $sec = 2**31 if $item->{'security'} eq 'public';
        $ditemid = $item->{'jitemid'}*256 + $item->{'anum'};
        $eventtime = LJ::mysqldate_to_time($item->{'eventtime'}, 1);

        $rows .= pack("NNNNN", 
                      $item->{'posterid'},
                      $eventtime,
                      $item->{'rlogtime'},
                      $sec,
                      $ditemid);

        if ($itemnum++ < 50) {
            LJ::MemCache::add([$jid, "rp:$jid:$item->{'jitemid'}"], $item->{'replycount'});
        }
    }

    $rows = $DATAVER . pack("N", $tu) . $rows;
    LJ::MemCache::set($memkey, $rows) unless $dont_store;

    $db->selectrow_array("SELECT RELEASE_LOCK(?)", undef, $lockkey);
    return $ret;
}

sub get_log2_recent_user
{
    my $opts = shift;
    my $ret = [];

    my $log = LJ::get_log2_recent_log($opts->{'userid'}, $opts->{'clusterid'},
              $opts->{'update'}, $opts->{'notafter'});

    my $left = $opts->{'itemshow'};
    my $notafter = $opts->{'notafter'};
    
    foreach my $item (@$log) {
        last unless $left;
        last if $notafter and $item->{'rlogtime'} > $notafter;
        next unless $opts->{'remote'} || $item->{'security'} eq 'public';
        next if $item->{'security'} eq 'private' 
            and $item->{'journalid'} != $opts->{'remote'}->{'userid'};
        if ($item->{'security'} eq 'usemask') {
            my $permit = ($item->{'journalid'} == $opts->{'remote'}->{'userid'});
            unless ($permit) {
                my $mask = LJ::get_groupmask($item->{'journalid'}, $opts->{'remote'}->{'userid'});
                $permit = $item->{'allowmask'}+0 & $mask+0;
            }
            next unless $permit;
        }
        
        # date conversion
        if ($opts->{'dateformat'} eq "S2") {
            $item->{'alldatepart'} = LJ::alldatepart_s2($item->{'eventtime'});
        } else {
            $item->{'alldatepart'} = LJ::alldatepart_s1($item->{'eventtime'});
        }
        push @$ret, $item;
    }

    return @$ret;
}

# <LJFUNC>
# name: LJ::get_friend_group
# des: Returns friendgroup row(s) for a given user.
# args: uuserid, opt?
# des-uuserid: a userid or u object
# des-opt: a hashref with keys: 'bit' => bit number of group to return
#                               'name' => name of group to return
# returns: hashref; if bit/name are specified, returns hashref with keys being
#                   friendgroup rows, or undef if the group wasn't found.
#
#                   otherwise, returns hashref of all group rows with keys being
#                   group bit numbers and values being row col => val hashrefs
# </LJFUNC>
sub get_friend_group {
    my ($uuid, $opt) = @_;
    my $uid = want_userid($uuid);
    return undef unless $uid;

    # data version number
    my $ver = 1;

    # sanity check bitnum
    delete $opt->{'bit'} if
        $opt->{'bit'} > 31 || $opt->{'bit'} < 0;

    my $fg;
    my $find_grp = sub {

        # $fg format:
        # [ version, [userid, bitnum, name, sortorder, public], [...], ... ]

        my $memver = shift @$fg;
        return undef unless $memver == $ver;

        # bit number was specified
        if ($opt->{'bit'}) {
            foreach (@$fg) {
                return LJ::MemCache::array_to_hash("fgrp", [$memver, @$_])
                    if $_->[1] == $opt->{'bit'};
            }
            return undef;
        }

        # group name was specified
        if ($opt->{'name'}) {
            foreach (@$fg) {
                return LJ::MemCache::array_to_hash("fgrp", [$memver, @$_])
                    if lc($_->[2]) eq lc($opt->{'name'});
            }
            return undef;
        }

        # no arg, return entire object
        return { map { $_->[1] => LJ::MemCache::array_to_hash("fgrp", [$memver, @$_]) } @$fg };
    };

    # check memcache
    my $memkey = [$uid, "fgrp:$uid"];
    $fg = LJ::MemCache::get($memkey);
    return $find_grp->() if $fg;

    # check database
    $fg = [$ver];
    my $dbh = LJ::get_db_writer();
    my $sth = $dbh->prepare("SELECT userid, groupnum, groupname, sortorder, is_public " .
                            "FROM friendgroup WHERE userid=?");
    $sth->execute($uid);
    my @row;
    push @$fg, [ @row ] while @row = $sth->fetchrow_array;

    # set in memcache
    LJ::MemCache::set($memkey, $fg);

    return $find_grp->();
}

# <LJFUNC>
# name: LJ::get_friends
# des: Returns friends rows for a given user.
# args: uuserid, mask?, memcache_only?
# des-uuserid: a userid or u object
# des-mask: a security mask to filter on
# des-memcache_only: flag, set to only return data from memcache
# returns: hashref; keys = friend userids
#                   values = hashrefs of 'friends' columns and their values
# </LJFUNC>
sub get_friends {
    my ($uuid, $mask, $memcache_only) = @_;
    my $userid = LJ::want_userid($uuid);
    return undef unless $userid;

    # memcache data version
    my $ver = 1;

    my $packfmt = "NH6H6NC";
    my $packlen = 15;  # bytes

    my @cols = qw(friendid fgcolor bgcolor groupmask showbydefault);

    # first, check memcache
    my $memkey = [$userid, "friends:$userid"];
    my $memfriends = LJ::MemCache::get($memkey);
    if ($memfriends) {
        my %friends; # rows to be returned

        # first byte of object is data version
        # only version 1 is meaningful right now
        my $memver = substr($memfriends, 0, 1, '');
        return undef unless $memver == $ver;

        # get each $packlen-byte row
        while (length($memfriends) >= $packlen) {
            my @row = unpack($packfmt, substr($memfriends, 0, $packlen, ''));

            # don't add into %friends hash if groupmask doesn't match
            next if $mask && ! ($row[3]+0 & $mask+0);

            # add "#" to beginning of colors
            $row[$_] = "\#$row[$_]" foreach 1..2;

            # turn unpacked row into hashref
            my $fid = $row[0];
            my $idx = 1;
            foreach my $col (@cols[1..$#cols]) {
                $friends{$fid}->{$col} = $row[$idx];
                $idx++;
            }
        }

        # got from memcache, return
        return \%friends;
    }
    return {} if $memcache_only; # no friends

    # nothing from memcache, select all rows from the
    # database and insert those into memcache
    # then return rows that matched the given groupmask

    my $mempack = $ver; # full packed string to insert into memcache, byte 1 is dversion
    my %friends;        # friends object to be returned, all groupmasks match
    my $dbh = LJ::get_db_writer();
    my $sth = $dbh->prepare("SELECT friendid, fgcolor, bgcolor, groupmask, showbydefault " .
                            "FROM friends WHERE userid=?");
    $sth->execute($userid);
    while (my @row = $sth->fetchrow_array) {

        # convert color columns to hex
        $row[$_] = sprintf("%06x", $row[$_]) foreach 1..2;

        $mempack .= pack($packfmt, @row);

        # unless groupmask matches, skip adding to %friends
        next if $mask && ! ($row[3]+0 & $mask+0);

        # add "#" to beginning of colors
        $row[$_] = "\#$row[$_]" foreach 1..2;

        my $fid = $row[0];
        my $idx = 1;
        foreach my $col (@cols[1..$#cols]) {
            $friends{$fid}->{$col} = $row[$idx];
            $idx++;
        }
    }

    LJ::MemCache::add($memkey, $mempack);

    return \%friends;
}

# <LJFUNC>
# name: LJ::get_timeupdate_multi
# des: Get the last time a list of users updated
# args: opt?, uids
# des-opt: optional hashref, currently can contain 'memcache_only'
#          to only retrieve data from memcache
# des-uids: list of userids to load timeupdates for
# returns: hashref; uid => unix timeupdate
# </LJFUNC>
sub get_timeupdate_multi {
    my ($opt, @uids) = @_;

    # allow optional opt hashref as first argument
    unless (ref $opt eq 'HASH') {
        push @uids, $opt;
        $opt = {};
    }
    return {} unless @uids;

    my @memkeys = map { [$_, "tu:$_"] } @uids;
    my $mem = LJ::MemCache::get_multi(@memkeys) || {};

    my @need;
    my %timeupdate; # uid => timeupdate
    foreach (@uids) {
        if ($mem->{"tu:$_"}) {
            $timeupdate{$_} = unpack("N", $mem->{"tu:$_"});
        } else {
            push @need, $_;
        }
    }

    # if everything was in memcache, return now
    return \%timeupdate if $opt->{'memcache_only'} || ! @need;

    # fill in holes from the database
    my $dbh = LJ::get_db_writer();
    my $need_bind = join(",", map { "?" } @need);
    my $sth = $dbh->prepare("SELECT userid, UNIX_TIMESTAMP(timeupdate) " .
                            "FROM userusage WHERE userid IN ($need_bind)");
    $sth->execute(@need);
    while (my ($uid, $tu) = $sth->fetchrow_array) {
        $timeupdate{$uid} = $tu;

        # set memcache for this row
        LJ::MemCache::set([$uid, "tu:$uid"], pack("N", $tu), 30*60);
    }

    return \%timeupdate;
}

# returns undef on error, or otherwise arrayref of arrayrefs,
# each of format [ year, month, day, count ] for all days with
# non-zero count.  examples:
#  [ [ 2003, 6, 5, 3 ], [ 2003, 6, 8, 4 ], ... ]
# 
sub get_daycounts
{
    my ($u, $remote, $not_memcache) = @_;  
    # NOTE: $remote not yet used.  one of the oldest LJ shortcomings is that
    # it's public how many entries users have per-day, even if the entries
    # are protected.  we'll be fixing that with a new table, but first
    # we're moving everything to this API.

    my $uid = LJ::want_userid($u) or return undef;

    my @days;
    my $memkey = [$uid,"dayct:$uid"];
    unless ($not_memcache) {
        my $list = LJ::MemCache::get($memkey);
        return $list if $list;
    }
    
    my $dbcm = LJ::get_cluster_master($u) or return undef;
    my $sth = $dbcm->prepare("SELECT year, month, day, COUNT(*) ".
                             "FROM log2 WHERE journalid=? GROUP BY 1, 2, 3");
    $sth->execute($uid);
    while (my ($y, $m, $d, $c) = $sth->fetchrow_array) {
        # we force each number from string scalars (from DBI) to int scalars,
        # so they store smaller in memcache
        push @days, [ int($y), int($m), int($d), int($c) ];
    }
    LJ::MemCache::add($memkey, \@days);
    return \@days;
}

# <LJFUNC>
# name: LJ::get_friend_items
# des: Return friend items for a given user, filter, and period.
# args: dbarg?, opts
# des-opts: Hashref of options:
#           - userid
#           - remoteid
#           - itemshow
#           - skip
#           - filter  (opt) defaults to all
#           - friends (opt) friends rows loaded via LJ::get_friends()
#           - friends_u (opt) u objects of all friends loaded
#           - idsbycluster (opt) hashref to set clusterid key to [ [ journalid, itemid ]+ ]
#           - dateformat:  either "S2" for S2 code, or anything else for S1
#           - common_filter:  set true if this is the default view
#           - friendsoffriends: load friends of friends, not just friends
#           - u: hashref of journal loading friends of
#           - showtypes: /[PYC]/
# returns: Array of item hashrefs containing the same elements 
# </LJFUNC>
sub get_friend_items
{
    &nodb; 
    my $opts = shift;

    my $dbr = LJ::get_db_reader();
    my $sth;

    my $userid = $opts->{'userid'}+0;
    return () if $LJ::FORCE_EMPTY_FRIENDS{$userid};

    # 'remote' opt takes precendence, then 'remoteid'
    my $remote = $opts->{'remote'};
    my $remoteid = $remote ? $remote->{'userid'} : 0;
    if ($remoteid == 0 && $opts->{'remoteid'}) {
        $remoteid = $opts->{'remoteid'} + 0;
        $remote = LJ::load_userid($dbr, $remoteid);
    }

    my @items = ();
    my $itemshow = $opts->{'itemshow'}+0;
    my $skip = $opts->{'skip'}+0;
    my $getitems = $itemshow + $skip;

    my $filter = $opts->{'filter'}+0;

    my $max_age = $LJ::MAX_FRIENDS_VIEW_AGE || 3600*24*14;  # 2 week default.
    my $lastmax = $LJ::EndOfTime - time() + $max_age;
    my $lastmax_cutoff = 0; # if nonzero, never search for entries with rlogtime higher than this (set when cache in use)

    # sanity check:
    $skip = 0 if $skip < 0;

    # given a hash of friends rows, strip out rows with invalid journaltype
    my $filter_journaltypes = sub {
        my ($friends, $friends_u, $memcache_only) = @_;
        return unless $friends && $friends_u;

        # load u objects for all the given
        LJ::load_userids_multiple([ map { $_, \$friends_u->{$_} } keys %$friends ], [$remote],
                                  $memcache_only);

        # delete u objects based on 'showtypes'
        foreach my $fid (keys %$friends_u) {
            my $fu = $friends_u->{$fid};
            if ($fu->{'statusvis'} ne "V" ||
                ($opts->{'showtypes'} && 
                 index(uc($opts->{'showtypes'}), $fu->{journaltype}) == -1))
            {
                delete $friends_u->{$fid};
                delete $friends->{$fid};
            }
        }

        # all args passed by reference
        return;
    };

    my @friends_buffer = ();
    my $fr_loaded = 0;  # flag:  have we loaded friends?

    # normal friends mode
    my $get_next_friend = sub
    {
        # return one if we already have some loaded.
        return $friends_buffer[0] if @friends_buffer;
        return undef if $fr_loaded;

        # get all friends for this user and groupmask
        my $friends = LJ::get_friends($userid, $filter) || {};
        my %friends_u;

        # strip out rows with invalid journal types
        $filter_journaltypes->($friends, \%friends_u);

        # get update times for all the friendids
        my $tu_opts = {};
        my $fcount = scalar keys %$friends;
        if ($LJ::SLOPPY_FRIENDS_THRESHOLD && $fcount > $LJ::SLOPPY_FRIENDS_THRESHOLD) {
            $tu_opts->{memcache_only} = 1;
        }
        my $timeupdate = LJ::get_timeupdate_multi($tu_opts, keys %$friends);

        # now push a properly formatted @friends_buffer row
        foreach my $fid (keys %$timeupdate) {
            my $fu = $friends_u{$fid};
            my $rupdate = $LJ::EndOfTime - $timeupdate->{$fid};
            my $clusterid = $fu->{'clusterid'};
            push @friends_buffer, [ $fid, $rupdate, $clusterid, $friends->{$fid}, $fu ];
        }

        @friends_buffer = sort { $a->[1] <=> $b->[1] } @friends_buffer;

        # note that we've already loaded the friends
        $fr_loaded = 1;

        # return one if we just found some, else we're all
        # out and there's nobody else to load.
        return @friends_buffer ? $friends_buffer[0] : undef;
    };

    # memcached friends of friends mode
    $get_next_friend = sub
    {
        # return one if we already have some loaded.
        return $friends_buffer[0] if @friends_buffer;
        return undef if $fr_loaded;

        # get journal's friends
        my $friends = LJ::get_friends($userid) || {};
        return undef unless %$friends;

        my %friends_u;

        # fill %allfriends with all friendids and cut $friends
        # down to only include those that match $filter
        my %allfriends = ();
        foreach my $fid (keys %$friends) {
            $allfriends{$fid}++;

            # delete from friends if it doesn't match the filter
            next unless $filter && ! ($friends->{$fid}->{'groupmask'}+0 & $filter+0);
            delete $friends->{$fid};
        }

        # strip out invalid friend journaltypes
        $filter_journaltypes->($friends, \%friends_u, "memcache_only");

        # get update times for all the friendids
        my $f_tu = LJ::get_timeupdate_multi({'memcache_only' => 1}, keys %$friends);

        # get friends of friends
        my $ffct = 0;
        my %ffriends = ();
        foreach my $fid (sort { $f_tu->{$b} <=> $f_tu->{$a} } keys %$friends) {
            last if $ffct > 50;
            my $ff = LJ::get_friends($fid, undef, "memcache_only") || {};
            my $ct = 0;
            while (my $ffid = each %$ff) {
                last if $ct > 100;
                next if $allfriends{$ffid} || $ffid == $userid;
                $ffriends{$ffid} = $ff->{$ffid};
                $ct++;
            }
            $ffct++;
        }

        # strip out invalid friendsfriends journaltypes
        my %ffriends_u;
        $filter_journaltypes->(\%ffriends, \%ffriends_u, "memcache_only");

        # get update times for all the friendids
        my $ff_tu = LJ::get_timeupdate_multi({'memcache_only' => 1}, keys %ffriends);

        # build friends buffer
        foreach my $ffid (sort { $ff_tu->{$b} <=> $ff_tu->{$a} } keys %$ff_tu) {
            my $rupdate = $LJ::EndOfTime - $ff_tu->{$ffid};
            my $clusterid = $ffriends_u{$ffid}->{'clusterid'};

            # since this is ff mode, we'll force colors to ffffff on 000000
            $ffriends{$ffid}->{'fgcolor'} = "#000000";
            $ffriends{$ffid}->{'bgcolor'} = "#ffffff";

            push @friends_buffer, [ $ffid, $rupdate, $clusterid, $ffriends{$ffid}, $ffriends_u{$ffid} ];
        }

        @friends_buffer = sort { $a->[1] <=> $b->[1] } @friends_buffer;

        # note that we've already loaded the friends
        $fr_loaded = 1;

        # return one if we just found some fine, else we're all
        # out and there's nobody else to load.
        return @friends_buffer ? $friends_buffer[0] : undef;

    } if $opts->{'friendsoffriends'} && @LJ::MEMCACHE_SERVERS;

    # old friends of friends mode
    # - use this when there are no memcache servers
    $get_next_friend = sub
    {
        # return one if we already have some loaded.
        return $friends_buffer[0] if @friends_buffer;
        return undef if $fr_loaded;

        # load all user's friends
        my %f;
        my $sth = $dbr->prepare(qq{
            SELECT f.friendid, f.groupmask, $LJ::EndOfTime-UNIX_TIMESTAMP(uu.timeupdate),
            u.journaltype FROM friends f, userusage uu, user u
            WHERE f.userid=? AND f.friendid=uu.userid AND u.userid=f.friendid
        });
        $sth->execute($userid);
        while (my ($id, $mask, $time, $jt) = $sth->fetchrow_array) {
            next if $id == $userid; # don't follow user's own friends
            $f{$id} = { 'userid' => $id, 'timeupdate' => $time, 'jt' => $jt,
                        'relevant' => ($filter && !($mask & $filter)) ? 0 : 1 , };
        }
            
        # load some friends of friends (most 20 queries)
        my %ff;
        my $fct = 0;
        foreach my $fid (sort { $f{$a}->{'timeupdate'} <=> $f{$b}->{'timeupdate'} } keys %f)
        {
            next unless $f{$fid}->{'jt'} eq "P" && $f{$fid}->{'relevant'};
            last if ++$fct > 20;
            my $extra;
            if ($opts->{'showtypes'}) {
                my @in;
                if ($opts->{'showtypes'} =~ /P/) { push @in, "'P'"; }
                if ($opts->{'showtypes'} =~ /Y/) { push @in, "'Y'"; }
                if ($opts->{'showtypes'} =~ /C/) { push @in, "'C','S','N'"; }
                $extra = "AND u.journaltype IN (".join (',', @in).")" if @in;
            }

            my $sth = $dbr->prepare(qq{
                SELECT u.*, UNIX_TIMESTAMP(uu.timeupdate) AS timeupdate
                FROM friends f, userusage uu, user u WHERE f.userid=? AND
                    f.friendid=uu.userid AND f.friendid=u.userid AND u.statusvis='V' $extra
                    AND uu.timeupdate > DATE_SUB(NOW(), INTERVAL 14 DAY) LIMIT 100
            });
            $sth->execute($fid);
            while (my $u = $sth->fetchrow_hashref) {
                my $uid = $u->{'userid'};
                next if $f{$uid} || $uid == $userid;  # we don't wanna see our friends

                # timeupdate
                my $time = $LJ::EndOfTime-$u->{'timeupdate'};
                delete $u->{'timeupdate'}; # not a proper $u column

                $ff{$uid} = [ $uid, $time, $u->{'clusterid'}, {}, $u ];
            }
        }

        @friends_buffer = sort { $a->[1] <=> $b->[1] } values %ff;
        $fr_loaded = 1;

        return @friends_buffer ? $friends_buffer[0] : undef;
        
    } if $opts->{'friendsoffriends'} && ! @LJ::MEMCACHE_SERVERS;

    my $loop = 1;
    my $itemsleft = $getitems;  # even though we got a bunch, potentially, they could be old
    my $fr;

    while ($loop && ($fr = $get_next_friend->()))
    {
        shift @friends_buffer;

        # load the next recent updating friend's recent items
        my $friendid = $fr->[0];

        $opts->{'friends'}->{$friendid} = $fr->[3];  # friends row
        $opts->{'friends_u'}->{$friendid} = $fr->[4]; # friend u object

        my @newitems = LJ::get_log2_recent_user({
            'clusterid' => $fr->[2],
            'userid' => $friendid,
            'remote' => $remote,
            'itemshow' => $itemsleft,
            'notafter' => $lastmax,
            'dateformat' => $opts->{'dateformat'},
            'update' => $LJ::EndOfTime - $fr->[1], # reverse back to normal
        });
        
        # stamp each with clusterid if from cluster, so ljviews and other
        # callers will know which items are old (no/0 clusterid) and which
        # are new
        if ($fr->[2]) {
            foreach (@newitems) { $_->{'clusterid'} = $fr->[2]; }
        }

        if (@newitems)
        {
            push @items, @newitems;

            $itemsleft--; # we'll need at least one less for the next friend

            # sort all the total items by rlogtime (recent at beginning)
            @items = sort { $a->{'rlogtime'} <=> $b->{'rlogtime'} } @items;

            # cut the list down to what we need.
            @items = splice(@items, 0, $getitems) if (@items > $getitems);
        }

        if (@items == $getitems)
        {
            $lastmax = $items[-1]->{'rlogtime'};
            $lastmax = $lastmax_cutoff if $lastmax_cutoff && $lastmax > $lastmax_cutoff;

            # stop looping if we know the next friend's newest entry
            # is greater (older) than the oldest one we've already
            # loaded.
            my $nextfr = $get_next_friend->();
            $loop = 0 if ($nextfr && $nextfr->[1] > $lastmax);
        }
    }

    # remove skipped ones
    splice(@items, 0, $skip) if $skip;

    # get items
    foreach (@items) {
        $opts->{'owners'}->{$_->{'ownerid'}} = 1;
    }

    # return the itemids grouped by clusters, if callers wants it.
    if (ref $opts->{'idsbycluster'} eq "HASH") {
        foreach (@items) {
            push @{$opts->{'idsbycluster'}->{$_->{'clusterid'}}},
            [ $_->{'ownerid'}, $_->{'itemid'} ];
        }
    }

    return @items;
}

# <LJFUNC>
# name: LJ::get_recent_items
# class:
# des: Returns journal entries for a given account.
# info:
# args: dbarg, opts
# des-opts: Hashref of options with keys:
#           -- err: scalar ref to return error code/msg in
#           -- userid
#           -- remote: remote user's $u
#           -- remoteid: id of remote user
#           -- clusterid: clusterid of userid
#           -- clustersource: if value 'slave', uses replicated databases
#           -- order: if 'logtime', sorts by logtime, not eventtime
#           -- friendsview: if true, sorts by logtime, not eventtime
#           -- notafter: upper bound inclusive for rlogtime/revttime (depending on sort mode),
#              defaults to no limit
#           -- skip: items to skip
#           -- itemshow: items to show
#           -- viewall: if set, no security is used.
#           -- dateformat: if "S2", uses S2's 'alldatepart' format.
#           -- itemids: optional arrayref onto which itemids should be pushed
# returns: array of hashrefs containing keys:
#          -- itemid (the jitemid)
#          -- posterid
#          -- security
#          -- alldatepart (in S1 or S2 fmt, depending on 'dateformat' req key)
#          -- ownerid (if in 'friendsview' mode)
#          -- rlogtime (if in 'friendsview' mode)
# </LJFUNC>
sub get_recent_items
{
    &nodb;
    my $opts = shift;

    my $dbr = LJ::get_db_reader();
    my $sth;

    my @items = ();             # what we'll return
    my $err = $opts->{'err'};

    my $userid = $opts->{'userid'}+0;

    # 'remote' opt takes precendence, then 'remoteid'
    my $remote = $opts->{'remote'};
    my $remoteid = $remote ? $remote->{'userid'} : 0;
    if ($remoteid == 0 && $opts->{'remoteid'}) {
        $remoteid = $opts->{'remoteid'} + 0;
        $remote = LJ::load_userid($dbr, $remoteid);
    }

    my $max_hints = $LJ::MAX_HINTS_LASTN;  # temporary
    my $sort_key = "revttime";

    my $clusterid = $opts->{'clusterid'}+0;
    my @sources = ("cluster$clusterid");
    if (my $ab = $LJ::CLUSTER_PAIR_ACTIVE{$clusterid}) {
        @sources = ("cluster${clusterid}${ab}");
    }
    unshift @sources, ("cluster${clusterid}lite", "cluster${clusterid}slave")
        if $opts->{'clustersource'} eq "slave";
    my $logdb = LJ::get_dbh(@sources);

    # community/friend views need to post by log time, not event time
    $sort_key = "rlogtime" if ($opts->{'order'} eq "logtime" ||
                               $opts->{'friendsview'});

    # 'notafter':
    #   the friends view doesn't want to load things that it knows it
    #   won't be able to use.  if this argument is zero or undefined,
    #   then we'll load everything less than or equal to 1 second from
    #   the end of time.  we don't include the last end of time second
    #   because that's what backdated entries are set to.  (so for one
    #   second at the end of time we'll have a flashback of all those
    #   backdated entries... but then the world explodes and everybody
    #   with 32 bit time_t structs dies)
    my $notafter = $opts->{'notafter'} + 0 || $LJ::EndOfTime - 1;

    my $skip = $opts->{'skip'}+0;
    my $itemshow = $opts->{'itemshow'}+0;
    if ($itemshow > $max_hints) { $itemshow = $max_hints; }
    my $maxskip = $max_hints - $itemshow;
    if ($skip < 0) { $skip = 0; }
    if ($skip > $maxskip) { $skip = $maxskip; }
    my $itemload = $itemshow + $skip;

    my $mask = 0;
    if ($remote && $remote->{'journaltype'} eq "P" && $remoteid != $userid) {
        $mask = LJ::get_groupmask($userid, $remoteid);
    }

    # decide what level of security the remote user can see
    my $secwhere = "";
    if ($userid == $remoteid || $opts->{'viewall'}) {
        # no extra where restrictions... user can see all their own stuff
        # alternatively, if 'viewall' opt flag is set, security is off.
    } elsif ($mask) {
        # can see public or things with them in the mask
        $secwhere = "AND (security='public' OR (security='usemask' AND allowmask & $mask != 0))";
    } else {
        # not a friend?  only see public.
        $secwhere = "AND security='public' ";
    }

    # because LJ::get_friend_items needs rlogtime for sorting.
    my $extra_sql;
    if ($opts->{'friendsview'}) {
        $extra_sql .= "journalid AS 'ownerid', rlogtime, ";
    }

    my $sql;

    my $dateformat = "%a %W %b %M %y %Y %c %m %e %d %D %p %i %l %h %k %H";
    if ($opts->{'dateformat'} eq "S2") {
        $dateformat = "%Y %m %d %H %i %s %w"; # yyyy mm dd hh mm ss day_of_week
    }

    $sql = ("SELECT jitemid AS 'itemid', posterid, security, $extra_sql ".
            "DATE_FORMAT(eventtime, \"$dateformat\") AS 'alldatepart', anum ".
            "FROM log2 USE INDEX ($sort_key) WHERE journalid=$userid AND $sort_key <= $notafter $secwhere ".
            "ORDER BY journalid, $sort_key ".
            "LIMIT $skip,$itemshow");

    unless ($logdb) {
        $$err = "nodb" if ref $err eq "SCALAR";
        return ();
    }

    $sth = $logdb->prepare($sql);
    $sth->execute;
    if ($logdb->err) { die $logdb->errstr; }

    # keep track of the last alldatepart, and a per-minute buffer
    my $last_time;
    my @buf;
    my $flush = sub {
        return unless @buf;
        push @items, sort { $b->{itemid} <=> $a->{itemid} } @buf;
        @buf = ();
    };

    while (my $li = $sth->fetchrow_hashref) {
        push @{$opts->{'itemids'}}, $li->{'itemid'};

        $flush->() if $li->{alldatepart} ne $last_time;
        push @buf, $li;
        $last_time = $li->{alldatepart};
    }
    $flush->();

    return @items;
}

# <LJFUNC>
# name: LJ::set_userprop
# des: Sets/deletes a userprop by name for a user.
# info: This adds or deletes from the
#       [dbtable[userprop]]/[dbtable[userproplite]] tables.  One
#       crappy thing about this interface is that it doesn't allow
#       a batch of userprops to be updated at once, which is the
#       common thing to do.
# args: dbarg?, uuserid, propname, value, memonly?
# des-uuserid: The userid of the user or a user hashref.
# des-propname: The name of the property.  Or a hashref of propname keys and corresponding values.
# des-value: The value to set to the property.  If undefined or the
#            empty string, then property is deleted.
# des-memonly: if true, only writes to memcache, and not to database.
# </LJFUNC>
sub set_userprop
{
    &nodb;

    my ($u, $propname, $value, $memonly) = @_;
    $u = ref $u ? $u : LJ::load_userid($u);
    my $userid = $u->{'userid'}+0;

    my $hash = ref $propname eq "HASH" ? $propname : { $propname => $value };

    my %action;  # $table -> {"replace"|"delete"} -> [ "($userid, $propid, $qvalue)" | propid ]

    foreach $propname (keys %$hash) {
        my $p = LJ::get_prop("user", $propname) or next;
        my $table = $p->{'indexed'} ? "userprop" : "userproplite";
        if ($p->{datatype} eq 'blobchar') {
            $table = 'userpropblob';
        }
        elsif ($p->{'cldversion'} && $u->{'dversion'} >= $p->{'cldversion'}) {
            $table = "userproplite2";
        }
        unless ($memonly) {
            my $db = $action{$table}->{'db'} ||= (
                $table !~ m{userprop(lite2|blob)}
                    ? LJ::get_db_writer()
                    : LJ::get_cluster_master($u) );
            return 0 unless $db;
        }
        $value = $hash->{$propname};
        if (defined $value && $value) {
            push @{$action{$table}->{"replace"}}, [ $p->{'id'}, $value ];
        } else {
            push @{$action{$table}->{"delete"}}, $p->{'id'};
        }
    }

    my $expire = time() + 3600*24;
    foreach my $table (keys %action) {
        my $db = $action{$table}->{'db'};
        if (my $list = $action{$table}->{"replace"}) {
            if ($db) {
                my $vals = join(',', map { "($userid,$_->[0]," . $db->quote($_->[1]) . ")" } @$list);
                $db->do("REPLACE INTO $table (userid, upropid, value) VALUES $vals");
            }
            LJ::MemCache::set([$userid,"uprop:$userid:$_->[0]"], $_->[1], $expire) foreach (@$list);
        }
        if (my $list = $action{$table}->{"delete"}) {
            if ($db) {
                my $in = join(',', @$list);
                $db->do("DELETE FROM $table WHERE userid=$userid AND upropid IN ($in)");
            }
            LJ::MemCache::set([$userid,"uprop:$userid:$_"], "", $expire) foreach (@$list);
        }
    }
    return 1;
}

# <LJFUNC>
# name: LJ::register_authaction
# des: Registers a secret to have the user validate.
# info: Some things, like requiring a user to validate their email address, require
#       making up a secret, mailing it to the user, then requiring them to give it
#       back (usually in a URL you make for them) to prove they got it.  This
#       function creates a secret, attaching what it's for and an optional argument.
#       Background maintenance jobs keep track of cleaning up old unvalidated secrets.
# args: dbarg?, userid, action, arg?
# des-userid: Userid of user to register authaction for.
# des-action: Action type to register.   Max chars: 50.
# des-arg: Optional argument to attach to the action.  Max chars: 255.
# returns: 0 if there was an error.  Otherwise, a hashref
#          containing keys 'aaid' (the authaction ID) and the 'authcode',
#          a 15 character string of random characters from
#          [func[LJ::make_auth_code]].
# </LJFUNC>
sub register_authaction
{
    &nodb;
    my $dbh = LJ::get_db_writer();

    my $userid = shift;  $userid += 0;
    my $action = $dbh->quote(shift);
    my $arg1 = $dbh->quote(shift);

    # make the authcode
    my $authcode = LJ::make_auth_code(15);
    my $qauthcode = $dbh->quote($authcode);

    $dbh->do("INSERT INTO authactions (aaid, userid, datecreate, authcode, action, arg1) ".
             "VALUES (NULL, $userid, NOW(), $qauthcode, $action, $arg1)");

    return 0 if $dbh->err;
    return { 'aaid' => $dbh->{'mysql_insertid'},
             'authcode' => $authcode,
         };
}

# <LJFUNC>
# class: logging
# name: LJ::statushistory_add
# des: Adds a row to a user's statushistory
# info: See the [dbtable[statushistory]] table.
# returns: boolean; 1 on success, 0 on failure
# args: dbarg?, userid, adminid, shtype, notes?
# des-userid: The user being acted on.
# des-adminid: The site admin doing the action.
# des-shtype: The status history type code.
# des-notes: Optional notes associated with this action.
# </LJFUNC>
sub statushistory_add
{
    &nodb;
    my $dbh = LJ::get_db_writer();
    
    my $userid = shift;
    $userid = LJ::want_userid($userid) + 0;

    my $actid  = shift;
    $actid = LJ::want_userid($actid) + 0;

    my $qshtype = $dbh->quote(shift);
    my $qnotes  = $dbh->quote(shift);

    $dbh->do("INSERT INTO statushistory (userid, adminid, shtype, notes) ".
             "VALUES ($userid, $actid, $qshtype, $qnotes)");
    return $dbh->err ? 0 : 1;
}

# <LJFUNC>
# name: LJ::make_link
# des: Takes a group of key=value pairs to append to a url
# returns: The finished url
# args: url, vars
# des-url: A string with the URL to append to.  The URL
#          shouldn't have a question mark in it.
# des-vars: A hashref of the key=value pairs to append with.
# </LJFUNC>
sub make_link
{
    my $url = shift;
    my $vars = shift;
    my $append = "?";
    foreach (keys %$vars) {
        next if ($vars->{$_} eq "");
        $url .= "${append}${_}=$vars->{$_}";
        $append = "&";
    }
    return $url;
}

# <LJFUNC>
# class: time
# name: LJ::ago_text
# des: Converts integer seconds to English time span
# info: Turns a number of seconds into the largest possible unit of
#       time. "2 weeks", "4 days", or "20 hours".
# returns: A string with the number of largest units found
# args: secondsold
# des-secondsold: The number of seconds from now something was made.
# </LJFUNC>
sub ago_text
{
    my $secondsold = shift;
    return "Never." unless ($secondsold);
    my $num;
    my $unit;
    if ($secondsold > 60*60*24*7) {
        $num = int($secondsold / (60*60*24*7));
        $unit = "week";
    } elsif ($secondsold > 60*60*24) {
        $num = int($secondsold / (60*60*24));
        $unit = "day";
    } elsif ($secondsold > 60*60) {
        $num = int($secondsold / (60*60));
        $unit = "hour";
    } elsif ($secondsold > 60) {
        $num = int($secondsold / (60));
        $unit = "minute";
    } else {
        $num = $secondsold;
        $unit = "second";
    }
    return "$num $unit" . ($num==1?"":"s") . " ago";
}

# <LJFUNC>
# name: LJ::get_shared_journals
# des: Gets an array of shared journals a user has access to.
# returns: An array of shared journals.
# args: u
# </LJFUNC>
sub get_shared_journals
{
    my $u = shift;
    my $ids = LJ::load_rel_target($u, 'A') || [];

    # have to get usernames;
    my %users;
    LJ::load_userids_multiple([ map { $_, \$users{$_} } @$ids ], [$u]);
    return sort map { $_->{'user'} } values %users;
}

# <LJFUNC>
# name: LJ::get_authas_user
# des: Given a username, will return a user object if remote is an admin for the
#      username.  Otherwise returns undef
# returns: user object if authenticated, otherwise undef.
# args: user
# des-opts: Username of user to attempt to auth as.
# </LJFUNC>
sub get_authas_user {
    my $user = shift;
    return undef unless $user;

    # get a remote
    my $remote = LJ::get_remote();
    return undef unless $remote;

    # remote is already what they want?
    return $remote if $remote->{'user'} eq $user;

    # load user and authenticate
    my $u = LJ::load_user($user);
    return undef unless $u;

    # does $u have admin access?
    return undef unless LJ::can_manage($remote, $u);

    # passed all checks, return $u
    return $u;
}

# <LJFUNC>
# name: LJ::can_manage
# des: Given a user and a target user, will determine if the first user is an
#      admin for the target user.
# returns: bool: true if authorized, otherwise fail
# args: remote, u
# des-remote: user object or userid of user to try and authenticate
# des-u: user object or userid of target user
# </LJFUNC>
sub can_manage {
    my ($remote, $u) = @_;
    return undef unless $remote && $u;

    # is same user?
    return 1 if want_userid($remote) == want_userid($u);

    # check for admin access
    return undef unless LJ::check_rel($u, $remote, 'A');

    # passed checks, return true
    return 1;
}

sub can_delete_journal_item {
    return LJ::can_manage(@_);
}

# <LJFUNC>
# name: LJ::get_authas_list
# des: Get a list of usernames a given user can authenticate as
# returns: an array of usernames
# args: u, opts?
# des-opts: Optional hashref.  keys are:
#           - type: 'P' to only return users of journaltype 'P'
#           - cap:  cap to filter users on
# </LJFUNC>
sub get_authas_list {
    my ($u, $opts) = @_;

    # used to accept a user type, now accept an opts hash
    $opts = { 'type' => $opts } unless ref $opts;

    # only one valid type right now
    $opts->{'type'} = 'P' if $opts->{'type'};

    my $ids = LJ::load_rel_target($u, 'A');
    return undef unless $ids;

    # load_userids_multiple
    my %users;
    LJ::load_userids_multiple([ map { $_, \$users{$_} } @$ids ], [$u]);

    return $u->{'user'}, sort map { $_->{'user'} }
                         grep { ! $opts->{'cap'} || LJ::get_cap($_, $opts->{'cap'}) }
                         grep { ! $opts->{'type'} || $opts->{'type'} eq $_->{'journaltype'} }
                         values %users;
}


# <LJFUNC>
# name: LJ::comm_member_request
# des: Registers an authaction to add a user to a
#      community and sends an approval email
# returns: Hashref; output of LJ::register_authaction()
#          includes datecreate of old row if no new row was created
# args: comm, u, attr?
# des-comm: Community user object
# des-u: User object to add to community
# des-attr: array of attributes new user will have
# </LJFUNC>
sub comm_member_request {
    my ($comm, $u, $attr) = @_;
    return undef unless ref $comm && ref $u;

    my $arg = join("&", "targetid=$u->{'userid'}", map { "$_=1" } sort @$attr);

    my $dbh = LJ::get_db_writer();

    # check for duplicates within the same hour (to prevent spamming)
    my $oldaa = $dbh->selectrow_hashref("SELECT aaid, authcode, datecreate FROM authactions " .
                                        "WHERE userid=? AND arg1=? " .
                                        "AND action='comm_invite' AND used='N' " .
                                        "AND NOW() < datecreate + INTERVAL 1 HOUR " .
                                        "ORDER BY 1 DESC LIMIT 1",
                                        undef, $comm->{'userid'}, $arg);
    return $oldaa if $oldaa;

    # insert authactions row
    my $aa = LJ::register_authaction($comm->{'userid'}, 'comm_invite', $arg);
    return undef unless $aa;

    # if there are older duplicates, invalidate any existing unused authactions of this type
    $dbh->do("UPDATE authactions SET used='Y' WHERE userid=? AND aaid<>? AND arg1=? " .
             "AND action='comm_invite' AND used='N'",
             undef, $comm->{'userid'}, $aa->{'aaid'}, $arg);

    # email recipient user for confirmation
    $attr ||= [];
    my %attr_map = ('member'     => "Member",
                    'admin'      => "Maintainer",
                    'post'       => "Poster",
                    'moderate'   => "Moderator",
                    'preapprove' => "Unmoderated",
                    );

    my $cuser = $comm->{'user'};
    my $body = "Dear $u->{'user'},\n";
    $body .= "A maintainer of the $cuser community ($LJ::SITEROOT/community/$cuser/) " .
        "has requested that you be added to the community with the following ".
        "capabilities: " .
        join(", ", map { $attr_map{$_} } @$attr) . ".\n\n" .
        "If you do not wish to be added to $cuser, just ignore this email.  " .
        "However, if you would like to join the community, please click " .
        "the link below to authorize this action.\n\n" .
        "     $LJ::SITEROOT/approve/$aa->{'aaid'}.$aa->{'authcode'}\n\n" .
        "Regards\n$LJ::SITENAME Team\n";

    LJ::send_mail({
        'to' => $u->{'email'},
        'from' => $LJ::ADMIN_EMAIL,
        'fromname' => $LJ::SITENAME,
        'charset' => 'utf-8',
        'subject' => "Community Membership: $cuser",
        'body' => $body
        });

    return $aa;
}

# <LJFUNC>
# name: LJ::shared_member_request
# des: Registers an authaction to add a user to a
#      shared journal and sends an approval email
# returns: Hashref; output of LJ::register_authaction()
#          includes datecreate of old row if no new row was created
# args: ju, u, attr?
# des-ju: Shared journal user object
# des-u: User object to add to shared journal
# </LJFUNC>
sub shared_member_request {
    my ($ju, $u) = @_;
    return undef unless ref $ju && ref $u;

    my $dbh = LJ::get_db_writer();

    # check for duplicates
    my $oldaa = $dbh->selectrow_hashref("SELECT aaid, authcode, datecreate FROM authactions " .
                                        "WHERE userid=? AND action='shared_invite' AND used='N' " .
                                        "AND NOW() < datecreate + INTERVAL 1 HOUR " .
                                        "ORDER BY 1 DESC LIMIT 1",
                                        undef, $ju->{'userid'});
    return $oldaa if $oldaa;

    # insert authactions row
    my $aa = LJ::register_authaction($ju->{'userid'}, 'shared_invite', "targetid=$u->{'userid'}");
    return undef unless $aa;

    # if there are older duplicates, invalidate any existing unused authactions of this type
    $dbh->do("UPDATE authactions SET used='Y' WHERE userid=? AND aaid<>? " .
             "AND action='shared_invite' AND used='N'",
             undef, $ju->{'userid'}, $aa->{'aaid'});

    my $body = "The maintainer of the $ju->{'user'} shared journal has requested that " .
        "you be given posting access.\n\n" .
        "If you do not wish to be added to this journal, just ignore this email.  " .
        "However, if you would like to accept posting rights to $ju->{'user'}, click " .
        "the link below to authorize this action.\n\n" .
        "     $LJ::SITEROOT/approve/$aa->{'aaid'}.$aa->{'authcode'}\n\n" .
        "Regards\n$LJ::SITENAME Team\n";

    LJ::send_mail({
        'to' => $u->{'email'},
        'from' => $LJ::ADMIN_EMAIL,
        'fromname' => $LJ::SITENAME,
        'charset' => 'utf-8',
        'subject' => "Community Membership: $ju->{'name'}",
        'body' => $body
        });

    return $aa;
}

# <LJFUNC>
# name: LJ::is_valid_authaction
# des: Validates a shared secret (authid/authcode pair)
# info: See [func[LJ::register_authaction]].
# returns: Hashref of authaction row from database.
# args: dbarg?, aaid, auth
# des-aaid: Integer; the authaction ID.
# des-auth: String; the auth string. (random chars the client already got)
# </LJFUNC>
sub is_valid_authaction
{
    &nodb;

    # we use the master db to avoid races where authactions could be
    # used multiple times
    my $dbh = LJ::get_db_writer();
    my ($aaid, $auth) = @_;
    return $dbh->selectrow_hashref("SELECT * FROM authactions WHERE aaid=? AND authcode=?",
                                   undef, $aaid, $auth);
}

# <LJFUNC>
# name: LJ::get_mood_picture
# des: Loads a mood icon hashref given a themeid and moodid.
# args: themeid, moodid, ref
# des-themeid: Integer; mood themeid.
# des-moodid: Integer; mood id.
# des-ref: Hashref to load mood icon data into.
# returns: Boolean; 1 on success, 0 otherwise.
# </LJFUNC>
sub get_mood_picture
{
    my ($themeid, $moodid, $ref) = @_;
    LJ::load_mood_theme($themeid) unless $LJ::CACHED_MOOD_THEME{$themeid};
    LJ::load_moods() unless $LJ::CACHED_MOODS;
    do
    {
        if ($LJ::CACHE_MOOD_THEME{$themeid} && 
            $LJ::CACHE_MOOD_THEME{$themeid}->{$moodid}) {
            %{$ref} = %{$LJ::CACHE_MOOD_THEME{$themeid}->{$moodid}};
            if ($ref->{'pic'} =~ m!^/!) {
                $ref->{'pic'} =~ s!^/img!!;
                $ref->{'pic'} = $LJ::IMGPREFIX . $ref->{'pic'};
            }
            $ref->{'moodid'} = $moodid;
            return 1;
        } else {
            $moodid = (defined $LJ::CACHE_MOODS{$moodid} ? 
                       $LJ::CACHE_MOODS{$moodid}->{'parent'} : 0);
        }
    }
    while ($moodid);
    return 0;
}

# mood id to name (or undef)
sub mood_name
{
    my ($moodid) = @_;
    LJ::load_moods() unless $LJ::CACHED_MOODS;
    my $m = $LJ::CACHE_MOODS{$moodid};
    return $m ? $m->{'name'} : undef;
}

# mood name to id (or undef)
sub mood_id
{
    my ($mood) = @_;
    return undef unless $mood;
    LJ::load_moods() unless $LJ::CACHED_MOODS;
    foreach my $m (values %LJ::CACHE_MOODS) {
        return $m->{'id'} if $mood eq $m->{'name'};
    }
    return undef;
}

sub get_moods
{
    LJ::load_moods() unless $LJ::CACHED_MOODS;
    return \%LJ::CACHE_MOODS;
}

# <LJFUNC>
# class: time
# name: LJ::http_to_time
# des: Converts HTTP date to Unix time.
# info: Wrapper around HTTP::Date::str2time.
#       See also [func[LJ::time_to_http]].
# args: string
# des-string: HTTP Date.  See RFC 2616 for format.
# returns: integer; Unix time.
# </LJFUNC>
sub http_to_time {
    my $string = shift;
    return HTTP::Date::str2time($string);
}

sub mysqldate_to_time {
    my ($string, $gmt) = @_;
    return undef unless $string =~ /^(\d\d\d\d)-(\d\d)-(\d\d)(?: (\d\d):(\d\d)(?::(\d\d))?)?$/;
    return $gmt ?
        Time::Local::timegm($6, $5, $4, $3, $2-1, $1) :
        Time::Local::timelocal($6, $5, $4, $3, $2-1, $1);        
}

# <LJFUNC>
# class: time
# name: LJ::time_to_http
# des: Converts a Unix time to an HTTP date.
# info: Wrapper around HTTP::Date::time2str to make an
#       HTTP date (RFC 1123 format)  See also [func[LJ::http_to_time]].
# args: time
# des-time: Integer; Unix time.
# returns: String; RFC 1123 date.
# </LJFUNC>
sub time_to_http {
    my $time = shift;
    return HTTP::Date::time2str($time);
}

# <LJFUNC>
# name: LJ::time_to_cookie
# des: Converts unix time to format expected in a Set-Cookie header
# args: time
# des-time: unix time
# returns: string; Date/Time in format expected by cookie.
# </LJFUNC>
sub time_to_cookie {
    my $time = shift;
    $time = time() unless defined $time;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($time);
    $year+=1900;

    my @day = qw{Sunday Monday Tuesday Wednesday Thursday Friday Saturday};
    my @month = qw{Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec};

    return sprintf("$day[$wday], %02d-$month[$mon]-%04d %02d:%02d:%02d GMT", 
                   $mday, $year, $hour, $min, $sec);
}

# http://www.w3.org/TR/NOTE-datetime
# http://www.w3.org/TR/xmlschema-2/#dateTime
sub time_to_w3c {
    my ($time, $ofs) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($time);

    $mon++;
    $year += 1900;

    $ofs =~ s/([\-+]\d\d)(\d\d)/$1:$2/;
    $ofs = 'Z' if $ofs =~ /0000$/;
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02d$ofs",
                   $year, $mon, $mday,
                   $hour, $min, $sec);
}

# <LJFUNC>
# class: component
# name: LJ::ljuser
# des: Make link to userinfo/journal of user.
# info: Returns the HTML for a userinfo/journal link pair for a given user
#       name, just like LJUSER does in BML.  This is for files like cleanhtml.pl
#       and ljpoll.pl which need this functionality too, but they aren't run as BML.
# args: user, opts?
# des-user: Username to link to, or user hashref.
# des-opts: Optional hashref to control output.  Key 'full' when true causes
#           a link to the mode=full userinfo.   Key 'type' when 'C' makes
#           a community link, when 'Y' makes a syndicated account link,
#           when 'N' makes a news account link, otherwise makes a user account
#           link. If user parameter is a hashref, its 'journaltype' overrides
#           this 'type'.  Key 'del', when true, makes a tag for a deleted user.
#           If user parameter is a hashref, its 'statusvis' overrides 'del'.
# returns: HTML with a little head image & bold text link.
# </LJFUNC>
sub ljuser
{
    my $user = shift;
    my $opts = shift;

    if ($LJ::DYNAMIC_LJUSER && ref $user ne 'HASH') {
        # Try to automatically pick the user type, but still
        # make something if we can't (user doesn't exist?)
        $user = LJ::load_user($user) || $user;

        # Traverse the renames to the final journal
        while (ref $user and $user->{'journaltype'} eq 'R') {
            LJ::load_user_props($user, 'renamedto');
            last unless length $user->{'renamedto'};
            $user = LJ::load_user($user->{'renamedto'});
        }
    }

    if (ref $user eq 'HASH') {
        $opts->{'type'} = $user->{'journaltype'};
        $opts->{'del'} = $user->{'statusvis'} ne 'V';
        $user = $user->{'user'};
    }
    my $andfull = $opts->{'full'} ? "&amp;mode=full" : "";
    my $img = $opts->{'imgroot'} || $LJ::IMGPREFIX;
    my $strike = $opts->{'del'} ? ' text-decoration: line-through;' : '';
    my $make_tag = sub {
        my ($fil, $dir, $x, $y) = @_;
        $y ||= $x;  # make square if only one dimension given

        return "<span class='ljuser' style='white-space: nowrap;$strike'><a href='$LJ::SITEROOT/userinfo.bml?user=$user$andfull'><img src='$img/$fil' alt='[info]' width='$x' height='$y' style='vertical-align: bottom; border: 0;' /></a><a href='$LJ::SITEROOT/$dir/$user/'><b>$user</b></a></span>";
    };

    if ($opts->{'type'} eq 'C') {
        return $make_tag->('community.gif', 'community', 16);
    } elsif ($opts->{'type'} eq 'Y') {
        return $make_tag->('syndicated.gif', 'users', 16);
    } elsif ($opts->{'type'} eq 'N') {
        return $make_tag->('newsinfo.gif', 'users', 16);
    } else {
        return $make_tag->('userinfo.gif', 'users', 17);
    }
}

# <LJFUNC>
# name: LJ::get_urls
# des: Returns a list of all referenced URLs from a string
# args: text
# des-text: Text to extra URLs from
# returns: list of URLs
# </LJFUNC>
sub get_urls
{
    my $text = shift;
    my @urls;
    while ($text =~ s!http://[^\s\"\'\<\>]+!!) {
        push @urls, $&;
    }
    return @urls;
}

# <LJFUNC>
# name: LJ::record_meme
# des: Records a URL reference from a journal entry to the meme table.
# args: dbarg?, url, posterid, itemid, journalid?
# des-url: URL to log
# des-posterid: Userid of person posting
# des-itemid: Itemid URL appears in.  This is the display itemid,
#             which is the jitemid*256+anum from the [dbtable[log2]] table.
# des-journalid: Optional, journal id of item, if item is clustered.  Otherwise
#                this should be zero or undef.
# </LJFUNC>
sub record_meme
{
    &nodb;
    my ($url, $posterid, $itemid, $jid) = @_;

    $url =~ s!/$!!;  # strip / at end
    LJ::run_hooks("canonicalize_url", \$url);

    # canonicalize_url hook might just erase it, so
    # we don't want to record it.
    return unless $url;

    my $dbh = LJ::get_db_writer();
    $dbh->do("REPLACE DELAYED INTO meme (url, posterid, journalid, itemid) " .
             "VALUES (?, ?, ?, ?)", undef, $url, $posterid, $jid, $itemid);
}

# <LJFUNC>
# name: LJ::name_caps
# des: Given a user's capability class bit mask, returns a
#      site-specific string representing the capability class name.
# args: caps
# des-caps: 16 bit capability bitmask
# </LJFUNC>
sub name_caps
{
    return undef unless LJ::are_hooks("name_caps");
    my $caps = shift;
    return LJ::run_hook("name_caps", $caps);
}

# <LJFUNC>
# name: LJ::name_caps_short
# des: Given a user's capability class bit mask, returns a
#      site-specific short string code.
# args: caps
# des-caps: 16 bit capability bitmask
# </LJFUNC>
sub name_caps_short
{
    return undef unless LJ::are_hooks("name_caps_short");
    my $caps = shift;
    return LJ::run_hook("name_caps_short", $caps);
}

# <LJFUNC>
# name: LJ::get_cap
# des: Given a user object or capability class bit mask and a capability/limit name,
#      returns the maximum value allowed for given user or class, considering
#      all the limits in each class the user is a part of.
# args: u_cap, capname
# des-u_cap: 16 bit capability bitmask or a user object from which the
#            bitmask could be obtained
# des-capname: the name of a limit, defined in doc/capabilities.txt
# </LJFUNC>
sub get_cap
{
    my $caps = shift;   # capability bitmask (16 bits), or user object
    my $cname = shift;  # capability limit name
    my $u = ref $caps ? $caps : undef;
    if (! defined $caps) { $caps = 0; }
    elsif ($u) { $caps = $u->{'caps'}; }
    my $max = undef;

    # allow a way for admins to force-set the read-only cap
    # to lower writes on a cluster.
    if ($cname eq "readonly" && $u &&
        ($LJ::READONLY_CLUSTER{$u->{clusterid}} ||
         $LJ::READONLY_CLUSTER_ADVISORY{$u->{clusterid}} &&
         ! LJ::get_cap($u, "avoid_readonly"))) {
        return 1;
    }

    foreach my $bit (keys %LJ::CAP) {
        next unless ($caps & (1 << $bit));
        my $v = $LJ::CAP{$bit}->{$cname};
        next unless (defined $v);
        next if (defined $max && $max > $v);
        $max = $v;
    }
    return defined $max ? $max : $LJ::CAP_DEF{$cname};
}

# <LJFUNC>
# name: LJ::get_cap_min
# des: Just like [func[LJ::get_cap]], but returns the minimum value.
#      Although it might not make sense at first, some things are
#      better when they're low, like the minimum amount of time
#      a user might have to wait between getting updates or being
#      allowed to refresh a page.
# args: u_cap, capname
# des-u_cap: 16 bit capability bitmask or a user object from which the
#            bitmask could be obtained
# des-capname: the name of a limit, defined in doc/capabilities.txt
# </LJFUNC>
sub get_cap_min
{
    my $caps = shift;   # capability bitmask (16 bits), or user object
    my $cname = shift;  # capability name
    if (! defined $caps) { $caps = 0; }
    elsif (ref $caps eq "HASH") { $caps = $caps->{'caps'}; }
    my $min = undef;
    foreach my $bit (keys %LJ::CAP) {
        next unless ($caps & (1 << $bit));
        my $v = $LJ::CAP{$bit}->{$cname};
        next unless (defined $v);
        next if (defined $min && $min < $v);
        $min = $v;
    }
    return defined $min ? $min : $LJ::CAP_DEF{$cname};
}

# <LJFUNC>
# name: LJ::are_hooks
# des: Returns true if the site has one or more hooks installed for
#      the given hookname.
# args: hookname
# </LJFUNC>
sub are_hooks
{
    my $hookname = shift;
    return defined $LJ::HOOKS{$hookname};
}

# <LJFUNC>
# name: LJ::clear_hooks
# des: Removes all hooks.
# </LJFUNC>
sub clear_hooks
{
    %LJ::HOOKS = ();
}

# <LJFUNC>
# name: LJ::run_hooks
# des: Runs all the site-specific hooks of the given name.
# returns: list of arrayrefs, one for each hook ran, their
#          contents being their own return values.
# args: hookname, args*
# des-args: Arguments to be passed to hook.
# </LJFUNC>
sub run_hooks
{
    my ($hookname, @args) = @_;
    my @ret;
    foreach my $hook (@{$LJ::HOOKS{$hookname} || []}) {
        push @ret, [ $hook->(@args) ];
    }
    return @ret;
}

# <LJFUNC>
# name: LJ::run_hook
# des: Runs single site-specific hook of the given name.
# returns: return value from hook
# args: hookname, args*
# des-args: Arguments to be passed to hook.
# </LJFUNC>
sub run_hook
{
    my ($hookname, @args) = @_;
    return undef unless @{$LJ::HOOKS{$hookname} || []};
    return $LJ::HOOKS{$hookname}->[0]->(@args);
    return undef;
}

# <LJFUNC>
# name: LJ::register_hook
# des: Installs a site-specific hook.
# info: Installing multiple hooks per hookname is valid.
#       They're run later in the order they're registered.
# args: hookname, subref
# des-subref: Subroutine reference to run later.
# </LJFUNC>
sub register_hook
{
    my $hookname = shift;
    my $subref = shift;
    push @{$LJ::HOOKS{$hookname}}, $subref;
}

# <LJFUNC>
# name: LJ::register_setter
# des: Installs code to run for the "set" command in the console.
# info: Setters can be general or site-specific.
# args: key, subref
# des-key: Key to set.
# des-subref: Subroutine reference to run later.
# </LJFUNC>
sub register_setter
{
    my $key = shift;
    my $subref = shift;
    $LJ::SETTER{$key} = $subref;
}

register_setter("newpost_minsecurity", sub {
    my ($dba, $u, $remote, $key, $value, $err) = @_;
    unless ($value =~ /^(public|friends|private)$/) {
        $$err = "Illegal value.  Must be 'public', 'friends', or 'private'";
        return 0;
    }
    # Don't let commmunities be private
    if ($u->{'journaltype'} eq "C" && $value eq "private") {
        $$err = "newpost_minsecurity cannot be private for communities";
        return 0;
    }
    $value = "" if $value eq "public";
    LJ::set_userprop($u, "newpost_minsecurity", $value);
    return 1;
});

register_setter("stylesys", sub {
    my ($dba, $u, $remote, $key, $value, $err) = @_;
    unless ($value =~ /^[sS]?(1|2)$/) {
        $$err = "Illegal value.  Must be S1 or S2.";
        return 0;
    }
    $value = $1 + 0;
    LJ::set_userprop($u, "stylesys", $value);
    return 1;
});


# <LJFUNC>
# name: LJ::make_auth_code
# des: Makes a random string of characters of a given length.
# returns: string of random characters, from an alphabet of 30
#          letters & numbers which aren't easily confused.
# args: length
# des-length: length of auth code to return
# </LJFUNC>
sub make_auth_code
{
    my $length = shift;
    my $digits = "abcdefghjkmnpqrstvwxyz23456789";
    my $auth;
    for (1..$length) { $auth .= substr($digits, int(rand(30)), 1); }
    return $auth;
}

# <LJFUNC>
# name: LJ::acid_encode
# des: Given a decimal number, returns base 30 encoding
#      using an alphabet of letters & numbers that are
#      not easily mistaken for each other.
# returns: Base 30 encoding, alwyas 7 characters long.
# args: number
# des-number: Number to encode in base 30.
# </LJFUNC>
sub acid_encode
{
    my $num = shift;
    my $acid = "";
    my $digits = "abcdefghjkmnpqrstvwxyz23456789";
    while ($num) {
        my $dig = $num % 30;
        $acid = substr($digits, $dig, 1) . $acid;
        $num = ($num - $dig) / 30;
    }
    return ("a"x(7-length($acid)) . $acid);
}

# <LJFUNC>
# name: LJ::acid_decode
# des: Given an acid encoding from [func[LJ::acid_encode]],
#      returns the original decimal number.
# returns: Integer.
# args: acid
# des-acid: base 30 number from [func[LJ::acid_encode]].
# </LJFUNC>
sub acid_decode
{
    my $acid = shift;
    $acid = lc($acid);
    my %val;
    my $digits = "abcdefghjkmnpqrstvwxyz23456789";
    for (0..30) { $val{substr($digits,$_,1)} = $_; }
    my $num = 0;
    my $place = 0;
    while ($acid) {
        return 0 unless ($acid =~ s/[$digits]$//o);
        $num += $val{$&} * (30 ** $place++);
    }
    return $num;
}

# <LJFUNC>
# name: LJ::acct_code_generate
# des: Creates invitation code(s) from an optional userid
#      for use by anybody.
# returns: Code generated (if quantity 1),
#          number of codes generated (if quantity>1),
#          or undef on failure.
# args: dbarg?, userid?, quantity?
# des-userid: Userid to make the invitation code from,
#             else the code will be from userid 0 (system)
# des-quantity: Number of codes to generate (default 1)
# </LJFUNC>
sub acct_code_generate
{
    &nodb;
    my $userid = int(shift);
    my $quantity = shift || 1;

    my $dbh = LJ::get_db_writer();

    my @authcodes = map {LJ::make_auth_code(5)} 1..$quantity;
    my @values = map {"(NULL, $userid, 0, '$_')"} @authcodes;
    my $sql = "INSERT INTO acctcode (acid, userid, rcptid, auth) "
            . "VALUES " . join(",", @values);
    my $num_rows = $dbh->do($sql) or return undef;

    if ($quantity == 1) {
	my $acid = $dbh->{'mysql_insertid'} or return undef;
	return acct_code_encode($acid, $authcodes[0]);
    } else {
        return $num_rows;
    }
}

# <LJFUNC>
# name: LJ::acct_code_encode
# des: Given an account ID integer and a 5 digit auth code, returns
#      a 12 digit account code.
# returns: 12 digit account code.
# args: acid, auth
# des-acid: account ID, a 4 byte unsigned integer
# des-auth: 5 random characters from base 30 alphabet.
# </LJFUNC>
sub acct_code_encode
{
    my $acid = shift;
    my $auth = shift;
    return lc($auth) . acid_encode($acid);
}

# <LJFUNC>
# name: LJ::acct_code_decode
# des: Breaks an account code down into its two parts
# returns: list of (account ID, auth code)
# args: code
# des-code: 12 digit account code
# </LJFUNC>
sub acct_code_decode
{
    my $code = shift;
    return (acid_decode(substr($code, 5, 7)), lc(substr($code, 0, 5)));
}

# <LJFUNC>
# name: LJ::acct_code_check
# des: Checks the validity of a given account code
# returns: boolean; 0 on failure, 1 on validity. sets $$err on failure.
# args: dbarg?, code, err?, userid?
# des-code: account code to check
# des-err: optional scalar ref to put error message into on failure
# des-userid: optional userid which is allowed in the rcptid field,
#             to allow for htdocs/create.bml case when people double
#             click the submit button.
# </LJFUNC>
sub acct_code_check
{
    &nodb;
    my $code = shift;
    my $err = shift;     # optional; scalar ref
    my $userid = shift;  # optional; acceptable userid (double-click proof)

    my $dbh = LJ::get_db_writer();

    unless (length($code) == 12) {
        $$err = "Malformed code; not 12 characters.";
        return 0;
    }

    my ($acid, $auth) = acct_code_decode($code);

    my $ac = $dbh->selectrow_hashref("SELECT userid, rcptid, auth ".
                                     "FROM acctcode WHERE acid=?", 
                                     undef, $acid);

    unless ($ac && $ac->{'auth'} eq $auth) {
        $$err = "Invalid account code.";
        return 0;
    }

    if ($ac->{'rcptid'} && $ac->{'rcptid'} != $userid) {
        $$err = "This code has already been used.";
        return 0;
    }

    # is the journal this code came from suspended?
    my $u = LJ::load_userid($ac->{'userid'});
    if ($u && $u->{'statusvis'} eq "S") {
        $$err = "Code belongs to a suspended account.";
        return 0;
    }

    return 1;
}

# <LJFUNC>
# name: LJ::load_mood_theme
# des: Loads and caches a mood theme, or returns immediately if already loaded.
# args: dbarg?, themeid
# des-themeid: the mood theme ID to load
# </LJFUNC>
sub load_mood_theme
{
    &nodb;
    my $themeid = shift;
    return if $LJ::CACHE_MOOD_THEME{$themeid};
    return unless $themeid;

    # check memcache
    my $memkey = [$themeid, "moodthemedata:$themeid"];
    return if $LJ::CACHE_MOOD_THEME{$themeid} = LJ::MemCache::get($memkey);

    # fall back to db
    my $dbh = LJ::get_db_writer();
    my $sth = $dbh->prepare("SELECT moodid, picurl, width, height FROM moodthemedata WHERE moodthemeid=?");
    $sth->execute($themeid);
    while (my ($id, $pic, $w, $h) = $sth->fetchrow_array) {
        $LJ::CACHE_MOOD_THEME{$themeid}->{$id} = { 'pic' => $pic, 'w' => $w, 'h' => $h };
    }

    # set in memcache
    LJ::MemCache::set($memkey, $LJ::CACHE_MOOD_THEME{$themeid});
}

# <LJFUNC>
# name: LJ::load_props
# des: Loads and caches one or more of the various *proplist tables:
#      logproplist, talkproplist, and userproplist, which describe
#      the various meta-data that can be stored on log (journal) items,
#      comments, and users, respectively.
# args: dbarg?, table*
# des-table: a list of tables' proplists to load.  can be one of
#            "log", "talk", "user", or "rate"
# </LJFUNC>
sub load_props
{
    my $dbarg = ref $_[0] ? shift : undef;
    my @tables = @_;
    my $dbr;
    my %keyname = qw(log  propid
                     talk tpropid
                     user upropid
                     rate rlid
                     );

    foreach my $t (@tables) {
        next unless defined $keyname{$t};
        next if defined $LJ::CACHE_PROP{$t};
        my $tablename = $t eq "rate" ? "ratelist" : "${t}proplist";
        $dbr ||= LJ::get_db_reader();
        my $sth = $dbr->prepare("SELECT * FROM $tablename");
        $sth->execute;
        while (my $p = $sth->fetchrow_hashref) {
            $p->{'id'} = $p->{$keyname{$t}};
            $LJ::CACHE_PROP{$t}->{$p->{'name'}} = $p;
            $LJ::CACHE_PROPID{$t}->{$p->{'id'}} = $p;
        }
    }
}

# <LJFUNC>
# name: LJ::get_prop
# des: This is used to retrieve
#      a hashref of a row from the given tablename's proplist table.
#      One difference from getting it straight from the database is
#      that the 'id' key is always present, as a copy of the real
#      proplist unique id for that table.
# args: table, name
# returns: hashref of proplist row from db
# des-table: the tables to get a proplist hashref from.  can be one of
#            "log", "talk", or "user".
# des-name: the name of the prop to get the hashref of.
# </LJFUNC>
sub get_prop
{
    my $table = shift;
    my $name = shift;
    unless (defined $LJ::CACHE_PROP{$table}) {
        LJ::load_props($table);
        return undef unless $LJ::CACHE_PROP{$table};
    }
    return $LJ::CACHE_PROP{$table}->{$name};
}

# <LJFUNC>
# name: LJ::load_codes
# des: Populates hashrefs with lookup data from the database or from memory,
#      if already loaded in the past.  Examples of such lookup data include
#      state codes, country codes, color name/value mappings, etc.
# args: dbarg?, whatwhere
# des-whatwhere: a hashref with keys being the code types you want to load
#                and their associated values being hashrefs to where you
#                want that data to be populated.
# </LJFUNC>
sub load_codes
{
    &nodb;
    my $req = shift;

    my $dbr = LJ::get_db_reader();

    foreach my $type (keys %{$req})
    {
        my $memkey = "load_codes:$type";
        unless ($LJ::CACHE_CODES{$type} ||= LJ::MemCache::get($memkey))
        {
            $LJ::CACHE_CODES{$type} = [];
            my $sth = $dbr->prepare("SELECT code, item, sortorder FROM codes WHERE type=?");
            $sth->execute($type);
            while (my ($code, $item, $sortorder) = $sth->fetchrow_array)
            {
                push @{$LJ::CACHE_CODES{$type}}, [ $code, $item, $sortorder ];
            }
            @{$LJ::CACHE_CODES{$type}} =
                sort { $a->[2] <=> $b->[2] } @{$LJ::CACHE_CODES{$type}};
            LJ::MemCache::set($memkey, $LJ::CACHE_CODES{$type}, 60*15);
        }

        foreach my $it (@{$LJ::CACHE_CODES{$type}})
        {
            if (ref $req->{$type} eq "HASH") {
                $req->{$type}->{$it->[0]} = $it->[1];
            } elsif (ref $req->{$type} eq "ARRAY") {
                push @{$req->{$type}}, { 'code' => $it->[0], 'item' => $it->[1] };
            }
        }
    }
}

# <LJFUNC>
# name: LJ::load_user_props
# des: Given a user hashref, loads the values of the given named properties
#      into that user hashref.
# args: dbarg?, u, opts?, propname*
# des-opts: hashref of opts.  set key 'cache' to use memcache.
# des-propname: the name of a property from the userproplist table.
# </LJFUNC>
sub load_user_props
{
    &nodb;

    my $u = shift;
    return unless ref $u eq "HASH";
    return if $u->{'statusvis'} eq "X";

    my $opts = ref $_[0] ? shift : {};
    my (@props) = @_;

    my ($sql, $sth);
    LJ::load_props("user");

    ## user reference
    my $uid = $u->{'userid'}+0;
    $uid = LJ::get_userid($u->{'user'}) unless $uid;
    
    my $mem = {};
    my $use_master = 0;
    my $used_slave = 0;  # set later if we ended up using a slave

    if (@LJ::MEMCACHE_SERVERS) {
        my @keys;
        foreach (@props) {
            next if exists $u->{$_};
            my $p = LJ::get_prop("user", $_);
            next unless $p;
            push @keys, [$uid,"uprop:$uid:$p->{'id'}"];
        }
        $mem = LJ::MemCache::get_multi(@keys) || {};
        $use_master = 1;
    }
    
    $use_master = 1 if $opts->{'use_master'};

    my @needwrite;  # [propid, propname] entries we need to save to memcache later

    my %loadfrom;
    unless (@props) {
        # case 1: load all props for a given user.
        $loadfrom{'userprop'} = 1;
        $loadfrom{'userproplite'} = 1;
        $loadfrom{'userproplite2'} = 1;
        $loadfrom{'userpropblob'} = 1;
    } else {
        # case 2: load only certain things
        foreach (@props) {
            next if exists $u->{$_};
            my $p = LJ::get_prop("user", $_);
            next unless $p;
            if (defined $mem->{"uprop:$uid:$p->{'id'}"}) {
                $u->{$_} = $mem->{"uprop:$uid:$p->{'id'}"};
                next;
            }
            push @needwrite, [ $p->{'id'}, $_ ];
            my $source = $p->{'indexed'} ? "userprop" : "userproplite";
            if ($p->{datatype} eq 'blobchar') {
                $source = "userpropblob"; # clustered blob
            }
            elsif ($p->{'cldversion'} && $u->{'dversion'} >= $p->{'cldversion'}) {
                $source = "userproplite2";  # clustered
            }
            push @{$loadfrom{$source}}, $p->{'id'};
        }
    }

    foreach my $table (keys %loadfrom) {
        my $db;
        if ($use_master) {
            $db = ($table =~ m{userprop(lite2|blob)}) ? 
                LJ::get_cluster_master($u) : 
                LJ::get_db_writer();
        }
        unless ($db) {
            $db = ($table =~ m{userprop(lite2|blob)}) ?
                LJ::get_cluster_reader($u) : 
                LJ::get_db_reader();
            $used_slave = 1;
        }
        $sql = "SELECT upropid, value FROM $table WHERE userid=$uid";
        if (ref $loadfrom{$table}) {
            $sql .= " AND upropid IN (" . join(",", @{$loadfrom{$table}}) . ")";
        }
        $sth = $db->prepare($sql);
        $sth->execute;
        while (my ($id, $v) = $sth->fetchrow_array) {
            $u->{$LJ::CACHE_PROPID{'user'}->{$id}->{'name'}} = $v;
        }
    }

    # Add defaults to user object.

    # defaults for S1 style IDs in config file are magic: really 
    # uniq strings representing style IDs, so on first use, we need
    # to map them
    unless ($LJ::CACHED_S1IDMAP) {

        my $pubsty = LJ::S1::get_public_styles();
        foreach (values %$pubsty) {
            my $k = "s1_$_->{'type'}_style";
            next unless $LJ::USERPROP_DEF{$k} eq "$_->{'type'}/$_->{'styledes'}";

            $LJ::USERPROP_DEF{$k} = $_->{'styleid'};
        }

	$LJ::CACHED_S1IDMAP = 1;
    }

    # If this was called with no @props, then the function tried
    # to load all metadata.  but we don't know what's missing, so
    # try to apply all defaults.
    unless (@props) { @props = keys %LJ::USERPROP_DEF; }

    foreach my $prop (@props) {
        next if (defined $u->{$prop});
        $u->{$prop} = $LJ::USERPROP_DEF{$prop};
    }

    unless ($used_slave) {
        my $expire = time() + 3600*24;
        foreach my $wr (@needwrite) {
            my ($id, $name) = ($wr->[0], $wr->[1]);
            LJ::MemCache::set([$uid,"uprop:$uid:$id"], $u->{$name} || "", $expire);
        }
    }
}

# <LJFUNC>
# name: LJ::debug
# des: When $LJ::DEBUG is set, logs the given message to
#      the Apache error log.  Or, if $LJ::DEBUG is 2, then
#      prints to STDOUT.
# returns: 1 if logging disabled, 0 on failure to open log, 1 otherwise
# args: message
# des-message: Message to log.
# </LJFUNC>
sub debug
{
    return 1 unless ($LJ::DEBUG);
    if ($LJ::DEBUG == 2) {
        print $_[0], "\n";
        return 1;
    }
    my $r = Apache->request;
    return 0 unless $r;
    $r->log_error($_[0]);
    return 1;
}

# <LJFUNC>
# name: LJ::auth_okay
# des: Validates a user's password.  The "clear" or "md5" argument
#      must be present, and either the "actual" argument (the correct
#      password) must be set, or the first argument must be a user
#      object ($u) with the 'password' key set.  Note that this is
#      the preferred way to validate a password (as opposed to doing
#      it by hand) since this function will use a pluggable authenticator
#      if one is defined, so LiveJournal installations can be based
#      off an LDAP server, for example.
# returns: boolean; 1 if authentication succeeded, 0 on failure
# args: u, clear, md5, actual?, ip_banned?
# des-clear: Clear text password the client is sending. (need this or md5)
# des-md5: MD5 of the password the client is sending. (need this or clear).
#          If this value instead of clear, clear can be anything, as md5
#          validation will take precedence.
# des-actual: The actual password for the user.  Ignored if a pluggable
#             authenticator is being used.  Required unless the first
#             argument is a user object instead of a username scalar.
# des-ip_banned: Optional scalar ref which this function will set to true
#                if IP address of remote user is banned.
# </LJFUNC>
sub auth_okay
{
    my $u = shift;
    my $clear = shift;
    my $md5 = shift;
    my $actual = shift;
    my $ip_banned = shift;
    return 0 unless ref $u eq "HASH";

    $actual ||= $u->{'password'};
    my $user = $u->{'user'};
    
    # set the IP banned flag, if it was provided.
    my $fake_scalar;
    my $ref = ref $ip_banned ? $ip_banned : \$fake_scalar;
    if (LJ::login_ip_banned($u)) {
        $$ref = 1;
        return 0;
    } else {
        $$ref = 0;
    }

    my $bad_login = sub {
        LJ::handle_bad_login($u);
        return 0;
    };

    ## custom authorization:
    if (ref $LJ::AUTH_CHECK eq "CODE") {
        my $type = $md5 ? "md5" : "clear";
        my $try = $md5 || $clear;
        my $good = $LJ::AUTH_CHECK->($user, $try, $type);
        return $good || $bad_login->();
    }

    ## LJ default authorization:   
    return $bad_login->() unless $actual;
    return 1 if ($md5 && lc($md5) eq LJ::hash_password($actual));
    return 1 if ($clear eq $actual);
    return $bad_login->();
}


# Create a challenge token for secure logins
sub challenge_generate
{
    my $goodfor = shift || 60;
    my ($stime, $secret) = LJ::get_secret();

    # challenge version, secret time, secret age, time in secs token is good for, random chars.
    my $s_age = time() - $stime;
    my $chalbare = "c0:$stime:$s_age:$goodfor:" . LJ::rand_chars(20);
    my $chalsig = Digest::MD5::md5_hex($chalbare . $secret);
    my $chal = "$chalbare:$chalsig";

    return $chal;
}

# Validate login/talk md5 responses.
# Return 1 on valid, 0 on invalid.
sub challenge_check
{
    my ($u, $chal, $res, $banned) = @_;
    return 0 unless $u;
    my $pass = $u->{'password'};

    # set the IP banned flag, if it was provided.
    my $fake_scalar;
    my $ref = ref $banned ? $banned : \$fake_scalar;
    if (LJ::login_ip_banned($u)) {
        $$ref = 1;
        return 0;
    } else {
        $$ref = 0;
    }

    my ($c_ver, $stime, $s_age, $goodfor, $rand, $chalsig) = split /:/, $chal;
    my $secret = LJ::get_secret($stime);
    my $chalbare = "$c_ver:$stime:$s_age:$goodfor:$rand";

    # Validate token
    return 0 unless $c_ver eq 'c0'; # wrong version
    return 0 unless time() - ($stime + $s_age) < $goodfor; # expired
    return 0 unless Digest::MD5::md5_hex($chalbare . $secret) eq $chalsig;

    # Check for token dups
    my $good;
    if (@LJ::MEMCACHE_SERVERS) {
        $good = LJ::MemCache::add("chaltoken:$chal", 1, $goodfor);
    } else {
        my $dbh = LJ::get_db_writer();
        my $rv = $dbh->do("SELECT GET_LOCK(?,5)", undef, $chal);
        return 0 unless $rv;
        if (! $dbh->selectrow_array("SELECT challenge FROM challenges WHERE challenge=?",
                                     undef, $chal)) {
            $dbh->do("INSERT INTO challenges SET ctime=?, challenge=?",
                      undef, $stime + $s_age, $chal);
            $good = 1;
        }
        $dbh->do("SELECT RELEASE_LOCK(?)", undef, $chal);
    }
    return 0 unless $good;

    # Validate password
    my $hashed = Digest::MD5::md5_hex($chal . Digest::MD5::md5_hex($pass));
    if ($hashed eq $res) {
        return 1;
    } else {
        LJ::handle_bad_login($u);
        return 0;
    }
}


# <LJFUNC>
# name: LJ::create_account
# des: Creates a new basic account.  <b>Note:</b> This function is
#      not really too useful but should be extended to be useful so
#      htdocs/create.bml can use it, rather than doing the work itself.
# returns: integer of userid created, or 0 on failure.
# args: dbarg?, opts
# des-opts: hashref containing keys 'user', 'name', and 'password'
# </LJFUNC>
sub create_account
{
    &nodb;
    my $o = shift;

    my $user = LJ::canonical_username($o->{'user'});
    unless ($user)  {
        return 0;
    }

    my $dbh = LJ::get_db_writer();
    my $quser = $dbh->quote($user);
    my $cluster = defined $o->{'cluster'} ? $o->{'cluster'} : LJ::new_account_cluster();
    my $caps = $o->{'caps'} || $LJ::NEWUSER_CAPS;

    # new non-clustered accounts aren't supported anymore
    return 0 unless $cluster;

    $dbh->do("INSERT INTO user (user, name, password, clusterid, dversion, caps) ".
             "VALUES ($quser, ?, ?, ?, $LJ::MAX_DVERSION, ?)", undef,
             $o->{'name'}, $o->{'password'}, $cluster, $caps);
    return 0 if $dbh->err;

    my $userid = $dbh->{'mysql_insertid'};
    return 0 unless $userid;

    $dbh->do("INSERT INTO useridmap (userid, user) VALUES ($userid, $quser)");
    $dbh->do("INSERT INTO userusage (userid, timecreate) VALUES ($userid, NOW())");

    LJ::run_hooks("post_create", {
        'userid' => $userid,
        'user' => $user,
        'code' => undef,
    });
    return $userid;
}

# <LJFUNC>
# name: LJ::new_account_cluster
# des: Which cluster to put a new account on.  $DEFAULT_CLUSTER if it's
#      a scalar, random element from @$DEFAULT_CLUSTER if it's arrayref.
# returns: clusterid where the new account should be created
# </LJFUNC>
sub new_account_cluster
{
    return (ref $LJ::DEFAULT_CLUSTER
            ? $LJ::DEFAULT_CLUSTER->[int rand scalar @$LJ::DEFAULT_CLUSTER]
            : $LJ::DEFAULT_CLUSTER+0);
}

# <LJFUNC>
# name: LJ::is_friend
# des: Checks to see if a user is a friend of another user.
# returns: boolean; 1 if user B is a friend of user A or if A == B
# args: usera, userb
# des-usera: Source user hashref or userid.
# des-userb: Destination user hashref or userid. (can be undef)
# </LJFUNC>
sub is_friend
{
    &nodb;
    my $ua = shift;
    my $ub = shift;

    my $uaid = (ref $ua ? $ua->{'userid'} : $ua)+0;
    my $ubid = (ref $ub ? $ub->{'userid'} : $ub)+0;

    return 0 unless $uaid;
    return 0 unless $ubid;
    return 1 if ($uaid == $ubid);

    my $dbr = LJ::get_db_reader();
    return $dbr->selectrow_array("SELECT COUNT(*) FROM friends WHERE ".
                                 "userid=$uaid AND friendid=$ubid");
}

# <LJFUNC>
# name: LJ::is_banned
# des: Checks to see if a user is banned from a journal.
# returns: boolean; 1 iff user B is banned from journal A
# args: user, journal
# des-user: User hashref or userid.
# des-journal: Journal hashref or userid.
# </LJFUNC>
sub is_banned
{
    &nodb;
    my $u = shift;
    my $j = shift;

    my $uid = (ref $u ? $u->{'userid'} : $u)+0;
    my $jid = (ref $j ? $j->{'userid'} : $j)+0;

    return 1 unless $uid;
    return 1 unless $jid;

    # for speed: common case is non-community posting and replies
    # in own journal.  avoid db hit.
    return 0 if ($uid == $jid);

    return LJ::check_rel($jid, $uid, 'B');
}

# <LJFUNC>
# name: LJ::can_view
# des: Checks to see if the remote user can view a given journal entry.
#      <b>Note:</b> This is meant for use on single entries at a time,
#      not for calling many times on every entry in a journal.
# returns: boolean; 1 if remote user can see item
# args: remote, item
# des-item: Hashref from the 'log' table.
# </LJFUNC>
sub can_view
{
    &nodb;
    my $remote = shift;
    my $item = shift;

    # public is okay
    return 1 if ($item->{'security'} eq "public");

    # must be logged in otherwise
    return 0 unless $remote;

    my $userid = int($item->{'ownerid'} || $item->{'journalid'});
    my $remoteid = int($remote->{'userid'});

    # owners can always see their own.
    return 1 if ($userid == $remoteid);

    # other people can't read private
    return 0 if ($item->{'security'} eq "private");

    # should be 'usemask' security from here out, otherwise
    # assume it's something new and return 0
    return 0 unless ($item->{'security'} eq "usemask");

    # usemask
    my $dbr = LJ::get_db_reader();

    # if it's usemask, we have to refuse non-personal journals,
    # so we have to load the user
    return 0 unless $remote->{'journaltype'} eq 'P';

    my $gmask = $dbr->selectrow_array("SELECT groupmask FROM friends WHERE ".
                                      "userid=$userid AND friendid=$remoteid");
    my $allowed = (int($gmask) & int($item->{'allowmask'}));
    return $allowed ? 1 : 0;  # no need to return matching mask
}

# <LJFUNC>
# name: LJ::get_logtext2
# des: Efficiently retrieves a large number of journal entry text, trying first
#      slave database servers for recent items, then the master in
#      cases of old items the slaves have already disposed of.  See also:
#      [func[LJ::get_talktext2]].
# args: u, opts?, jitemid*
# returns: hashref with keys being jitemids, values being [ $subject, $body ]
# des-opts: Optional hashref of special options.  Currently only 'usemaster'
#           key is supported, which always returns a definitive copy,
#           and not from a cache or slave database.
# des-jitemid: List of jitemids to retrieve the subject & text for.
# </LJFUNC>
sub get_logtext2
{
    my $u = shift;
    my $clusterid = $u->{'clusterid'};
    my $journalid = $u->{'userid'}+0;

    my $opts = ref $_[0] ? shift : {};

    # return structure.
    my $lt = {};
    return $lt unless $clusterid;

    # keep track of itemids we still need to load.
    my %need;
    my @mem_keys;
    foreach (@_) { 
        my $id = $_+0;
        $need{$id} = 1;
        push @mem_keys, [$journalid,"logtext:$clusterid:$journalid:$id"];
    }

    # pass 0: memory, avoiding databases
    unless ($opts->{'usemaster'}) {
        my $mem = LJ::MemCache::get_multi(@mem_keys) || {};
        while (my ($k, $v) = each %$mem) {
            next unless $v;
            $k =~ /:(\d+):(\d+):(\d+)/;
            delete $need{$3};
            $lt->{$3} = $v;
        }
    }

    return $lt unless %need;

    # pass 1 (slave) and pass 2 (master)
    foreach my $pass (1, 2) {
        next unless %need;
        next if $pass == 1 && $opts->{'usemaster'};
        my $db = $pass == 1 ? LJ::get_cluster_reader($clusterid) :
            LJ::get_cluster_master($clusterid);
        next unless $db;
        
        my $jitemid_in = join(", ", keys %need);
        my $sth = $db->prepare("SELECT jitemid, subject, event FROM logtext2 ".
                               "WHERE journalid=$journalid AND jitemid IN ($jitemid_in)");
        $sth->execute;
        while (my ($id, $subject, $event) = $sth->fetchrow_array) {
            LJ::text_uncompress(\$event);
            my $val = [ $subject, $event ];
            $lt->{$id} = $val;
            LJ::MemCache::add([$journalid,"logtext:$clusterid:$journalid:$id"], $val);
            delete $need{$id};
        }
    }
    return $lt;
}

# <LJFUNC>
# name: LJ::get_talktext2
# des: Retrieves comment text. Tries slave servers first, then master.
# info: Efficiently retreives batches of comment text. Will try alternate
#       servers first. See also [func[LJ::get_logtext2]].
# returns: Hashref with the talkids as keys, values being [ $subject, $event ].
# args: u, opts?, jtalkids
# des-opts: A hashref of options. 'onlysubjects' will only retrieve subjects.
# des-jtalkids: A list of talkids to get text for.
# </LJFUNC>
sub get_talktext2
{
    my $u = shift;
    my $clusterid = $u->{'clusterid'};
    my $journalid = $u->{'userid'}+0;

    my $opts = ref $_[0] ? shift : {};

    # return structure.
    my $lt = {};
    return $lt unless $clusterid;

    # keep track of itemids we still need to load.
    my %need;
    my @mem_keys;
    foreach (@_) {
        my $id = $_+0;
        $need{$id} = 1;
        push @mem_keys, [$journalid,"talksubject:$clusterid:$journalid:$id"];
        unless ($opts->{'onlysubjects'}) {
            push @mem_keys, [$journalid,"talkbody:$clusterid:$journalid:$id"];
        }
    }

    # try the memory cache
    my $mem = LJ::MemCache::get_multi(@mem_keys) || {};
    while (my ($k, $v) = each %$mem) {
        $k =~ /^talk(.*):(\d+):(\d+):(\d+)/;
        if ($opts->{'onlysubjects'} && $1 eq "subject") {
            delete $need{$4};
            $lt->{$4} = [ $v ];
        }
        if (! $opts->{'onlysubjects'} && $1 eq "body" &&
            exists $mem->{"talksubject:$2:$3:$4"}) {
            delete $need{$4};
            $lt->{$4} = [ $mem->{"talksubject:$2:$3:$4"}, $v ];
        }
    }
    return $lt unless %need;
    
    my $bodycol = $opts->{'onlysubjects'} ? "" : ", body";

    # pass 1 (slave) and pass 2 (master)
    foreach my $pass (1, 2) {
        next unless %need;
        my $db = $pass == 1 ? LJ::get_cluster_reader($clusterid) :
            LJ::get_cluster_master($clusterid);
        next unless $db;
        my $in = join(",", keys %need);
        my $sth = $db->prepare("SELECT jtalkid, subject $bodycol FROM talktext2 ".
                               "WHERE journalid=$journalid AND jtalkid IN ($in)");
        $sth->execute;
        while (my ($id, $subject, $body) = $sth->fetchrow_array) {
            LJ::text_uncompress(\$body);
            $lt->{$id} = [ $subject, $body ];
            LJ::MemCache::add([$journalid,"talkbody:$clusterid:$journalid:$id"], $body)
                unless $opts->{'onlysubjects'};
            LJ::MemCache::add([$journalid,"talksubject:$clusterid:$journalid:$id"], $subject);
            delete $need{$id};
        }
    }
    return $lt;
}

# <LJFUNC>
# name: LJ::get_logtext2multi
# des: Gets log text from clusters.
# info: Fetches log text from clusters. Trying slaves first if available.
# returns: hashref with keys being "jid jitemid", values being [ $subject, $body ]
# args: idsbyc
# des-idsbyc: A hashref where the key is the clusterid, and the data
#             is an arrayref of [ ownerid, itemid ] array references.
# </LJFUNC>
sub get_logtext2multi
{
    &nodb;
    return _get_posts_raw_wrapper(shift, "text");
}

# this function is used to translate the old get_logtext2multi and load_log_props2multi
# functions into using the new get_posts_raw.  eventually, the above functions should
# be taken out of the rest of the code, at which point this function can also die.
sub _get_posts_raw_wrapper {
    # args:
    #   { cid => [ [jid, jitemid]+ ] }
    #   "text" or "props"
    #   optional hashref to put return value in.  (see get_logtext2multi docs)
    # returns: that hashref.
    my ($idsbyc, $type, $ret) = @_;

    my $opts = {};
    if ($type eq 'text') {
        $opts->{text_only} = 1;
    } elsif ($type eq 'prop') {
        $opts->{prop_only} = 1;
    } else {
        return undef;
    }

    my @postids;
    while (my ($cid, $ids) = each %$idsbyc) {
        foreach my $pair (@$ids) {
            push @postids, [ $cid, $pair->[0], $pair->[1] ];
        }
    }
    my $rawposts = LJ::get_posts_raw($opts, @postids);
    
    # add replycounts fields to props
    if ($type eq "prop") {
        while (my ($k, $v) = each %{$rawposts->{"replycount"}||{}}) {
            $rawposts->{prop}{$k}{replycount} = $rawposts->{replycount}{$k};
        }
    }

    # translate colon-separated (new) to space-separated (old) keys.
    $ret ||= {};
    while (my ($id, $data) = each %{$rawposts->{$type}}) {
        $id =~ s/:/ /;
        $ret->{$id} = $data;
    }
    return $ret;
}

# <LJFUNC>
# name: LJ::get_posts_raw
# des: Gets raw post data (text and props) efficiently from clusters.
# info: Fetches posts from clusters, trying memcache and slaves first if available.
# returns: hashref with keys 'text', 'prop', or 'replycount', and values being
#          hashrefs with keys "jid:jitemid".  values of that are as follows:
#          text: [ $subject, $body ], props: { ... }, and replycount: scalar
# args: opts?, id+
# des-opts: An optional hashref of options:
#            - memcache_only:  Don't fall back on the database.
#            - text_only:  Retrieve only text, no props (used to support old API).
#            - prop_only:  Retrieve only props, no text (used to support old API).
# des-id: An arrayref of [ clusterid, ownerid, itemid ].
# </LJFUNC>
sub get_posts_raw
{
    my $opts = ref $_[0] eq "HASH" ? shift : {};
    my $ret = {};
    my $sth;

    LJ::load_props('log') unless $opts->{text_only};

    # throughout this function, the concept of an "id"
    # is the key to identify a single post.
    # it is of the form "$jid:$jitemid".

    # build up a list for each cluster of what we want to get,
    # as well as a list of all the keys we want from memcache.
    my %cids;      # cid => 1
    my $needtext;  # text needed:  $cid => $id => 1
    my $needprop;  # props needed: $cid => $id => 1
    my $needrc;    # replycounts needed: $cid => $id => 1
    my @mem_keys;

    # if we're loading entries for a friends page,
    # silently failing to load a cluster is acceptable.
    # but for a single user, we want to die loudly so they don't think
    # we just lost their journal.
    my $single_user;

    # because the memcache keys for logprop don't contain
    # which cluster they're in, we also need a map to get the
    # cid back from the jid so we can insert into the needfoo hashes.
    # the alternative is to not key the needfoo hashes on cluster,
    # but that means we need to grep out each cluster's jids when
    # we do per-cluster queries on the databases.
    my %cidsbyjid;
    foreach my $post (@_) {
        my ($cid, $jid, $jitemid) = @{$post};
        my $id = "$jid:$jitemid";
        if (not defined $single_user) {
            $single_user = $jid;
        } elsif ($single_user and $jid != $single_user) {
            # multiple users
            $single_user = 0;
        }
        $cids{$cid} = 1;
        $cidsbyjid{$jid} = $cid;
        unless ($opts->{prop_only}) {
            $needtext->{$cid}{$id} = 1;
            push @mem_keys, [$jid,"logtext:$cid:$id"];
        }
        unless ($opts->{text_only}) {
            $needprop->{$cid}{$id} = 1;
            push @mem_keys, [$jid,"logprop:$id"];
            $needrc->{$cid}{$id} = 1;
            push @mem_keys, [$jid,"rp:$id"];
        }
    }

    # first, check memcache.
    my $mem = LJ::MemCache::get_multi(@mem_keys) || {};
    while (my ($k, $v) = each %$mem) {
        next unless defined $v;
        next unless $k =~ /(\w+):(?:\d+:)?(\d+):(\d+)/;
        my ($type, $jid, $jitemid) = ($1, $2, $3);
        my $cid = $cidsbyjid{$jid};
        my $id = "$jid:$jitemid";
        if ($type eq "logtext") {
            delete $needtext->{$cid}{$id};
            $ret->{text}{$id} = $v;
        } elsif ($type eq "logprop" && ref $v eq "HASH") {
            delete $needprop->{$cid}{$id};
            $ret->{prop}{$id} = $v;
        } elsif ($type eq "rp") {
            delete $needrc->{$cid}{$id};
            $ret->{replycount}{$id} = int($v); # remove possible spaces
        }
    }
    
    # we may be done already.
    return $ret if $opts->{memcache_only};
    return $ret unless values %$needtext or values %$needprop 
        or values %$needrc;

    # otherwise, hit the database.
    foreach my $cid (keys %cids) {
        # for each cluster, get the text/props we need from it.
        my $cneedtext = $needtext->{$cid} || {};
        my $cneedprop = $needprop->{$cid} || {};
        my $cneedrc   = $needrc->{$cid} || {};

        next unless %$cneedtext or %$cneedprop or %$cneedrc;

        my $make_in = sub {
            my @in;
            foreach my $id (@_) {
                my ($jid, $jitemid) = map { $_ + 0 } split(/:/, $id);
                push @in, "(journalid=$jid AND jitemid=$jitemid)";
            }
            return join(" OR ", @in);
        };

        # now load from each cluster.
        my $fetchtext = sub {
            my $db = shift;
            return unless %$cneedtext;
            my $in = $make_in->(keys %$cneedtext);
            $sth = $db->prepare("SELECT journalid, jitemid, subject, event ".
                                "FROM logtext2 WHERE $in");
            $sth->execute;
            while (my ($jid, $jitemid, $subject, $event) = $sth->fetchrow_array) {
                LJ::text_uncompress(\$event);
                my $id = "$jid:$jitemid";
                my $val = [ $subject, $event ];
                $ret->{text}{$id} = $val;
                LJ::MemCache::add([$jid,"logtext:$cid:$id"], $val);
                delete $cneedtext->{$id};
            }
        };

        my $fetchprop = sub {
            my $db = shift;
            return unless %$cneedprop;
            my $in = $make_in->(keys %$cneedprop);
            $sth = $db->prepare("SELECT journalid, jitemid, propid, value ".
                                "FROM logprop2 WHERE $in");
            $sth->execute;
            my %gotid;
            while (my ($jid, $jitemid, $propid, $value) = $sth->fetchrow_array) {
                my $id = "$jid:$jitemid";
                my $propname = $LJ::CACHE_PROPID{'log'}->{$propid}{name};
                $ret->{prop}{$id}{$propname} = $value;
                $gotid{$id} = 1;
            }
            foreach my $id (keys %gotid) {
                my ($jid, $jitemid) = map { $_ + 0 } split(/:/, $id);
                LJ::MemCache::add([$jid, "logprop:$id"], $ret->{prop}{$id});
                delete $cneedprop->{$id};
            }
        };

        my $fetchrc = sub {
            my $db = shift;
            return unless %$cneedrc;
            my $in = $make_in->(keys %$cneedrc);
            $sth = $db->prepare("SELECT journalid, jitemid, replycount FROM log2 WHERE $in");
            $sth->execute;
            while (my ($jid, $jitemid, $rc) = $sth->fetchrow_array) {
                my $id = "$jid:$jitemid";
                $ret->{replycount}{$id} = $rc;
                LJ::MemCache::add([$jid, "rp:$id"], $rc);
                delete $cneedrc->{$id};
            }
        };

        my $dberr = sub {
            die "Couldn't connect to database" if $single_user;
            next;
        };

        # run the fetch functions on the proper databases, with fallbacks if necessary.
        my ($dbcm, $dbcr);
        if (@LJ::MEMCACHE_SERVERS or $opts->{use_master}) {
            $dbcm ||= LJ::get_cluster_master($cid) or $dberr->();
            $fetchtext->($dbcm) if %$cneedtext;
            $fetchprop->($dbcm) if %$cneedprop;
            $fetchrc->($dbcm) if %$cneedrc;
        } else {
            $dbcr ||= LJ::get_cluster_reader($cid);
            if ($dbcr) {
                $fetchtext->($dbcr) if %$cneedtext;
                $fetchprop->($dbcr) if %$cneedprop;
                $fetchrc->($dbcr) if %$cneedrc;
            }
            # if we still need some data, switch to the master.
            if (%$cneedtext or %$cneedprop) {
                $dbcm ||= LJ::get_cluster_master($cid) or $dberr->();
                $fetchtext->($dbcm);
                $fetchprop->($dbcm);
                $fetchrc->($dbcm);
            }
        }

        # and finally, if there were no errors,
        # insert into memcache the absence of props
        # for all posts that didn't have any props.
        foreach my $id (keys %$cneedprop) {
            my ($jid, $jitemid) = map { $_ + 0 } split(/:/, $id);
            LJ::MemCache::set([$jid, "logprop:$id"], {});
        }
    }
    return $ret;
}

sub get_posts
{
    my $opts = ref $_[0] eq "HASH" ? shift : {};
    my $rawposts = get_posts_raw($opts, @_);

    # fix up posts as needed for display, following directions given in opts.


    # XXX this function is incomplete.  it should also HTML clean, etc.
    # XXX we need to load users when we have unknown8bit data, but that
    # XXX means we have to load users.
    

    while (my ($id, $rp) = each %$rawposts) {
        if ($LJ::UNICODE && $rp->{props}{unknown8bit}) {
            #LJ::item_toutf8($u, \$rp->{text}[0], \$rp->{text}[1], $rp->{props});
        }
    }

    return $rawposts;
}

# <LJFUNC>
# name: LJ::get_remote
# des: authenticates the user at the remote end based on their cookies
#      and returns a hashref representing them
# returns: hashref containing 'user' and 'userid' if valid user, else
#          undef.
# args: dbarg?, criterr?, cgi?
# des-criterr: scalar ref to set critical error flag.  if set, caller
#              should stop processing whatever it's doing and complain
#              about an invalid login with a link to the logout page.
# des-cgi: Optional CGI.pm reference if using in a script which
#          already uses CGI.pm.
# </LJFUNC>
sub get_remote
{
    my $opts = ref $_[0] eq "HASH" ? shift : {};
    my $dbarg = shift;
    my $criterr = shift;
    my $cgi = shift;

    return $LJ::CACHE_REMOTE if $LJ::CACHED_REMOTE && ! $opts->{'ignore_ip'};

    $$criterr = 0;

    my $cookie = sub {
        return $cgi ? $cgi->cookie($_[0]) : $BML::COOKIE{$_[0]};
    };

    my $sopts;
    my $validate = sub {
        my $a = shift;
        # let hooks reject credentials, or set criterr true:
        my $hookparam = {
            'user' => $a->{'user'},
            'userid' => $a->{'userid'},
            'caps' => $a->{'caps'},
            'criterr' => $criterr,
            'cookiesource' => $cookie,
            'sopts' => $sopts,
        };
        my @r = LJ::run_hooks("validate_get_remote", $hookparam);
        return undef if grep { ! $_->[0] } @r;
        return 1;
    };

    my $no_remote = sub {
        $LJ::CACHED_REMOTE = 1;
        $LJ::CACHE_REMOTE = undef;
        $validate->();
        return undef;
    };

    my $sessdata;

    # do they have any sort of session cookie?
    return $no_remote->("No session") 
        unless ($sessdata = $cookie->('ljsession'));

    
    my ($authtype, $user, $sessid, $auth, $_sopts) = split(/:/, $sessdata);
    $sopts = $_sopts;

    # fail unless authtype is 'ws' (more might be added in future)
    return $no_remote->("No ws auth") unless $authtype eq "ws";

    my $u = LJ::load_user($user);
    return $no_remote->("User doesn't exist") unless $u;

    my $sess_db;
    my $sess;
    my $get_sess = sub {
        return undef unless $sess_db;
        $sess = $sess_db->selectrow_hashref("SELECT * FROM sessions ".
                                            "WHERE userid=? AND sessid=? AND auth=?",
                                            undef, $u->{'userid'}, $sessid, $auth);
    };
    my $memkey = [$u->{'userid'},"sess:$u->{'userid'}:$sessid"];
    # try memory
    $sess = LJ::MemCache::get($memkey);
    # try master
    unless ($sess) {
        $sess_db = LJ::get_cluster_master($u);
        $get_sess->();
        LJ::MemCache::set($memkey, $sess) if $sess;
    }
    # try slave
    unless ($sess) {
        $sess_db = LJ::get_cluster_reader($u);
        $get_sess->();
    }
    return $no_remote->("Session bogus") unless $sess;
    return $no_remote->("Invalid auth") unless $sess->{'auth'} eq $auth;
    my $now = time();
    return $no_remote->("Session old") if $sess->{'timeexpire'} < $now;
    if ($sess->{'ipfixed'} && ! $opts->{'ignore_ip'}) {
        my $remote_ip = $LJ::_XFER_REMOTE_IP || LJ::get_remote_ip();
        return $no_remote->("Session wrong IP") 
            if $sess->{'ipfixed'} ne $remote_ip;
    }

    # renew short session
    my $sess_length = {
        'short' => 60*60*24*1.5,
        'long' => 60*60*24*60,
    }->{$sess->{'exptype'}};
    
    if ($sess_length && 
        $sess->{'timeexpire'} - $now < $sess_length/2) {
        my $udbh = LJ::get_cluster_master($u);
        if ($udbh) {
            my $future = $now + $sess_length;
            $udbh->do("UPDATE sessions SET timeexpire=$future WHERE ".
                      "userid=$u->{'userid'} AND sessid=$sess->{'sessid'}");
            my $dbh = LJ::get_db_writer();
            $dbh->do("UPDATE userusage SET timecheck=NOW() WHERE userid=?",
                     undef, $u->{'userid'});
            LJ::MemCache::delete($memkey);
        }
    }

    # augment hash with session data;
    $u->{'_session'} = $sess;

    $LJ::CACHED_REMOTE = 1;
    $LJ::CACHE_REMOTE = $u;

    eval {
        Apache->request->notes("ljuser" => $u->{'user'});
    };

    return $u;
}

sub set_remote
{
    my $remote = shift;
    $LJ::CACHED_REMOTE = 1;
    $LJ::CACHE_REMOTE = $remote;
    1;
}

sub load_remote
{
    # function is no longer used, since get_remote returns full objects.
    # keeping this here so we don't break people's local site code
}

# <LJFUNC>
# name: LJ::get_remote_noauth
# des: returns who the remote user says they are, but doesn't check
#      their login token.  disadvantage: insecure, only use when
#      you're not doing anything critical.  advantage:  faster.
# returns: hashref containing only key 'user', not 'userid' like
#          [func[LJ::get_remote]].
# </LJFUNC>
sub get_remote_noauth
{
    my $sess = $BML::COOKIE{'ljsession'};
    return { 'user' => $1 } if $sess =~ /^ws:(\w+):/;
    return undef;
}

# <LJFUNC>
# name: LJ::clear_caches
# des: This function is called from a HUP signal handler and is intentionally
#      very very simple (1 line) so we don't core dump on a system without
#      reentrant libraries.  It just sets a flag to clear the caches at the
#      beginning of the next request (see [func[LJ::handle_caches]]).
#      There should be no need to ever call this function directly.
# </LJFUNC>
sub clear_caches
{
    $LJ::CLEAR_CACHES = 1;
}

# <LJFUNC>
# name: LJ::handle_caches
# des: clears caches if the CLEAR_CACHES flag is set from an earlier
#      HUP signal that called [func[LJ::clear_caches]], otherwise
#      does nothing.
# returns: true (always) so you can use it in a conjunction of
#          statements in a while loop around the application like:
#          while (LJ::handle_caches() && FCGI::accept())
# </LJFUNC>
sub handle_caches
{
    return 1 unless $LJ::CLEAR_CACHES;
    $LJ::CLEAR_CACHES = 0;

    do "$ENV{'LJHOME'}/cgi-bin/ljconfig.pl";
    do "$ENV{'LJHOME'}/cgi-bin/ljdefaults.pl";

    $LJ::DBIRole->flush_cache();

    %LJ::CACHE_PROP = ();
    %LJ::CACHE_STYLE = ();
    $LJ::CACHED_MOODS = 0;
    $LJ::CACHED_MOOD_MAX = 0;
    %LJ::CACHE_MOODS = ();
    %LJ::CACHE_MOOD_THEME = ();
    %LJ::CACHE_USERID = ();
    %LJ::CACHE_USERNAME = ();
    %LJ::CACHE_CODES = ();
    %LJ::CACHE_USERPROP = ();  # {$prop}->{ 'upropid' => ... , 'indexed' => 0|1 };
    %LJ::CACHE_ENCODINGS = ();
    return 1;
}

# <LJFUNC>
# name: LJ::start_request
# des: Before a new web request is obtained, this should be called to
#      determine if process should die or keep working, clean caches,
#      reload config files, etc.
# returns: 1 if a new request is to be processed, 0 if process should die.
# </LJFUNC>
sub start_request
{
    handle_caches();
    # TODO: check process growth size

    # clear per-request caches
    $LJ::CACHE_REMOTE = undef;
    $LJ::CACHED_REMOTE = 0;
    %LJ::CACHE_USERPIC_SIZE = ();     # picid -> [width, height, userid]
    %LJ::CACHE_USERPIC_INFO = ();     # uid -> { ... }
    %LJ::REQ_CACHE_USER_NAME = ();    # users by name
    %LJ::REQ_CACHE_USER_ID = ();      # users by id
    %LJ::REQ_CACHE_REL = ();          # relations from LJ::check_rel()
    %LJ::S1::REQ_CACHE_STYLEMAP = (); # styleid -> uid mappings
    %LJ::REQ_DBIX_TRACKER = ();       # canonical dbrole -> DBIx::StateTracker
    %LJ::REQ_DBIX_KEEPER = ();        # dbrole -> DBIx::StateKeeper

    # we use this to fake out get_remote's perception of what
    # the client's remote IP is, when we transfer cookies between
    # authentication domains.  see the FotoBilder interface.
    $LJ::_XFER_REMOTE_IP = undef;

    # clear the handle request cache (like normal cache, but verified already for
    # this request to be ->ping'able).
    $LJ::DBIRole->clear_req_cache();

    # need to suck db weights down on every request (we check
    # the serial number of last db weight change on every request
    # to validate master db connection, instead of selecting
    # the connection ID... just as fast, but with a point!)
    $LJ::DBIRole->trigger_weight_reload();

    # reset BML's cookies
    eval { BML::reset_cookies() };

    # check the modtime of ljconfig.pl and reload if necessary
    # only do a stat every 10 seconds and then only reload
    # if the file has changed
    my $now = time();
    if ($now - $LJ::CACHE_CONFIG_MODTIME_LASTCHECK > 10) {
        my $modtime = (stat("$ENV{'LJHOME'}/cgi-bin/ljconfig.pl"))[9];
        if ($modtime > $LJ::CACHE_CONFIG_MODTIME) {
            # reload config and update cached modtime
            $LJ::CACHE_CONFIG_MODTIME = $modtime;
            eval { 
                do "$ENV{'LJHOME'}/cgi-bin/ljconfig.pl"; 
                do "$ENV{'LJHOME'}/cgi-bin/ljdefaults.pl"; 
            };
            $LJ::IMGPREFIX_BAK = $LJ::IMGPREFIX;
            $LJ::STATPREFIX_BAK = $LJ::STATPREFIX;
            $LJ::DBIRole->set_sources(\%LJ::DBINFO);
            LJ::MemCache::trigger_bucket_reconstruct();
            if ($modtime > $now - 60) {
                # show to stderr current reloads.  won't show
                # reloads happening from new apache children
                # forking off the parent who got the inital config loaded
                # hours/days ago and then the "updated" config which is
                # a different hours/days ago.
                print STDERR "ljconfig.pl reloaded\n";
            }
        }
        $LJ::CACHE_CONFIG_MODTIME_LASTCHECK = $now;
    }

    return 1;
}


# <LJFUNC>
# name: LJ::end_request
# des: Clears cached DB handles/trackers/keepers (if $LJ::DISCONNECT_DBS is
#      true) and disconnects MemCache handles (if $LJ::DISCONNECT_MEMCACHE is
#      true).
# </LJFUNC>
sub end_request
{
    LJ::disconnect_dbs() if $LJ::DISCONNECT_DBS;
    LJ::MemCache::disconnect_all() if $LJ::DISCONNECT_MEMCACHE;
}


# <LJFUNC>
# name: LJ::disconnect_dbs
# des: Clear cached DB handles and trackers/keepers to partitioned DBs.
# </LJFUNC>
sub disconnect_dbs {
    # clear cached handles
    $LJ::DBIRole->disconnect_all();

    # and cached trackers/keepers to partitioned dbs
    while (my ($role, $tk) = each %LJ::REQ_DBIX_TRACKER) {
        $tk->disconnect if $tk;
    }
    %LJ::REQ_DBIX_TRACKER = ();
    %LJ::REQ_DBIX_KEEPER = ();
}

# <LJFUNC>
# name: LJ::load_userpics
# des: Loads a bunch of userpic at once.
# args: dbarg?, upics, idlist
# des-upics: hashref to load pictures into, keys being the picids
# des-idlist: arrayref of picids to load
# </LJFUNC>
sub load_userpics
{
    &nodb;
    my ($upics, $idlist) = @_;

    my @load_list;
    foreach my $id (@{$idlist})
    {
        if ($LJ::CACHE_USERPIC_SIZE{$id}) {
            $upics->{$id}->{'width'} = $LJ::CACHE_USERPIC_SIZE{$id}->[0];
            $upics->{$id}->{'height'} = $LJ::CACHE_USERPIC_SIZE{$id}->[1];
            $upics->{$id}->{'userid'} = $LJ::CACHE_USERPIC_SIZE{$id}->[2];
        } elsif ($id+0) {
            push @load_list, ($id+0);
        }
    }
    return unless @load_list;

    if (@LJ::MEMCACHE_SERVERS) {
        my @mem_keys = map { [$_,"userpic.$_"] } @load_list;
        my $mem = LJ::MemCache::get_multi(@mem_keys) || {};
        while (my ($k, $v) = each %$mem) {
            next unless $v && $k =~ /(\d+)/;
            my $id = $1;
            $upics->{$id}->{'width'} = $v->[0];
            $upics->{$id}->{'height'} = $v->[1];
            $upics->{$id}->{'userid'} = $v->[2];
        }
        @load_list = grep { ! $upics->{$_} } @load_list;
        return unless @load_list;
    }

    my $dbr = LJ::get_db_reader();
    my $picid_in = join(",", @load_list);
    my $sth = $dbr->prepare("SELECT userid, picid, width, height ".
                            "FROM userpic WHERE picid IN ($picid_in)");
    $sth->execute;
    while ($_ = $sth->fetchrow_hashref) {
        my $id = $_->{'picid'};
        undef $_->{'picid'};
        $upics->{$id} = $_;
        my $val = [ $_->{'width'}, $_->{'height'}, $_->{'userid'} ];
        $LJ::CACHE_USERPIC_SIZE{$id} = $val;
        LJ::MemCache::set([$id,"userpic.$id"], $val);
    }
}

# <LJFUNC>
# name: LJ::modify_caps
# des: Given a list of caps to add and caps to remove, updates a user's caps
# args: uuid, cap_add, cap_del
# arg-cap_add: arrayref of bit numbers to turn on
# arg-cap_del: arrayref of bit numbers to turn off
# returns: updated u object, retrieved from $dbh, then 'caps' key modified
#          otherwise, returns 0 unless all  hooks run properly
# </LJFUNC>
sub modify_caps {
    my ($argu, $cap_add, $cap_del) = @_;
    my $userid = LJ::want_userid($argu);
    return unless $userid;

    $cap_add ||= [];
    $cap_del ||= [];
    my %cap_add_mod = ();
    my %cap_del_mod = ();

    # get a u object directly from the db
    my $u = LJ::load_userid($userid, "force");

    # add new caps
    my $newcaps = int($u->{'caps'});
    foreach (@$cap_add) {
        my $cap = 1 << $_;

        # about to turn bit on, is currently off?
        $cap_add_mod{$_} = 1 unless $newcaps & $cap;
        $newcaps |= $cap;
    }

    # remove deleted caps
    foreach (@$cap_del) {
        my $cap = 1 << $_;

        # about to turn bit off, is it currently on?
        $cap_del_mod{$_} = 1 if $newcaps & $cap;
        $newcaps &= ~$cap;
    }

    # run hooks for modified bits
    my $res = LJ::run_hook("modify_caps", 
                           { 'u' => $u, 
                             'newcaps' => $newcaps,
                             'oldcaps' => $u->{'caps'},
                             'cap_on_req'  => { map { $_ => 1 } @$cap_add },
                             'cap_off_req' => { map { $_ => 1 } @$cap_del },
                             'cap_on_mod'  => \%cap_add_mod,
                             'cap_off_mod' => \%cap_del_mod,
                           });

    # hook should return a status code
    return 0 if defined $res && ! $res;

    # update user row
    LJ::update_user($u, { 'caps' => $newcaps });

    return $u;
}

# <LJFUNC>
# name: LJ::activate_userpics
# des: Sets/unsets userpics as inactive based on account caps
# args: u
# returns: nothing
# </LJFUNC>
sub activate_userpics
{
    # this behavior is optional, but enabled by default
    return if $LJ::ALLOW_PICS_OVER_QUOTA;

    my $u = shift;
    return unless $u;

    # get a database handle for reading/writing
    # need to get this now so we can pass it to load_userid if necessary
    my $dbh = LJ::get_db_writer();

    # if a userid was given, get a real $u object
    $u = LJ::load_userid($u, "force") unless ref $u eq "HASH";

    # should have a $u object now
    return unless ref $u eq 'HASH';
    my $userid = $u->{'userid'};

    # active / inactive lists
    my @active = ();
    my @inactive = ();
    my $allow = LJ::get_cap($u, "userpics");

    # get database cluster reader handle
    my $dbcr = LJ::get_cluster_reader($u);
    return unless $dbcr;

    # select all userpics and build active / inactive lists
    my $sth = $dbh->prepare("SELECT picid, state FROM userpic WHERE userid=?");
    $sth->execute($userid);
    while (my ($picid, $state) = $sth->fetchrow_array) {
        if ($state eq 'I') {
            push @inactive, $picid;
        } else {
            push @active, $picid;
        }
    }  

    # inactivate previously activated userpics
    if (@active > $allow) {
        my $to_ban = @active - $allow;

        # find first jitemid greater than time 2 months ago using rlogtime index
        # ($LJ::EndOfTime - UnixTime)
        my $jitemid = $dbcr->selectrow_array("SELECT jitemid FROM log2 USE INDEX (rlogtime) " .
                                             "WHERE journalid=? AND rlogtime > ? LIMIT 1",
                                             undef, $userid, $LJ::EndOfTime - time() + 86400*60);

        # query all pickws in logprop2 with jitemid > that value
        my %count_kw = ();
        my $propid = LJ::get_prop("log", "picture_keyword")->{'id'};
        my $sth = $dbcr->prepare("SELECT value, COUNT(*) FROM logprop2 " . 
                                 "WHERE journalid=? AND jitemid > ? AND propid=?" .
                                 "GROUP BY value");
        $sth->execute($userid, $jitemid, $propid);
        while (my ($value, $ct) = $sth->fetchrow_array) {
            # keyword => count
            $count_kw{$value} = $ct;
        }

        my $keywords_in = join(",", map { $dbh->quote($_) } keys %count_kw);

        # map pickws to picids for freq hash below
        my %count_picid = ();
        if ($keywords_in) {
            my $sth = $dbh->prepare("SELECT k.keyword, m.picid FROM keywords k, userpicmap m " .
                                    "WHERE k.keyword IN ($keywords_in) AND k.kwid=m.kwid " . 
                                    "AND m.userid=?");
            $sth->execute($userid);
            while (my ($keyword, $picid) = $sth->fetchrow_array) {
                # keyword => picid
                $count_picid{$picid} += $count_kw{$keyword};
            }
        }

        # we're only going to ban the least used, excluding the user's default
        my @ban = (grep { $_ != $u->{'defaultpicid'} } 
                   sort { $count_picid{$a} <=> $count_picid{$b} } @active);

        @ban = splice(@ban, 0, $to_ban) if @ban > $to_ban;
        my $ban_in = join(",", map { $dbh->quote($_) } @ban);
        $dbh->do("UPDATE userpic SET state='I' WHERE userid=? AND picid IN ($ban_in)", 
                 undef, $userid) if $ban_in;
    }

    # activate previously inactivated userpics
    if (@inactive && @active < $allow) {
        my $to_activate = $allow - @active;
        $to_activate = @inactive if $to_activate > @inactive;

        # take the $to_activate newest (highest numbered) pictures
        # to reactivated
        @inactive = sort @inactive;
        my @activate_picids = splice(@inactive, -$to_activate);

        my $activate_in = join(",", map { $dbh->quote($_) } @activate_picids);
        $dbh->do("UPDATE userpic SET state='N' WHERE userid=? AND picid IN ($activate_in)",
                 undef, $userid) if $activate_in;
    }

    return;
}

# for efficiency, we store the userpic structures
# in memcache in a packed format.
#
# memory format:
# [
#   version number of format,
#   userid,
#   "packed string", which expands to an array of {width=>..., ...}
#   "packed string", which expands to { 'kw1' => id, 'kw2' => id, ...}
# ]

sub get_userpic_info
{
    my $uuid = shift;
    return undef unless $uuid;
    my $userid = want_userid($uuid);
    return $LJ::CACHE_USERPIC_INFO{$userid} if $LJ::CACHE_USERPIC_INFO{$userid};
    
    my $VERSION_PICINFO = 3;

    my $memkey = [$userid,"upicinf:$userid"];
    my ($info, $minfo);

    if ($minfo = LJ::MemCache::get($memkey)) {
        # the pre-versioned memcache data was a two-element hash.
        # since then, we use an array and include a version number.
        if (ref $minfo eq 'HASH' ||
            $minfo->[0] != $VERSION_PICINFO) {
            # old data in the cache.  delete.
            LJ::MemCache::delete($memkey);
        } else {
            my (undef, $picstr, $kwstr) = @$minfo;
            $info = {
                'pic' => {},
                'kw' => {},
            };
            while (length $picstr >= 7) {
                my $pic = { userid => $userid };
                ($pic->{picid},
                 $pic->{width}, $pic->{height},
                 $pic->{state}) = unpack "NCCA", substr($picstr, 0, 7, '');
                $info->{pic}{$pic->{picid}} = $pic;
            }

            my ($pos, $nulpos);
            $pos = $nulpos = 0;
            while (($nulpos = index($kwstr, "\0", $pos)) > 0) {
                my $kw = substr($kwstr, $pos, $nulpos-$pos);
                my $id = unpack("N", substr($kwstr, $nulpos+1, 4));
                $pos = $nulpos + 5; # skip NUL + 4 bytes.
                $info->{kw}{$kw} = $info->{pic}{$id} if $info;
            }
        }
    }

    unless ($info) {
        $info = {
            'pic' => {},
            'kw' => {},
        };
        my ($picstr, $kwstr);
        
        my $db = @LJ::MEMCACHE_SERVERS ? LJ::get_db_writer() : LJ::get_db_reader();
        my $sth = $db->prepare("SELECT picid, width, height, state, userid ".
                               "FROM userpic WHERE userid=?");
        $sth->execute($userid);
        my @pics;
        while (my $pic = $sth->fetchrow_hashref) {
            push @pics, $pic;
            $info->{'pic'}->{$pic->{'picid'}} = $pic;
        }
        $picstr = join('', map { pack("NCCA", $_->{picid},
                                 $_->{width}, $_->{height}, $_->{state}) } @pics);
        
        $sth = $db->prepare("SELECT k.keyword, m.picid FROM userpicmap m, keywords k ".
                            "WHERE m.userid=? AND m.kwid=k.kwid");
        $sth->execute($userid);
        my %minfokw;
        while (my ($kw, $id) = $sth->fetchrow_array) {
            next unless $info->{'pic'}->{$id};
            next if $kw =~ /[\n\r\0]/;  # used to be a bug that allowed these to get in.
            $info->{'kw'}->{$kw} = $info->{'pic'}->{$id};
            $minfokw{$kw} = int($id);
        }
        $kwstr = join('', map { pack("Z*N", $_, $minfokw{$_}) } keys %minfokw);

        $minfo = [ $VERSION_PICINFO, $picstr, $kwstr ];
        LJ::MemCache::add($memkey, $minfo);
    }

    foreach (values %{$info->{'pic'}}) {
        $LJ::CACHE_USERPIC_SIZE{$_->{'picid'}} = [ $_->{'width'}, $_->{'height'}, $_->{'userid'} ];
    }
    
    return $LJ::CACHE_USERPIC_INFO{$userid} = $info;
}

# <LJFUNC>
# name: LJ::get_pic_from_keyword
# des: Given a userid and keyword, returns the pic row hashref
# args: u, keyword
# des-keyword: The keyword of the userpic to fetch
# returns: hashref of pic row found
# </LJFUNC>
sub get_pic_from_keyword
{
    my ($u, $kw) = @_;
    my $info = LJ::get_userpic_info($u);
    return undef unless $info;
    return $info->{'kw'}{$kw};
}

sub get_picid_from_keyword
{
    my ($u, $kw, $default) = @_;
    $default ||= (ref $u ? $u->{'defaultpicid'} : 0);
    return $default unless $kw;
    my $info = LJ::get_userpic_info($u);
    return $default unless $info;
    my $pr = $info->{'kw'}{$kw};
    return $pr ? $pr->{'picid'} : $default;
}

# <LJFUNC>
# name: LJ::get_timezone_name
# des: Gets the timezone for the user.
# args: u, tzref, fakedref
# des-u: user object.
# des-tzref: reference to scalar to hold timezone;
# des-fakedref: reference to scalar to hold whether this timezone was
#               faked.  0 if it is the timezone specified by the user (not supported yet).
# returns: nonzero if successful.
# </LJFUNC>
sub get_timezone_name {
    my ($u, $tzref, $fakedref) = @_;

    my $timezone;

    $timezone = $u->{timezone} || $BML::COOKIE{'ljtimezone'};
    $$fakedref = 0;
    if(!$timezone) {
        $timezone = $LJ::DEFAULT_TIMEZONE;
        $fakedref = 1;
    }

    $$tzref = $timezone;
    return 1;
}

# <LJFUNC>
# name: LJ::get_current_tzoffset
# des: Gets the timezone offset from UTC for the current time in the specified timezone.
# args: tz
# des-tz: timezone name.
# returns: offset, in seconds.
# </LJFUNC>
sub get_current_tzoffset {
    my ($tz) = @_;

    return DateTime::TimeZone->new(name => $tz)->offset_for_datetime(DateTime->now());
}

# <LJFUNC>
# name: LJ::strip_bad_code
# class: security
# des: Removes malicious/annoying HTML.
# info: This is just a wrapper function around [func[LJ::CleanHTML::clean]].
# args: textref
# des-textref: Scalar reference to text to be cleaned.
# returns: Nothing.
# </LJFUNC>
sub strip_bad_code
{
    my $data = shift;
    LJ::CleanHTML::clean($data, {
        'eat' => [qw[layer iframe script object embed]],
        'mode' => 'allow',
        'keepcomments' => 1, # Allows CSS to work
    });
}

# <LJFUNC>
# name: LJ::server_down_html
# des: Returns an HTML server down message.
# returns: A string with a server down message in HTML.
# </LJFUNC>
sub server_down_html
{
    return "<b>$LJ::SERVER_DOWN_SUBJECT</b><br />$LJ::SERVER_DOWN_MESSAGE";
}

# <LJFUNC>
# name: LJ::make_journal
# class:
# des:
# info:
# args: dbarg, user, view, remote, opts
# des-:
# returns:
# </LJFUNC>
sub make_journal
{
    &nodb;
    my ($user, $view, $remote, $opts) = @_;

    my $r = $opts->{'r'};  # mod_perl $r, or undef
    my $geta = $opts->{'getargs'};

    if ($LJ::SERVER_DOWN) {
        if ($opts->{'vhost'} eq "customview") {
            return "<!-- LJ down for maintenance -->";
        }
        return LJ::server_down_html();
    }

    # S1 style hashref.  won't be loaded now necessarily, 
    # only if via customview.
    my $style;

    my ($styleid);
    if ($opts->{'styleid'}) {  # s1 styleid
        $styleid = $opts->{'styleid'}+0;

        # if we have an explicit styleid, we have to load
        # it early so we can learn its type, so we can
        # know which uprops to load for its owner
        $style = LJ::S1::load_style($styleid, \$view);
    } else {
        $view ||= "lastn";    # default view when none specified explicitly in URLs
        if ($LJ::viewinfo{$view} || $view eq "month" || 
            $view eq "entry" || $view eq "reply")  {
            $styleid = -1;    # to get past the return, then checked later for -1 and fixed, once user is loaded.
        } else {
            $opts->{'badargs'} = 1;
        }
    }
    return unless $styleid;

    my $u;
    if ($opts->{'u'}) {
        $u = $opts->{'u'};
    } else {
        $u = LJ::load_user($user);
    }

    unless ($u) {
        $opts->{'baduser'} = 1;
        return "<h1>Error</h1>No such user <b>$user</b>";
    }

    my $eff_view = $LJ::viewinfo{$view}->{'styleof'} || $view;
    my $s1prop = "s1_${eff_view}_style";

    my @needed_props = ("stylesys", "s2_style", "url", "urlname", $s1prop, "opt_nctalklinks",
                        "renamedto",  "opt_blockrobots", "opt_usesharedpic",
                        "journaltitle", "journalsubtitle");

    # preload props the view creation code will need later (combine two selects)
    if (ref $LJ::viewinfo{$eff_view}->{'owner_props'} eq "ARRAY") {
        push @needed_props, @{$LJ::viewinfo{$eff_view}->{'owner_props'}};
    }

    if ($eff_view eq "reply") {
        push @needed_props, "opt_logcommentips";
    }

    LJ::load_user_props($u, @needed_props);

    # FIXME: remove this after all affected accounts have been fixed
    # see http://zilla.livejournal.org/1443 for details
    if ($u->{$s1prop} =~ /^\D/) {
        $u->{$s1prop} = $LJ::USERPROP_DEF{$s1prop};
        LJ::set_userprop($u, $s1prop, $u->{$s1prop});
    }

    # if the remote is the user to be viewed, make sure the $remote
    # hashref has the value of $u's opt_nctalklinks (though with
    # LJ::load_user caching, this may be assigning between the same
    # underlying hashref)
    $remote->{'opt_nctalklinks'} = $u->{'opt_nctalklinks'} if
        ($remote && $remote->{'userid'} == $u->{'userid'});

    my $stylesys = 1;
    if ($styleid == -1) {

        my $get_styleinfo = sub {

            my $get_s1_styleid = sub {
                my $id = $u->{$s1prop};
                LJ::run_hooks("s1_style_select", {
                    'styleid' => \$id,
                    'u' => $u,
                    'view' => $view,
                });
                return $id;
            };

            # forced s2 style id
            if ($geta->{'s2id'} && LJ::get_cap($u, "s2styles")) {

                # see if they own the requested style
                my $dbr = LJ::get_db_reader();
                my $style_userid = $dbr->selectrow_array("SELECT userid FROM s2styles WHERE styleid=?",
                                                         undef, $geta->{'s2id'});

                # if remote owns the style or the journal owns the style, it's okay
                if ($u->{'userid'} == $style_userid ||
                    $remote->{'userid'} == $style_userid ) {
                    return (2, $geta->{'s2id'});
                }
            }

            # style=mine passed in GET?
            if ($remote && $geta->{'style'} eq 'mine') {

                # get remote props and decide what style remote uses
                LJ::load_user_props($remote, "stylesys", "s2_style");

                # remote using s2
                if ($remote->{'stylesys'} == 2 && $remote->{'s2_style'}) {
                    return (2, $remote->{'s2_style'});
                }

                # remote using s1
                return (1, $get_s1_styleid->());
            }

            # resource URLs have the styleid in it
            if ($view eq "res" && $opts->{'pathextra'} =~ m!^/(\d+)/!) {
                return (2, $1);
            }

            # if none of the above match, they fall through to here
            if ($u->{'stylesys'} == 2) {
                return (2, $u->{'s2_style'});
            }

            # no special case and not s2, fall through to s1
            return (1, $get_s1_styleid->());
        };

        ($stylesys, $styleid) = $get_styleinfo->();
    }

    # signal to LiveJournal.pm that we can't handle this
    if ($stylesys == 1 && ($view eq "entry" || $view eq "reply" || $view eq "month")) {
        ${$opts->{'handle_with_bml_ref'}} = 1;
        return;
    }

    if ($r) {
        $r->notes('journalid' => $u->{'userid'});
    }
    
    my $notice = sub {
        my $msg = shift;
        my $status = shift;

        my $url = "$LJ::SITEROOT/users/$user/";
        $opts->{'status'} = $status if $status;
        
        return qq{
            <h1>Notice</h1>
            <p>$msg</p>
            <p>Instead, please use <nobr><a href=\"$url\">$url</a></nobr></p>
        }.("<!-- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx -->\n" x 50);
    };
    my $error = sub {
        my $msg = shift;
        my $status = shift;
        $opts->{'status'} = $status if $status;
        
        return qq{
            <h1>Error</h1>
            <p>$msg</p>
        }.("<!-- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx -->\n" x 50);
    };
    if ($LJ::USER_VHOSTS && $opts->{'vhost'} eq "users" && $u->{'journaltype'} ne 'R' &&
        ! LJ::get_cap($u, "userdomain")) {
        return $notice->("URLs like <nobr><b>http://<i>username</i>.$LJ::USER_DOMAIN/" .
                         "</b></nobr> are not available for this user's account type.");
    }
    if ($opts->{'vhost'} =~ /^other:/ && ! LJ::get_cap($u, "userdomain")) {
        return $notice->("This user's account type doesn't permit domain aliasing.");
    }
    if ($opts->{'vhost'} eq "customview" && ! LJ::get_cap($u, "styles")) {
        return $notice->("This user's account type is not permitted to create and embed styles.");
    }
    if ($opts->{'vhost'} eq "community" && $u->{'journaltype'} ne "C") {
        $opts->{'badargs'} = 1; # Output a generic 'bad URL' message if available
        return "<h1>Notice</h1><p>This account isn't a community journal.</p>";
    }
    if ($view eq "friendsfriends" && ! LJ::get_cap($u, "friendsfriendsview")) {
        return "<b>Sorry</b><br />This user's account type doesn't permit showing friends of friends.";
    }

    unless ($geta->{'viewall'} && LJ::check_priv($remote, "viewall") ||
            $opts->{'pathextra'} =~ m#/(\d+)/stylesheet$#) { # don't check style sheets
        return $error->("Journal has been deleted.  If you are <b>$user</b>, you have a period of 30 days to decide to undelete your journal.", "404 Not Found") if ($u->{'statusvis'} eq "D");
        return $error->("This journal has been suspended.", "403 Forbidden") if ($u->{'statusvis'} eq "S");
    }
    return $error->("This journal has been deleted and purged.", "410 Gone") if ($u->{'statusvis'} eq "X");

    $opts->{'view'} = $view;

    # what charset we put in the HTML
    $opts->{'saycharset'} ||= "utf-8";

    if ($view eq 'data') {
        return LJ::Feed::make_feed($r, $u, $remote, $opts);
    }

    if ($stylesys == 2) {
        $r->notes('codepath' => "s2.$view") if $r;
        return LJ::S2::make_journal($u, $styleid, $view, $remote, $opts);
    }

    # Everything from here on down is S1.  FIXME: this should be moved to LJ::S1::make_journal
    # to be more like LJ::S2::make_journal.
    $r->notes('codepath' => "s1.$view") if $r;

    # load the user-related S1 data  (overrides and colors)
    my $s1uc = {};
    my $s1uc_memkey = [$u->{'userid'}, "s1uc:$u->{'userid'}"];
    if ($u->{'useoverrides'} eq "Y" || $u->{'themeid'} == 0) {
        $s1uc = LJ::MemCache::get($s1uc_memkey);
        unless ($s1uc) {
            my $db;
            my $setmem = 1;
            if (@LJ::MEMCACHE_SERVERS) { 
                $db = LJ::get_cluster_master($u);
            } else {
                $db = LJ::get_cluster_reader($u);
                $setmem = 0;
            }
            $s1uc = $db->selectrow_hashref("SELECT * FROM s1usercache WHERE userid=?",
                                           undef, $u->{'userid'});
            LJ::MemCache::set($s1uc_memkey, $s1uc) if $s1uc && $setmem;
        }
    }

    # we should have our cache row!  we'll update it in a second.
    my $dbcm;
    if (! $s1uc) {
        $dbcm ||= LJ::get_cluster_master($u);
        $dbcm->do("INSERT IGNORE INTO s1usercache (userid) VALUES (?)", undef, $u->{'userid'});
        $s1uc = {};
    }
    
    # conditionally rebuild parts of our cache that are missing
    my %update;

    # is the overrides cache old or missing?
    my $dbh;
    if ($u->{'useoverrides'} eq "Y" && (! $s1uc->{'override_stor'} ||
                                        $s1uc->{'override_cleanver'} < $LJ::S1::CLEANER_VERSION)) {

        my $overrides = LJ::S1::get_overrides($u);
        $update{'override_stor'} = LJ::CleanHTML::clean_s1_style($overrides);
        $update{'override_cleanver'} = $LJ::S1::CLEANER_VERSION;
    }
    
    # is the color cache here if it's a custom user theme?
    if ($u->{'themeid'} == 0 && ! $s1uc->{'color_stor'}) {
        my $col = {};
        $dbh ||= LJ::get_db_writer();
        my $sth = $dbh->prepare("SELECT coltype, color FROM themecustom WHERE user=?");
        $sth->execute($u->{'user'});
        $col->{$_->{'coltype'}} = $_->{'color'} while $_ = $sth->fetchrow_hashref;
        $update{'color_stor'} = Storable::freeze($col);
    }

    # save the updates
    if (%update) {
        my $set;
        $dbcm ||= LJ::get_cluster_master($u);
        foreach my $k (keys %update) {
            $s1uc->{$k} = $update{$k};
            $set .= ", " if $set;
            $set .= "$k=" . $dbcm->quote($update{$k});
        }
        my $rv = $dbcm->do("UPDATE s1usercache SET $set WHERE userid=?", undef, $u->{'userid'});
        if ($rv && $update{'color_stor'}) {
            $dbh ||= LJ::get_db_writer();
            $dbh->do("DELETE FROM themecustom WHERE user=?", undef, $u->{'user'});
        }
        LJ::MemCache::set($s1uc_memkey, $s1uc);
    }

    # load the style
    my $viewref = $view eq "" ? \$view : undef;
    $style ||= $LJ::viewinfo{$view}->{'nostyle'} ? {} :
        LJ::S1::load_style($styleid, $viewref);

    my %vars = ();
    
    # apply the style
    foreach (keys %$style) {
        $vars{$_} = $style->{$_};
    }

    # apply the overrides
    if ($opts->{'nooverride'}==0 && $u->{'useoverrides'} eq "Y") {
        my $tw = Storable::thaw($s1uc->{'override_stor'});
        foreach (keys %$tw) {
            $vars{$_} = $tw->{$_};
        }
    }

    # apply the color theme
    my $cols = $u->{'themeid'} ? LJ::S1::get_themeid($u->{'themeid'}) :
        Storable::thaw($s1uc->{'color_stor'});
    foreach (keys %$cols) {
        $vars{"color-$_"} = $cols->{$_};
    }
        
    # instruct some function to make this specific view type
    return unless defined $LJ::viewinfo{$view}->{'creator'};
    my $ret = "";

    # call the view creator w/ the buffer to fill and the construction variables
    my $res = $LJ::viewinfo{$view}->{'creator'}->(\$ret, $u, \%vars, $remote, $opts);

    unless ($res) {
        my $errcode = $opts->{'errcode'};
        my $errmsg = {
            'nodb' => 'Database temporarily unavailable during maintenance.',
            'nosyn' => 'No syndication URL available.',
        }->{$errcode};
        return "<!-- $errmsg -->" if ($opts->{'vhost'} eq "customview");

        # If not customview, set the error response code.
        $opts->{'status'} = {
            'nodb' => '503 Maintenance',
            'nosyn' => '404 Not Found',
        }->{$errcode} || '500 Server Error';
        return $errmsg;
    }   

    if ($opts->{'redir'}) {
        return undef;
    }

    # clean up attributes which we weren't able to quickly verify
    # as safe in the Storable-stored clean copy of the style.
    $ret =~ s/\%\%\[attr\[(.+?)\]\]\%\%/LJ::CleanHTML::s1_attribute_clean($1)/eg;

    # return it...
    return $ret;
}

sub syn_cost
{
    my $watchers = shift;
    return 1 if $watchers < 1;
    return 1/(log($watchers)/log(5)+1);
}


# <LJFUNC>
# name: LJ::canonical_username
# des:
# info:
# args: user
# returns: the canonical username given, or blank if the username is not well-formed
# </LJFUNC>
sub canonical_username
{
    my $user = shift;
    if ($user =~ /^\s*([\w\-]{1,15})\s*$/) {
        # perl 5.8 bug:  $user = lc($1) sometimes causes corruption when $1 points into $user.
        $user = $1;
        $user = lc($user);
        $user =~ s/-/_/g;
        return $user;
    }
    return "";  # not a good username.
}

# <LJFUNC>
# name: LJ::decode_url_string
# class: web
# des: Parse URL-style arg/value pairs into a hash.
# args: buffer, hashref
# des-buffer: Scalar or scalarref of buffer to parse.
# des-hashref: Hashref to populate.
# returns: boolean; true.
# </LJFUNC>
sub decode_url_string
{
    my $a = shift;
    my $buffer = ref $a ? $a : \$a;
    my $hashref = shift;  # output hash

    my $pair;
    my @pairs = split(/&/, $$buffer);
    my ($name, $value);
    foreach $pair (@pairs)
    {
        ($name, $value) = split(/=/, $pair);
        $value =~ tr/+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $name =~ tr/+/ /;
        $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $hashref->{$name} .= $hashref->{$name} ? "\0$value" : $value;
    }
    return 1;
}

sub get_db_reader {
    return LJ::get_dbh("slave", "master");
}

sub get_db_writer {
    return LJ::get_dbh("master");
}

# <LJFUNC>
# name: LJ::get_cluster_reader
# class: db
# des: Returns a cluster slave for a user, or cluster master if no slaves exist.
# args: uarg
# des-uarg: Either a userid scalar or a user object.
# returns: DB handle.  Or undef if all dbs are unavailable.
# </LJFUNC>
sub get_cluster_reader
{
    my $arg = shift;
    my $id = ref $arg eq "HASH" ? $arg->{'clusterid'} : $arg;
    my @roles = ("cluster${id}slave", "cluster${id}");
    if (my $ab = $LJ::CLUSTER_PAIR_ACTIVE{$id}) {
        $ab = lc($ab);
        # master-master cluster
        @roles = ("cluster${id}${ab}") if $ab eq "a" || $ab eq "b";
    }
    return LJ::get_dbh(@roles);
}

# <LJFUNC>
# name: LJ::get_cluster_master
# class: db
# des: Returns a cluster master for a given user.
# args: uarg
# des-uarg: Either a userid scalar or a user object.
# returns: DB handle.  Or undef if master is unavailable.
# </LJFUNC>
sub get_cluster_master
{
    my @dbh_opts = scalar(@_) == 2 ? (shift @_) : ();
    my $arg = shift;
    my $id = ref $arg eq "HASH" ? $arg->{'clusterid'} : $arg;
    my $role = "cluster${id}";
    if (my $ab = $LJ::CLUSTER_PAIR_ACTIVE{$id}) {
        $ab = lc($ab);
        # master-master cluster
        $role = "cluster${id}${ab}" if $ab eq "a" || $ab eq "b";
    }
    return LJ::get_dbh(@dbh_opts, $role);
}

# <LJFUNC>
# name: LJ::item_link
# class: component
# des: Returns URL to view an individual journal item.
# info: The returned URL may have an ampersand in it.  In an HTML/XML attribute,
#       these must first be escaped by, say, [func[LJ::ehtml]].  This
#       function doesn't return it pre-escaped because the caller may
#       use it in, say, a plain-text email message.
# args: u, itemid, anum?
# des-itemid: Itemid of entry to link to.
# des-anum: If present, $u is assumed to be on a cluster and itemid is assumed
#           to not be a $ditemid already, and the $itemid will be turned into one
#           by multiplying by 256 and adding $anum.
# returns: scalar; unescaped URL string
# </LJFUNC>
sub item_link
{
    my ($u, $itemid, $anum, @args) = @_;
    my $ditemid = $itemid*256 + $anum;

    # XXX: should have an option of returning a url with escaped (&amp;)
    #      or non-escaped (&) arguments.  a new link object would be best.
    my $args = @args ? "?" . join("&amp;", @args) : "";
    return LJ::journal_base($u) . "/$ditemid.html$args";
}

# <LJFUNC>
# name: LJ::make_graphviz_dot_file
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub make_graphviz_dot_file
{
    &nodb;
    my $user = shift;

    # the code below is inefficient.  let sites disable it.
    return if $LJ::DISABLED{'graphviz_dot'};

    my $dbr = LJ::get_db_reader();

    my $quser = $dbr->quote($user);
    my $sth;
    my $ret;

    my $u = LJ::load_user($user);
    return unless $u;

    $ret .= "digraph G {\n";
    $ret .= "  node [URL=\"$LJ::SITEROOT/userinfo.bml?user=\\N\"]\n";
    $ret .= "  node [fontsize=10, color=lightgray, style=filled]\n";
    $ret .= "  \"$user\" [color=yellow, style=filled]\n";

    my @friends = ();
    $sth = $dbr->prepare("SELECT friendid FROM friends WHERE userid=$u->{'userid'} AND userid<>friendid");
    $sth->execute;
    while ($_ = $sth->fetchrow_hashref) {
        push @friends, $_->{'friendid'};
    }

    my $friendsin = join(", ", map { $dbr->quote($_); } ($u->{'userid'}, @friends));
    my $sql = "SELECT uu.user, uf.user AS 'friend' FROM friends f, user uu, user uf WHERE f.userid=uu.userid AND f.friendid=uf.userid AND f.userid<>f.friendid AND uu.statusvis='V' AND uf.statusvis='V' AND (f.friendid=$u->{'userid'} OR (f.userid IN ($friendsin) AND f.friendid IN ($friendsin)))";
    $sth = $dbr->prepare($sql);
    $sth->execute;
    while ($_ = $sth->fetchrow_hashref) {
        $ret .= "  \"$_->{'user'}\"->\"$_->{'friend'}\"\n";
    }

    $ret .= "}\n";

    return $ret;
}

# <LJFUNC>
# name: LJ::expand_embedded
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub expand_embedded
{
    &nodb;
    my ($u, $ditemid, $remote, $eventref) = @_;

    LJ::Poll::show_polls($ditemid, $remote, $eventref);
    LJ::run_hooks("expand_embedded", $u, $ditemid, $remote, $eventref);
}

# <LJFUNC>
# name: LJ::make_remote
# des: Returns a minimal user structure ($remote-like) from
#      a username and userid.
# args: user, userid
# des-user: Username.
# des-userid: User ID.
# returns: hashref with 'user' and 'userid' keys, or undef if
#          either argument was bogus (so caller can pass
#          untrusted input)
# </LJFUNC>
sub make_remote
{
    my $user = LJ::canonical_username(shift);
    my $userid = shift;
    if ($user && $userid && $userid =~ /^\d+$/) {
        return { 'user' => $user,
                 'userid' => $userid, };
    }
    return undef;
}

sub update_user
{
    my ($uuserid, $ref) = @_;
    my $uid = want_userid($uuserid);
    return 0 unless $uid;

    my @sets;
    my @bindparams;
    while (my ($k, $v) = each %$ref) {
        if ($k eq "raw") {
            push @sets, $v;
        } else {
            push @sets, "$k=?";
            push @bindparams, $v;
        }
    }
    return 1 unless @sets;
    my $dbh = LJ::get_db_writer();
    return 0 unless $dbh;
    { 
        local $" = ",";
        $dbh->do("UPDATE user SET @sets WHERE userid=?", undef,
                 @bindparams, $uid);
        return 0 if $dbh->err;
    }
    if (@LJ::MEMCACHE_SERVERS) {
        my $u = _load_user_raw($dbh, "userid", $uid);
        LJ::memcache_set_u($u);
    }
    return 1;
}

# <LJFUNC>
# name: LJ::load_userids_multiple
# des: Loads a number of users at once, efficiently.
# info: loads a few users at once, their userids given in the keys of $map
#       listref (not hashref: can't have dups).  values of $map listref are
#       scalar refs to put result in.  $have is an optional listref of user
#       object caller already has, but is too lazy to sort by themselves.
# args: dbarg?, map, have, memcache_only?
# des-map: Arrayref of pairs (userid, destination scalarref)
# des-have: Arrayref of user objects caller already has
# des-memcache_only: Flag to only retrieve data from memcache
# returns: Nothing.
# </LJFUNC>
sub load_userids_multiple
{
    &nodb;
    my ($map, $have, $memcache_only) = @_;

    my $sth;

    my %need;
    while (@$map) {
        my $id = shift @$map;
        my $ref = shift @$map;
        next unless int($id);
        push @{$need{$id}}, $ref;

        if ($LJ::REQ_CACHE_USER_ID{$id}) {
            push @{$have}, $LJ::REQ_CACHE_USER_ID{$id};
        }
    }

    my $satisfy = sub {
        my $u = shift;
        next unless ref $u eq "HASH";
        foreach (@{$need{$u->{'userid'}}}) {
            $$_ = $u;
        }
        $LJ::REQ_CACHE_USER_NAME{$u->{'user'}} = $u;
        $LJ::REQ_CACHE_USER_ID{$u->{'userid'}} = $u;
        delete $need{$u->{'userid'}};
    };

    if ($have) {
        foreach my $u (@$have) {
            $satisfy->($u);
        }
    }
    
    if (%need) {
        foreach (LJ::memcache_get_u(map { [$_,"userid:$_"] } keys %need)) {
            $satisfy->($_);
        }
    }

    if (%need && ! $memcache_only) {
        my $db = @LJ::MEMCACHE_SERVERS ? LJ::get_db_writer() : LJ::get_db_reader();
        _load_user_raw($db, "userid", [ keys %need ], sub {
            my $u = shift;
            LJ::memcache_set_u($u);
            $satisfy->($u);
        });
    }
}

# des-db:  $dbh/$dbr
# des-key:  either "userid" or "user"  (the WHERE part)
# des-vals: value or arrayref of values for key to match on
# des-hoook: optional code ref to run for each $u
# returns: last $u found
sub _load_user_raw
{
    my ($db, $key, $vals, $hook) = @_;
    $hook ||= sub {};
    $vals = [ $vals ] unless ref $vals eq "ARRAY";
    
    my $use_isam;
    unless ($LJ::CACHE_NO_ISAM{user} || scalar(@$vals) > 10) {
        $db->do("HANDLER user OPEN");
        if ($db->err) {
            $LJ::CACHE_NO_ISAM{user} = 1;
        } else {
            $use_isam = 1;
        }
    }

    my $last;

    if ($use_isam) {
        $key = "PRIMARY" if $key eq "userid";
        foreach my $v (@$vals) {
            my $sth = $db->prepare("HANDLER user READ `$key` = (?) LIMIT 1");
            $sth->execute($v);
            my $u = $sth->fetchrow_hashref;
            if ($u) {
                $hook->($u);
                $last = $u;
            }
        }
        $db->do("HANDLER user close");
    } else {
        my $in = join(", ", map { $db->quote($_) } @$vals);
        my $sth = $db->prepare("SELECT * FROM user WHERE $key IN ($in)");
        $sth->execute;
        while (my $u = $sth->fetchrow_hashref) {
            $hook->($u);
            $last = $u;
        }
    }

    return $last;
}

# <LJFUNC>
# name: LJ::load_user
# des: Loads a user record given a username.
# info: From the [dbarg[user]] table.
# args: dbarg?, user, force?
# des-user: Username of user to load.
# des-force: if set to true, won't return cached user object and will
#            query a dbh
# returns: Hashref with keys being columns of [dbtable[user]] table.
# </LJFUNC>
sub load_user
{
    &nodb;
    my ($user, $force) = @_;

    $user = LJ::canonical_username($user);
    return undef unless length $user;
    
    my $set_req_cache = sub {
        my $u = shift;
        $LJ::REQ_CACHE_USER_NAME{$u->{'user'}} = $u;
        $LJ::REQ_CACHE_USER_ID{$u->{'userid'}} = $u;
        return $u;
    };

    my $get_user = sub {
        my $use_dbh = shift;
        my $db = $use_dbh ? LJ::get_db_writer() : LJ::get_db_reader();
        my $u = _load_user_raw($db, "user", $user);
        return $u unless $u && $use_dbh;

        # set caches since we got a u from the master
        LJ::memcache_set_u($u);
        return $set_req_cache->($u);
    };

    # caller is forcing a master, return now
    return $get_user->("master") if $force;

    my $u;

    # return process cache if we have one
    $u = $LJ::REQ_CACHE_USER_NAME{$user};
    return $u if $u;

    # check memcache
    $u = LJ::memcache_get_u("user:$user");
    return $set_req_cache->($u) if $u;

    # try to load from master if using memcache, otherwise from slave
    $u = $get_user->(scalar @LJ::MEMCACHE_SERVERS);
    return $u if $u;

    # if user doesn't exist in the LJ database, it's possible we're using
    # an external authentication source and we should create the account
    # implicitly.
    if (ref $LJ::AUTH_EXISTS eq "CODE" && 
        $LJ::AUTH_EXISTS->($user))
    {
        if (LJ::create_account({
            'user' => $user,
            'name' => $user,
            'password' => "",
        }))
        {
            # this should pull from the master, since it was _just_ created
            return $get_user->("master");
        }
    }

    return undef;
}

sub memcache_get_u
{
    my @keys = @_;
    my @ret;
    foreach my $ar (values %{LJ::MemCache::get_multi(@keys) || {}}) {
        my $u = LJ::MemCache::array_to_hash("user", $ar);
        push @ret, $u if $u;
    }
    return wantarray ? @ret : $ret[0];
}

sub memcache_set_u
{
    my $u = shift;
    return unless $u;
    my $expire = time() + 1800;
    my $ar = LJ::MemCache::hash_to_array("user", $u);
    return unless $ar;
    LJ::MemCache::set([$u->{'userid'}, "userid:$u->{'userid'}"], $ar, $expire);
    LJ::MemCache::set("user:$u->{'user'}", $ar, $expire);
}

# <LJFUNC>
# name: LJ::load_userid
# des: Loads a user record given a userid.
# info: From the [dbarg[user]] table.
# args: dbarg?, userid, force?
# des-userid: Userid of user to load.
# des-force: if set to true, won't return cached user object and will
#            query a dbh
# returns: Hashref with keys being columns of [dbtable[user]] table.
# </LJFUNC>
sub load_userid
{
    &nodb;
    my ($userid, $force) = @_;
    return undef unless $userid;
     
    my $set_req_cache = sub {
        my $u = shift;
        $LJ::REQ_CACHE_USER_NAME{$u->{'user'}} = $u;
        $LJ::REQ_CACHE_USER_ID{$u->{'userid'}} = $u;
        return $u;
    };

    my $get_user = sub {
        my $use_dbh = shift;
        my $db = $use_dbh ? LJ::get_db_writer() : LJ::get_db_reader();
        my $u = _load_user_raw($db, "userid", $userid);
        return $u unless $u && $use_dbh;

        # set caches since we got a u from the master
        LJ::memcache_set_u($u);
        return $set_req_cache->($u);
    };

    # user is forcing master, return now
    return $get_user->("master") if $force;

    my $u;

    # check process cache
    $u = $LJ::REQ_CACHE_USER_ID{$userid};
    return $u if $u;

    # check memcache
    $u = LJ::memcache_get_u([$userid,"userid:$userid"]);
    return $set_req_cache->($u) if $u;

    # get from master if using memcache
    return $get_user->("master") if @LJ::MEMCACHE_SERVERS;

    # check slave
    $u = $get_user->();
    return $u if $u;

    # if we didn't get a u from the reader, fall back to master
    return $get_user->("master");
}

# <LJFUNC>
# name: LJ::get_bio
# des: gets a user bio, from db or memcache
# args: u, force
# des-force: true to get data from cluster master
# returns: string
# </LJFUNC>
sub get_bio {
    my ($u, $force) = @_;
    return unless $u && $u->{'has_bio'} eq "Y";

    my $bio;

    my $memkey = [$u->{'userid'}, "bio:$u->{'userid'}"];
    unless ($force) {
        my $bio = LJ::MemCache::get($memkey);
        return $bio if defined $bio;
    }

    # not in memcache, fall back to disk
    my $db = @LJ::MEMCACHE_SERVERS || $force ?
      LJ::get_cluster_master($u) : LJ::get_cluster_reader($u);
    $bio = $db->selectrow_array("SELECT bio FROM userbio WHERE userid=?",
                                undef, $u->{'userid'});

    # set in memcache
    LJ::MemCache::add($memkey, $bio);

    return $bio;
}

# <LJFUNC>
# name: LJ::load_moods
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub load_moods
{
    return if $LJ::CACHED_MOODS;
    my $dbr = LJ::get_db_reader();
    my $sth = $dbr->prepare("SELECT moodid, mood, parentmood FROM moods");
    $sth->execute;
    while (my ($id, $mood, $parent) = $sth->fetchrow_array) {
        $LJ::CACHE_MOODS{$id} = { 'name' => $mood, 'parent' => $parent, 'id' => $id };
        if ($id > $LJ::CACHED_MOOD_MAX) { $LJ::CACHED_MOOD_MAX = $id; }
    }
    $LJ::CACHED_MOODS = 1;
}

# <LJFUNC>
# name: LJ::cmd_buffer_add
# des: Schedules some command to be run sometime in the future which would
#      be too slow to do syncronously with the web request.  An example
#      is deleting a journal entry, which requires recursing through a lot
#      of tables and deleting all the appropriate stuff.
# args: db, journalid, cmd, hargs
# des-db: Cluster master db handle to run command on.
# des-journalid: Journal id command affects.  This is indexed in the
#                [dbtable[cmdbuffer]] table so that all of a user's queued
#                actions can be run before that user is potentially moved
#                between clusters.
# des-cmd: Text of the command name.  30 chars max.
# des-hargs: Hashref of command arguments.
# </LJFUNC>
sub cmd_buffer_add
{
    my ($db, $journalid, $cmd, $args) = @_;

    return 0 unless $db;
    return 0 unless $cmd;

    my $arg_str;
    if (ref $args eq 'HASH') {
        foreach (sort keys %$args) {
            $arg_str .= LJ::eurl($_) . "=" . LJ::eurl($args->{$_}) . "&";
        }
        chop $arg_str;
    } else {
        $arg_str = $args;
    }

    $db->do("INSERT INTO cmdbuffer (journalid, cmd, instime, args) ".
            "VALUES (?, ?, NOW(), ?)", undef,
            $journalid, $cmd, $arg_str);
}

# <LJFUNC>
# name: LJ::cmd_buffer_flush
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub cmd_buffer_flush
{
    my ($dbh, $db, $cmd, $userid) = @_;
    return 0 unless $cmd;

    my $mode = "run";
    if ($cmd =~ s/:(\w+)//) {
        $mode = $1;
    }

    # built-in commands
    my $cmds = {
        'delitem' => {
            'run' => sub {
                my ($dbh, $db, $c) = @_;
                my $a = $c->{'args'};
                LJ::delete_entry($c->{'journalid'}, $a->{'itemid'},
                                 0, $a->{'anum'});
            },
        },
        # ping weblogs.com with updates?  takes a $u argument
        'weblogscom' => {
            'too_old' => 60*60*2,  # 2 hours old = qbufferd not running?
            'run' => sub {
                # user, title, url
                my ($dbh, $db, $c) = @_;
                my $a = $c->{'args'};
                eval {
                    eval "use XMLRPC::Lite;";
                    XMLRPC::Lite
                        ->new( proxy => "http://rpc.weblogs.com/RPC2",
                               timeout => 5 )
                        ->call('weblogUpdates.ping', # xml-rpc method call
                               LJ::ehtml($a->{'title'}) . " \@ $LJ::SITENAMESHORT",
                               $a->{'url'},
                               "$LJ::SITEROOT/misc/weblogs-change.bml?user=$a->{'user'}");
                };
            },
        },
        # emails that previously failed to send
        'send_mail' => {
            'arg_format' => 'raw',
            'run' => sub {
                my ($dbh, $db, $c) = @_;

                my $msg = Storable::thaw($c->{'args'});
                LJ::send_mail($msg);
            }
        }
    };

    my $code;
    my $too_old = 0;        # 0 = never too old
    my $arg_format = 'url'; # 'raw' = don't urlencode

    # is it a built-in command?
    if ($cmds->{$cmd}) {
        $code = $cmds->{$cmd}->{$mode};
        $too_old = $cmds->{$cmd}->{"too_old"};
        $arg_format = $cmds->{$cmd}->{"arg_format"} if
            defined $cmds->{$cmd}->{"arg_format"};
        
    # otherwise it might be a site-local command
    } else {
        $code = $LJ::HOOKS{"cmdbuf:$cmd:$mode"}->[0]
            if $LJ::HOOKS{"cmdbuf:$cmd:$mode"};
        $too_old = $LJ::HOOKS{"cmdbuf:$cmd:too_old"}->[0]->()
            if $LJ::HOOKS{"cmdbuf:$cmd:too_old"};
    }

    return 0 unless $code;

    # start/finish modes
    if ($mode ne "run") {
        $code->($dbh);
        return;
    }

    my $clist;
    my $loop = 1;

    my $where = "cmd=" . $dbh->quote($cmd);
    if ($userid) {
        $where .= " AND journalid=" . $dbh->quote($userid);
    }

    my $LIMIT = 500;

    while ($loop &&
           ($clist = $db->selectall_arrayref("SELECT cbid, UNIX_TIMESTAMP() - UNIX_TIMESTAMP(instime) ".
                                             "FROM cmdbuffer ".
                                             "WHERE $where ORDER BY cbid LIMIT $LIMIT")) &&
           $clist && @$clist)
    {
        my @too_old;
        my @cbids;
        foreach my $citem (@$clist) {
            if ($too_old && $citem->[1] > $too_old) {
                push @too_old, $citem->[0];
            } else {
                push @cbids, $citem->[0];
            }
        }
        if (@too_old) {
            local $" = ",";
            $db->do("DELETE FROM cmdbuffer WHERE cbid IN (@too_old)");
        }

        foreach my $cbid (@cbids) {
            my $got_lock = $db->selectrow_array("SELECT GET_LOCK('cbid-$cbid',10)");
            return 0 unless $got_lock;
            # sadly, we have to do another query here to verify the job hasn't been
            # done by another thread.  (otherwise we could've done it above, instead
            # of just getting the id)

            my $c = $db->selectrow_hashref("SELECT cbid, journalid, cmd, instime, args " .
                                           "FROM cmdbuffer WHERE cbid=?", undef, $cbid);
            next unless $c;

            if ($arg_format eq "url") {
                my $a = {};
                LJ::decode_url_string($c->{'args'}, $a);
                $c->{'args'} = $a;
            }
            # otherwise, arg_format eq "raw"

            # run handler
            $code->($dbh, $db, $c);

            $db->do("DELETE FROM cmdbuffer WHERE cbid=$cbid");
            $db->do("SELECT RELEASE_LOCK('cbid-$cbid')");
        }
        $loop = 0 unless scalar(@$clist) == $LIMIT;
    }

    return 1;
}

# <LJFUNC>
# name: LJ::journal_base
# des: Returns URL of a user's journal.
# info: The tricky thing is that users with underscores in their usernames
#       can't have some_user.site.com as a hostname, so that's changed into
#       some-user.site.com.
# args: uuser, vhost?
# des-uuser: User hashref or username of user whose URL to make.
# des-vhost: What type of URL.  Acceptable options are "users", to make a
#            http://user.site.com/ URL; "tilde" to make http://site.com/~user/;
#            "community" for http://site.com/community/user; or the default
#            will be http://site.com/users/user.  If unspecifed and uuser
#            is a user hashref, then the best/preferred vhost will be chosen.
# returns: scalar; a URL.
# </LJFUNC>
sub journal_base
{
    my ($user, $vhost) = @_;
    if (ref $user eq "HASH") {
        my $u = $user;
        $user = $u->{'user'};
        unless (defined $vhost) {
            if ($LJ::FRONTPAGE_JOURNAL eq $user) {
                $vhost = "front";
            } elsif ($u->{'journaltype'} eq "P") {
                $vhost = "";
            } elsif ($u->{'journaltype'} eq "C") {
                $vhost = "community";
            }

        }
    }
    if ($vhost eq "users") {
        my $he_user = $user;
        $he_user =~ s/_/-/g;
        return "http://$he_user.$LJ::USER_DOMAIN";
    } elsif ($vhost eq "tilde") {
        return "$LJ::SITEROOT/~$user";
    } elsif ($vhost eq "community") {
        return "$LJ::SITEROOT/community/$user";
    } elsif ($vhost eq "front") {
        return $LJ::SITEROOT;
    } elsif ($vhost =~ /^other:(.+)/) {
        return "http://$1";
    } else {
        return "$LJ::SITEROOT/users/$user";
    }
}


# loads all of the given privs for a given user into a hashref
# inside the user record ($u->{_privs}->{$priv}->{$arg} = 1)
# <LJFUNC>
# name: LJ::load_user_privs
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub load_user_privs
{
    &nodb;
    my $remote = shift;
    my @privs = @_;
    return unless $remote and @privs;

    # return if we've already loaded these privs for this user.
    @privs = grep { ! $remote->{'_privloaded'}->{$_} } @privs;
    return unless @privs;

    my $dbr = LJ::get_db_reader();
    return unless $dbr;
    foreach (@privs) { $remote->{'_privloaded'}->{$_}++; }
    @privs = map { $dbr->quote($_) } @privs;
    my $sth = $dbr->prepare("SELECT pl.privcode, pm.arg ".
                            "FROM priv_map pm, priv_list pl ".
                            "WHERE pm.prlid=pl.prlid AND ".
                            "pl.privcode IN (" . join(',',@privs) . ") ".
                            "AND pm.userid=$remote->{'userid'}");
    $sth->execute;
    while (my ($priv, $arg) = $sth->fetchrow_array) {
        unless (defined $arg) { $arg = ""; }  # NULL -> ""
        $remote->{'_priv'}->{$priv}->{$arg} = 1;
    }
}

# <LJFUNC>
# name: LJ::check_priv
# des: Check to see if a user has a certain privilege.
# info: Usually this is used to check the privs of a $remote user.
#       See [func[LJ::get_remote]].  As such, a $u argument of undef
#       is okay to pass: 0 will be returned, as an unknown user can't
#       have any rights.
# args: dbarg?, u, priv, arg?
# des-priv: Priv name to check for (see [dbtable[priv_list]])
# des-arg: Optional argument.  If defined, function only returns true
#          when $remote has a priv of type $priv also with arg $arg, not
#          just any priv of type $priv, which is the behavior without
#          an $arg
# returns: boolean; true if user has privilege
# </LJFUNC>
sub check_priv
{
    &nodb;
    my ($u, $priv, $arg) = @_;
    return 0 unless $u;

    if (! $u->{'_privloaded'}->{$priv}) {
	LJ::load_user_privs($u, $priv);
    }

    if (defined $arg) {
        return (defined $u->{'_priv'}->{$priv} &&
                defined $u->{'_priv'}->{$priv}->{$arg});
    } else {
        return (defined $u->{'_priv'}->{$priv});
    }
}

#
#
# <LJFUNC>
# name: LJ::remote_has_priv
# class:
# des: Check to see if the given remote user has a certain priviledge
# info: DEPRECATED.  should use load_user_privs + check_priv
# args:
# des-:
# returns:
# </LJFUNC>
sub remote_has_priv
{
    &nodb;
    my $remote = shift;
    my $privcode = shift;     # required.  priv code to check for.
    my $ref = shift;  # optional, arrayref or hashref to populate
    return 0 unless ($remote);

    ### authentication done.  time to authorize...

    my $dbr = LJ::get_db_reader();
    my $sth = $dbr->prepare("SELECT pm.arg FROM priv_map pm, priv_list pl WHERE pm.prlid=pl.prlid AND pl.privcode=? AND pm.userid=?");
    $sth->execute($privcode, $remote->{'userid'});

    my $match = 0;
    if (ref $ref eq "ARRAY") { @$ref = (); }
    if (ref $ref eq "HASH") { %$ref = (); }
    while (my ($arg) = $sth->fetchrow_array) {
        $match++;
        if (ref $ref eq "ARRAY") { push @$ref, $arg; }
        if (ref $ref eq "HASH") { $ref->{$arg} = 1; }
    }
    return $match;
}

# <LJFUNC>
# name: LJ::get_userid
# des: Returns a userid given a username.
# info: Results cached in memory.  On miss, does DB call.  Not advised
#       to use this many times in a row... only once or twice perhaps
#       per request.  Tons of serialized db requests, even when small,
#       are slow.  Opposite of [func[LJ::get_username]].
# args: dbarg?, user
# des-user: Username whose userid to look up.
# returns: Userid, or 0 if invalid user.
# </LJFUNC>
sub get_userid
{
    &nodb;
    my $user = shift;

    $user = LJ::canonical_username($user);

    if ($LJ::CACHE_USERID{$user}) { return $LJ::CACHE_USERID{$user}; }

    my $dbr = LJ::get_db_reader();
    my $userid = $dbr->selectrow_array("SELECT userid FROM useridmap WHERE user=?", undef, $user);
    if ($userid) { $LJ::CACHE_USERID{$user} = $userid; }

    # implictly create an account if we're using an external
    # auth mechanism
    if (! $userid && ref $LJ::AUTH_EXISTS eq "CODE")
    {
        $userid = LJ::create_account({ 'user' => $user,
                                       'name' => $user,
                                       'password' => '', });
    }

    return ($userid+0);
}

# <LJFUNC>
# name: LJ::want_userid
# des: Returns userid when passed either userid or the user hash. Useful to functions that
#      want to accept either. Forces its return value to be a number (for safety).
# args: userid
# des-userid: Either a userid, or a user hash with the userid in its 'userid' key.
# returns: The userid, guaranteed to be a numeric value.
# </LJFUNC>
sub want_userid
{
    my $uuserid = shift;
    return ($uuserid->{'userid'} + 0) if ref $uuserid;
    return ($uuserid + 0);
}


# <LJFUNC>
# name: LJ::get_username
# des: Returns a username given a userid.
# info: Results cached in memory.  On miss, does DB call.  Not advised
#       to use this many times in a row... only once or twice perhaps
#       per request.  Tons of serialized db requests, even when small,
#       are slow.  Opposite of [func[LJ::get_userid]].
# args: dbarg?, user
# des-user: Username whose userid to look up.
# returns: Userid, or 0 if invalid user.
# </LJFUNC>
sub get_username
{
    &nodb;
    my $userid = shift;
    $userid += 0;

    # Checked the cache first.
    if ($LJ::CACHE_USERNAME{$userid}) { return $LJ::CACHE_USERNAME{$userid}; }

    # if we're using memcache, it's faster to just query memcache for
    # an entire $u object and just return the username.  otherwise, we'll
    # go ahead and query useridmap
    if (@LJ::MEMCACHE_SERVERS) {
        my $u = LJ::load_userid($userid);
        return undef unless $u;

        $LJ::CACHE_USERNAME{$userid} = $u->{'user'};
        return $u->{'user'};
    }

    my $dbr = LJ::get_db_reader();
    my $user = $dbr->selectrow_array("SELECT user FROM useridmap WHERE userid=?", undef, $userid);

    # Fall back to master if it doesn't exist.
    unless (defined $user) {
        my $dbh = LJ::get_db_writer();
        $user = $dbh->selectrow_array("SELECT user FROM useridmap WHERE userid=?", undef, $userid);
    }

    return undef unless defined $user;

    $LJ::CACHE_USERNAME{$userid} = $user;
    return $user;
}

sub get_itemid_near2
{
    my $u = shift;
    my $jitemid = shift;
    my $after_before = shift;

    $jitemid += 0;

    my ($inc, $order);
    if ($after_before eq "after") {
        ($inc, $order) = (-1, "DESC");
    } elsif ($after_before eq "before") {
        ($inc, $order) = (1, "ASC");
    } else {
        return 0;
    }

    my $dbr = LJ::get_cluster_reader($u);
    my $jid = $u->{'userid'}+0;
    my $field = $u->{'journaltype'} eq "P" ? "revttime" : "rlogtime";

    my $stime = $dbr->selectrow_array("SELECT $field FROM log2 WHERE ".
                                      "journalid=$jid AND jitemid=$jitemid");
    return 0 unless $stime;


    my $day = 86400;
    foreach my $distance ($day, $day*7, $day*30, $day*90) {
        my ($one_away, $further) = ($stime + $inc, $stime + $inc*$distance);
        if ($further < $one_away) {
            # swap them, BETWEEN needs lower number first
            ($one_away, $further) = ($further, $one_away);
        }
        my ($id, $anum) =
            $dbr->selectrow_array("SELECT jitemid, anum FROM log2 WHERE journalid=$jid ".
                                  "AND $field BETWEEN $one_away AND $further ".
                                  "ORDER BY $field $order LIMIT 1");
        if ($id) {
            return wantarray() ? ($id, $anum) : ($id*256 + $anum);
        }
    }
    return 0;
}

sub get_itemid_after2  { return get_itemid_near2(@_, "after");  }
sub get_itemid_before2 { return get_itemid_near2(@_, "before"); }


# <LJFUNC>
# name: LJ::mysql_time
# des:
# class: time
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub mysql_time
{
    my ($time, $gmt) = @_;
    $time ||= time();
    my @ltime = $gmt ? gmtime($time) : localtime($time);
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d",
                   $ltime[5]+1900,
                   $ltime[4]+1,
                   $ltime[3],
                   $ltime[2],
                   $ltime[1],
                   $ltime[0]);
}

# gets date in MySQL format, produces s2dateformat
# s1 dateformat is: 
# "%a %W %b %M %y %Y %c %m %e %d %D %p %i %l %h %k %H"
# sample string:
# Tue Tuesday Sep September 03 2003 9 09 30 30 30th AM 22 9 09 9 09
# Thu Thursday Oct October 03 2003 10 10 2 02 2nd AM 33 9 09 9 09

sub alldatepart_s1 
{
    my $time = shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday) =
        gmtime(LJ::mysqldate_to_time($time, 1));
    my $ret = "";

    $ret .= LJ::Lang::day_short($wday+1) . " " .
      LJ::Lang::day_long($wday+1) . " " .
      LJ::Lang::month_short($mon+1) . " " .
      LJ::Lang::month_long($mon+1) . " " .
      sprintf("%02d %04d %d %02d %d %02d %d%s ",
              $year % 100, $year + 1900, $mon+1, $mon+1,
              $mday, $mday, $mday, LJ::Lang::day_ord($mday));
    $ret .= $hour < 12 ? "AM " : "PM ";
    $ret .= sprintf("%02d %d %02d %d %02d", $min, 
                    ($hour+11)%12 + 1,
                    ($hour+ 11)%12 +1,
                    $hour,
                    $hour);

    return $ret;
}
              

# gets date in MySQL format, produces s2dateformat
# s2 dateformat is: yyyy mm dd hh mm ss day_of_week
sub alldatepart_s2 
{
    my $time = shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday) =
        gmtime(LJ::mysqldate_to_time($time, 1));
    return 
        sprintf("%04d %02d %02d %02d %02d %02d %01d",
                $year+1900, 
                $mon+1, 
                $mday, 
                $hour, 
                $min, 
                $sec, 
                $wday);
}
                                                                                

# <LJFUNC>
# name: LJ::get_keyword_id
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub get_keyword_id
{
    &nodb;
    my $kw = shift;
    unless ($kw =~ /\S/) { return 0; }
    $kw = LJ::text_trim($kw, LJ::BMAX_KEYWORD, LJ::CMAX_KEYWORD);

    my $dbh = LJ::get_db_writer();
    my $qkw = $dbh->quote($kw);

    # Making this a $dbr could cause problems due to the insertion of
    # data based on the results of this query. Leave as a $dbh.
    my $sth = $dbh->prepare("SELECT kwid FROM keywords WHERE keyword=$qkw");
    $sth->execute;
    my ($kwid) = $sth->fetchrow_array;
    unless ($kwid) {
        $sth = $dbh->prepare("INSERT INTO keywords (kwid, keyword) VALUES (NULL, $qkw)");
        $sth->execute;
        $kwid = $dbh->{'mysql_insertid'};
    }
    return $kwid;
}

# <LJFUNC>
# name: LJ::trim
# class: text
# des: Removes whitespace from left and right side of a string.
# args: string
# des-string: string to be trimmed
# returns: string trimmed
# </LJFUNC>
sub trim
{
    my $a = $_[0];
    $a =~ s/^\s+//;
    $a =~ s/\s+$//;
    return $a;
}

# <LJFUNC>
# name: LJ::delete_user
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub delete_user
{
                # TODO: Is this function even being called?
                # It doesn't look like it does anything useful
    my $dbh = shift;
    my $user = shift;
    my $quser = $dbh->quote($user);
    my $sth;
    $sth = $dbh->prepare("SELECT user, userid FROM useridmap WHERE user=$quser");
    my $u = $sth->fetchrow_hashref;
    unless ($u) { return; }

    ### so many issues.
}

# <LJFUNC>
# name: LJ::hash_password
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub hash_password
{
    return Digest::MD5::md5_hex($_[0]);
}

# <LJFUNC>
# name: LJ::can_use_journal
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub can_use_journal
{
    &nodb;
    my ($posterid, $reqownername, $res) = @_;

    ## find the journal owner's info
    my $uowner = LJ::load_user($reqownername);
    unless ($uowner) {
        $res->{'errmsg'} = "Journal \"$reqownername\" does not exist.";
        return 0;
    }
    my $ownerid = $uowner->{'userid'};

    # the 'ownerid' necessity came first, way back when.  but then
    # with clusters, everything needed to know more, like the
    # journal's dversion and clusterid, so now it also returns the
    # user row.
    $res->{'ownerid'} = $ownerid;
    $res->{'u_owner'} = $uowner;

    ## check if user has access
    return 1 if LJ::check_rel($ownerid, $posterid, 'P');

    # let's check if this community is allowing post access to non-members 
    LJ::load_user_props($uowner, "nonmember_posting");
    if ($uowner->{'nonmember_posting'}) {
        my $dbr = LJ::get_db_reader() or die "nodb";
        my $postlevel = $dbr->selectrow_array("SELECT postlevel FROM ".
                                              "community WHERE userid=$ownerid");
        return 1 if $postlevel eq 'members';
    }

    # is the poster an admin for this community?
    return 1 if LJ::can_manage($posterid, $uowner);

    $res->{'errmsg'} = "You do not have access to post to this journal.";
    return 0;
}

sub can_add_syndicated
{
    my ($u, $su) = @_;  # user and syndicated user
    my $quota = LJ::get_cap($u, "synd_quota");
    return 0 unless $quota;

    my $used;

    # see where we're
    my $dbh = LJ::get_dbh("master");
    my $sth = $dbh->prepare("SELECT s.userid, COUNT(*) FROM syndicated s, friends fa, friends fb ".
                            "WHERE fa.userid=? AND fa.friendid=s.userid  ".
                            "AND fb.friendid=s.userid GROUP BY 1");
    $sth->execute($u->{'userid'});
    while (my ($sid, $ct) = $sth->fetchrow_array) {
        # if user already has this friend, doesn't change their count to add it again.
        return 1 if ($sid == $su->{'userid'});
        $used += LJ::syn_cost($ct);
        return 0 if $used > $quota;
    }
    
    # they're under quota so far.  would this account push them over?
    my $ct = $dbh->selectrow_array("SELECT COUNT(*) FROM friends WHERE friendid=?", undef,
                                   $su->{'userid'});
    $used += LJ::syn_cost($ct + 1);
    return 0 if $used > $quota;
    return 1;
}

sub set_logprop
{
    my ($u, $jitemid, $hashref, $logprops) = @_;  # hashref to set, hashref of what was done
    my $dbcm = LJ::get_cluster_master($u);

    $jitemid += 0;
    my $uid = $u->{'userid'} + 0;
    my $kill_mem = 0;
    my $del_ids;
    my $ins_values;
    while (my ($k, $v) = each %{$hashref||{}}) {
        my $prop = LJ::get_prop("log", $k);
        next unless $prop;
        $kill_mem = 1 unless $prop eq "commentalter";
        if ($v) {
            $ins_values .= "," if $ins_values;
            $ins_values .= "($uid, $jitemid, $prop->{'id'}, " . $dbcm->quote($v) . ")";
            $logprops->{$k} = $v;
        } else {
            $del_ids .= "," if $del_ids;
            $del_ids .= $prop->{'id'};
        }
    }
    
    $dbcm->do("REPLACE INTO logprop2 (journalid, jitemid, propid, value) ".
              "VALUES $ins_values") if $ins_values;
    $dbcm->do("DELETE FROM logprop2 WHERE journalid=? AND jitemid=? ".
              "AND propid IN ($del_ids)", undef, $u->{'userid'}, $jitemid) if $del_ids;

    LJ::MemCache::delete([$uid,"logprop:$uid:$jitemid"]) if $kill_mem;
}

# <LJFUNC>
# name: LJ::load_log_props2
# des: Loads the values from the logprop2 table for a journal entry
# args: db?, jjournalid, itemsref, propsref
# des-db: optional database handle
# des-jjournalid: ID of journal whose items to retrieve properties for
# des-itemsref: reference to list of itemids to retrieve properties for
# des-propsref: reference to hash where properties will be stored
# </LJFUNC>
sub load_log_props2
{
    my $db = isdb($_[0]) ? shift @_ : undef;

    my ($jjournalid, $itemsref, $propsref) = @_;
    my $journalid = want_userid($jjournalid);
    return unless ref $hashref eq "HASH";
    
    my %needprops;
    my %needrc;
    my %rc;
    my @memkeys;
    foreach (@$itemsref) {
        my $id = $_+0;
        $needprops{$id} = 1;
        $needrc{$id} = 1;
        push @memkeys, [$userid, "logprop:$userid:$id"];
        push @memkeys, [$userid, "rp:$userid:$id"];
    }
    return unless %needprops || %needrc;

    my $mem = LJ::MemCache::get_multi(@memkeys) || {};
    while (my ($k, $v) = each %$mem) {
        next unless $k =~ /(\w+):(\d+):(\d+)/;
        if ($1 eq 'logprop') {
            next unless ref $v eq "HASH";
            delete $needprops{$3};
            $propsref->{$3} = $v;
        }
        if ($1 eq 'rp') {
            delete $needrc{$3};
            $rc{$3} = int($v);  # change possible "0   " (true) to "0" (false)
        }
    }

    foreach (keys %rc) {
        $propsref->{$_}{'replycount'} = $rc{$_};
    }

    return unless %needprops || %needrc;

    unless ($db) {
        my $u = LJ::load_userid($journalid);
        $db = @LJ::MEMCACHE_SERVERS ? LJ::get_cluster_master($u) :  LJ::get_cluster_reader($u);
        return unless $db;
    }

    if (%needprops) {
        LJ::load_props("log");
        my $in = join(",", keys %needprops);
        my $sth = $db->prepare("SELECT jitemid, propid, value FROM logprop2 ".
                                 "WHERE journalid=? AND jitemid IN ($in)");
        $sth->execute($journalid);
        while (my ($jitemid, $propid, $value) = $sth->fetchrow_array) {
            $propsref->{$jitemid}->{$LJ::CACHE_PROPID{'log'}->{$propid}->{'name'}} = $value;
        }
        foreach my $id (keys %needprops) {
            LJ::MemCache::set([$journalid,"logprop:$journalid:$id"], $propsref->{$id} || {});
          }
    }

    if (%needrc) {
        my $in = join(",", keys %needrc);
        my $sth = $db->prepare("SELECT jitemid, replycount FROM log2 WHERE journalid=? AND jitemid IN ($in)");
        $sth->execute($journalid);
        while (my ($jitemid, $rc) = $sth->fetchrow_array) {
            $propsref->{$jitemid}->{'replycount'} = $rc;
            LJ::MemCache::add([$journalid, "rp:$journalid:$jitemid"], $rc);
        }
    }                  
        

}

# <LJFUNC>
# name: LJ::load_log_props2multi
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub load_log_props2multi
{
    &nodb;    
    my ($ids, $props) = @_;
    _get_posts_raw_wrapper($ids, "prop", $props);
}

# <LJFUNC>
# name: LJ::load_talk_props2
# class:
# des:
# info:
# args:
# des-:
# returns:
# </LJFUNC>
sub load_talk_props2
{
    my $db = isdb($_[0]) ? shift @_ : undef;
    my ($uuserid, $listref, $hashref) = @_;

    my $userid = want_userid($uuserid);
    my $u = ref $uuserid ? $uuserid : undef;

    $hashref = {} unless ref $hashref eq "HASH";

    my %need;
    my @memkeys;
    foreach (@$listref) {
        my $id = $_+0;
        $need{$id} = 1;
        push @memkeys, [$userid,"talkprop:$userid:$id"];
    }
    return $hashref unless %need;

    my $mem = LJ::MemCache::get_multi(@memkeys) || {};
    while (my ($k, $v) = each %$mem) {
        next unless $k =~ /(\d+):(\d+)/ && ref $v eq "HASH";
        delete $need{$2};
        $hashref->{$2}->{$_[0]} = $_[1] while @_ = each %$v;
    }
    return $hashref unless %need;

    if (!$db || @LJ::MEMCACHE_SERVERS) {
        $u ||= LJ::load_userid($userid);
        $db = @LJ::MEMCACHE_SERVERS ? LJ::get_cluster_master($u) :  LJ::get_cluster_reader($u);
        return $hashref unless $db;
    }

    LJ::load_props("talk");
    my $in = join(',', keys %need);
    my $sth = $db->prepare("SELECT jtalkid, tpropid, value FROM talkprop2 ".
                           "WHERE journalid=? AND jtalkid IN ($in)");
    $sth->execute($userid);
    while (my ($jtalkid, $propid, $value) = $sth->fetchrow_array) {
        my $p = $LJ::CACHE_PROPID{'talk'}->{$propid};
        next unless $p;
        $hashref->{$jtalkid}->{$p->{'name'}} = $value;
    }
    foreach my $id (keys %need) {
        LJ::MemCache::set([$userid,"talkprop:$userid:$id"], $hashref->{$id} || {});
    }
    return $hashref;
}

# <LJFUNC>
# name: LJ::eurl
# class: text
# des: Escapes a value before it can be put in a URL.  See also [func[LJ::durl]].
# args: string
# des-string: string to be escaped
# returns: string escaped
# </LJFUNC>
sub eurl
{
    my $a = $_[0];
    $a =~ s/([^a-zA-Z0-9_\,\-.\/\\\: ])/uc sprintf("%%%02x",ord($1))/eg;
    $a =~ tr/ /+/;
    return $a;
}

# <LJFUNC>
# name: LJ::durl
# class: text
# des: Decodes a value that's URL-escaped.  See also [func[LJ::eurl]].
# args: string
# des-string: string to be decoded
# returns: string decoded
# </LJFUNC>
sub durl
{
    my ($a) = @_;
    $a =~ tr/+/ /;
    $a =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    return $a;
}

# <LJFUNC>
# name: LJ::exml
# class: text
# des: Escapes a value before it can be put in XML.
# args: string
# des-string: string to be escaped
# returns: string escaped.
# </LJFUNC>
sub exml
{
    my $a = shift;
    $a =~ s/\&/&amp;/g;
    $a =~ s/\"/&quot;/g;
    $a =~ s/\'/&apos;/g;
    $a =~ s/</&lt;/g;
    $a =~ s/>/&gt;/g;
    return $a;
}

# <LJFUNC>
# name: LJ::ehtml
# class: text
# des: Escapes a value before it can be put in HTML.
# args: string
# des-string: string to be escaped
# returns: string escaped.
# </LJFUNC>
sub ehtml
{
    my $a = $_[0];
    $a =~ s/\&/&amp;/g;
    $a =~ s/\"/&quot;/g;
    $a =~ s/\'/&\#39;/g;
    $a =~ s/</&lt;/g;
    $a =~ s/>/&gt;/g;
    return $a;
}
*eall = \&ehtml;  # old BML syntax required eall to also escape BML.  not anymore.

# <LJFUNC>
# name: LJ::etags
# class: text
# des: Escapes < and > from a string
# args: string
# des-string: string to be escaped
# returns: string escaped.
# </LJFUNC>
sub etags
{
    my $a = $_[0];
    $a =~ s/</&lt;/g;
    $a =~ s/>/&gt;/g;
    return $a;
}

# <LJFUNC>
# name: LJ::ejs
# class: text
# des: Escapes a string value before it can be put in JavaScript.
# args: string
# des-string: string to be escaped
# returns: string escaped.
# </LJFUNC>
sub ejs
{
    my $a = $_[0];
    $a =~ s/[\"\'\\]/\\$&/g;
    $a =~ s/\r?\n/\\n/gs;
    return $a;
}

# <LJFUNC>
# name: LJ::days_in_month
# class: time
# des: Figures out the number of days in a month.
# args: month, year?
# des-month: Month
# des-year: Year.  Necessary for February.  If undefined or zero, function
#           will return 29.
# returns: Number of days in that month in that year.
# </LJFUNC>
sub days_in_month
{
    my ($month, $year) = @_;
    if ($month == 2)
    {
        return 29 unless $year;  # assume largest
        if ($year % 4 == 0)
        {
          # years divisible by 400 are leap years
          return 29 if ($year % 400 == 0);

          # if they're divisible by 100, they aren't.
          return 28 if ($year % 100 == 0);

          # otherwise, if divisible by 4, they are.
          return 29;
        }
    }
    return ((31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[$month-1]);
}

sub day_of_week
{
    my ($year, $month, $day) = @_;
    my $time = Time::Local::timelocal(0,0,0,$day,$month-1,$year);
    return (localtime($time))[6];
}

# <LJFUNC>
# name: LJ::delete_entry
# des: Deletes a user's journal entry
# args: uuserid, jitemid, quick?, anum?
# des-uuserid: Journal itemid or $u object of journal to delete entry from
# des-jitemid: Journal itemid of item to delete.
# des-quick: Optional boolean.  If set, only [dbtable[log2]] table
#            is deleted from and the rest of the content is deleted
#            later using [func[LJ::cmd_buffer_add]].
# des-anum: The log item's anum, which'll be needed to delete lazily
#           some data in tables which includes the anum, but the
#           log row will already be gone so we'll need to store it for later.
# returns: boolean; 1 on success, 0 on failure.
# </LJFUNC>
sub delete_entry
{
    my ($uuserid, $jitemid, $quick, $anum) = @_;
    my $jid = LJ::want_userid($uuserid);
    my $u = ref $uuserid ? $uuserid : LJ::load_userid($jid);
    $jitemid += 0;

    my $dbcm = LJ::get_cluster_master($u);
    return 0 unless $dbcm;

    my $and;
    if (defined $anum) { $and = "AND anum=" . ($anum+0); }

    my $dc = LJ::log2_do($dbcm, $jid, undef, "DELETE FROM log2 WHERE journalid=$jid AND jitemid=$jitemid $and");
    LJ::MemCache::delete([$jid, "log2:$jid:$jitemid"]);
    LJ::MemCache::decr([$jid, "log2ct:$jid"]);

    # if this is running the second time (started by the cmd buffer),
    # the log2 row will already be gone and we shouldn't check for it.
    if ($quick) {
        return 1 if $dc < 1;  # already deleted?
        return LJ::cmd_buffer_add($dbcm, $jid, "delitem", {
            'itemid' => $jitemid,
            'anum' => $anum,
        });
    }

    # delete from clusters
    foreach my $t (qw(logtext2 logprop2 logsec2)) {
        $dbcm->do("DELETE FROM $t WHERE journalid=$jid AND jitemid=$jitemid");
    }
    LJ::dudata_set($dbcm, $jid, 'L', $jitemid, 0);

    # delete stuff from meta cluster
    my $aitemid = $jitemid * 256 + $anum;
    my $dbh = LJ::get_db_writer();
    foreach my $t (qw(memorable)) {
        $dbh->do("DELETE FROM $t WHERE journalid=$jid AND jitemid=$aitemid");
    }

    LJ::delete_all_comments($u, 'L', $jitemid);

    return 1;
}

# <LJFUNC>
# name: LJ::delete_all_comments
# des: deletes all comments from a post, permanently, for when a post is deleted
# info: The tables [dbtable[talk2]], [dbtable[talkprop2]], [dbtable[talktext2]],
#       are deleted from, immediately.
# args: u, nodetype, nodeid
# des-nodetype: The thread nodetype (probably 'L' for log items)
# des-nodeid: The thread nodeid for the given nodetype (probably the jitemid from the log2 row)
# returns: boolean; success value
# </LJFUNC>
sub delete_all_comments {
    my ($u, $nodetype, $nodeid) = @_;

    my $dbcm = LJ::get_cluster_master($u);
    return 0 unless $dbcm;

    # delete comments
    my ($t, $loop) = (undef, 1);
    my $chunk_size = 200;
    while ($loop &&
           ($t = $dbcm->selectcol_arrayref("SELECT jtalkid FROM talk2 WHERE ".
                                           "nodetype=? AND journalid=? ".
                                           "AND nodeid=? LIMIT $chunk_size", undef,
                                           $nodetype, $u->{'userid'}, $nodeid))
           && $t && @$t)
    {
        my $in = join(',', map { $_+0 } @$t);
        return 1 unless $in;
        foreach my $table (qw(talkprop2 talktext2 talk2)) {
            $dbcm->do("DELETE FROM $table WHERE journalid=? AND jtalkid IN ($in)",
                      undef, $u->{'userid'});
        }
        # decrement memcache
        LJ::MemCache::decr([$u->{'userid'}, "talk2ct:$u->{'userid'}"], scalar(@$t));
        $loop = 0 unless @$t == $chunk_size;
    }
    return 1;
    
}

# <LJFUNC>
# name: LJ::memcache_kill
# des: Kills a memcache entry, given a userid and type
# args: uuserid, type
# des-uuserid: a userid or u object
# des-args: memcache key type, will be used as "$type:$userid"
# returns: results of LJ::MemCache::delete
# </LJFUNC>
sub memcache_kill {
    my ($uuid, $type) = @_;
    my $userid = want_userid($uuid);
    return undef unless $userid && $type;

    return LJ::MemCache::delete([$userid, "$type:$userid"]);
}

# all reads/writes to talk2 must be done inside a lock, so there's
# no race conditions between reading from db and putting in memcache.
# can't do a db write in between those 2 steps.  the talk2 -> memcache
# is elsewhere (talklib.pl), but this $dbh->do wrapper is provided
# here because non-talklib things modify the talk2 table, and it's
# nice to centralize the locking rules.
#
# return value is return of $dbh->do.  $errref scalar ref is optional, and 
# if set, gets value of $dbh->errstr
#
# write:  (LJ::talk2_do)
#   GET_LOCK
#    update/insert into talk2
#   RELEASE_LOCK
#    delete memcache
#
# read:   (LJ::Talk::get_talk_data)
#   try memcache
#   GET_LOCk
#     read db
#     update memcache
#   RELEASE_LOCK

sub talk2_do {
    my ($dbcm, $uid, $nodetype, $nodeid, $errref, $sql, @args) = @_;
    return undef unless $nodetype =~ /^\w$/;
    return undef unless $nodeid =~ /^\d+$/;
    return undef unless $uid =~ /^\d+$/;

    my $memkey = [$uid, "talk2:$uid:$nodetype:$nodeid"];
    my $lockkey = $memkey->[1];

    $dbcm->selectrow_array("SELECT GET_LOCK(?,10)", undef, $lockkey);
    my $ret = $dbcm->do($sql, undef, @args);
    if (ref $errref) { $$errref = $dbcm->errstr; }
    $dbcm->selectrow_array("SELECT RELEASE_LOCK(?)", undef, $lockkey);

    LJ::MemCache::delete($memkey, 0) if int($ret);
    return $ret;
}

# log2_do
# see comments for talk2_do

sub log2_do {
    my ($db, $uid, $errref, $sql, @args) = @_;
    return undef unless $uid =~ /^\d+$/;

    my $memkey = [$uid, "log2lt:$uid"];
    my $lockkey = $memkey->[1];

    $db->selectrow_array("SELECT GET_LOCK(?,10)", undef, $lockkey);
    my $ret = $db->do($sql, undef, @args);
    if (ref $errref) { $$errref = $db->errstr; }
    $db->selectrow_array("SELECT RELEASE_LOCK(?)", undef, $lockkey);

    LJ::MemCache::delete($memkey, 0) if int($ret);
    return $ret;
}

# <LJFUNC>
# name: LJ::friends_do
# des: Runs given sql, then deletes the given userid's friends from memcache
# args: uuserid, sql, args
# des-uuserid: a userid or u object
# des-sql: sql to run via $dbh->do()
# des-args: a list of arguments to pass use via: $dbh->do($sql, undef, @args)
# returns: results of $dbh->do()
# </LJFUNC>
sub friends_do {
    my ($uuid, $sql, @args) = @_;
    my $uid = want_userid($uuid);
    return undef unless $uid && $sql;

    my $dbh = LJ::get_db_writer();
    my $ret = $dbh->do($sql, undef, @args);

    LJ::memcache_kill($uid, "friends");

    return $ret;
}

# replycount_do
# input: $u, $jitemid, $action, $value
# action is one of: "init", "incr", "decr"
# $value is amount to incr/decr, 1 by default

sub replycount_do {
    my ($u, $jitemid, $action, $value) = @_;
    $value = 1 unless defined $value;
    my $uid = $u->{'userid'};
    my $memkey = [$uid, "rp:$uid:$jitemid"];

    # "init" is easiest and needs no lock (called before the entry is live)
    if ($action eq 'init') {
        LJ::MemCache::set($memkey, "0   ");
        return;
    }

    my $db = LJ::get_cluster_master($u);
    my $lockkey = $memkey->[1];
    $db->selectrow_array("SELECT GET_LOCK(?,10)", undef, $lockkey);

    my $ret;

    if ($action eq 'decr') {
        $ret = LJ::MemCache::decr($memkey, $value);
        $db->do("UPDATE log2 SET replycount=replycount-$value WHERE journalid=$uid AND jitemid=$jitemid");
    }

    if ($action eq 'incr') {
        $ret = LJ::MemCache::incr($memkey, $value);
        $db->do("UPDATE log2 SET replycount=replycount+$value WHERE journalid=$uid AND jitemid=$jitemid");
    }

    unless (defined $ret) {
        my $rc = $db->selectrow_array("SELECT replycount FROM log2 WHERE journalid=$uid AND jitemid=$jitemid");
        if (defined $rc) {
            $rc = sprintf("%-4d", $rc);
            LJ::MemCache::set($memkey, $rc);
        }
    }

    $db->selectrow_array("SELECT RELEASE_LOCK(?)", undef, $lockkey);

    return;
}

# <LJFUNC>
# name: LJ::delete_comments
# des: deletes comments, but not the relational information, so threading doesn't break
# info: The tables [dbtable[talkprop2]] and [dbtable[talktext2]] are deleted from.  [dbtable[talk2]]
#       just has its state column modified to 'D'.
# args: u, nodetype, nodeid, talkids+
# des-nodetype: The thread nodetype (probably 'L' for log items)
# des-nodeid: The thread nodeid for the given nodetype (probably the jitemid from the log2 row)
# des-talkids: List of talkids to delete.
# returns: scalar integer; number of items deleted.
# </LJFUNC>
sub delete_comments {
    my ($u, $nodetype, $nodeid, @talkids) = @_;

    my $dbcm = LJ::get_cluster_master($u);
    return 0 unless $dbcm;

    my $jid = $u->{'userid'}+0;
    my $in = join(',', map { $_+0 } @talkids);
    return 1 unless $in;
    my $where = "WHERE journalid=$jid AND jtalkid IN ($in)";

    my $num = LJ::talk2_do($dbcm, $jid, $nodetype, $nodeid, undef,
                           "UPDATE talk2 SET state='D' $where");
    $num = 0 if $num == -1;

    if ($num > 0) {
        $dbcm->do("UPDATE talktext2 SET subject=NULL, body=NULL $where");
        $dbcm->do("DELETE FROM talkprop2 WHERE $where");
    }
    return $num;
}

# <LJFUNC>
# name: LJ::dudata_set
# class: logging
# des: Record or delete disk usage data for a journal
# args: dbcm, journalid, area, areaid, bytes
# journalid: Journal userid to record space for.
# area: One character: "L" for log, "T" for talk, "B" for bio, "P" for pic.
# areaid: Unique ID within $area, or '0' if area has no ids (like bio)
# bytes: Number of bytes item takes up.  Or 0 to delete record.
# returns: 1.
# </LJFUNC>
sub dudata_set
{
    my ($dbcm, $journalid, $area, $areaid, $bytes) = @_;
    $bytes += 0; $areaid += 0; $journalid += 0;
    $area = $dbcm->quote($area);
    if ($bytes) {
        $dbcm->do("REPLACE INTO dudata (userid, area, areaid, bytes) ".
                  "VALUES ($journalid, $area, $areaid, $bytes)");
    } else {
        $dbcm->do("DELETE FROM dudata WHERE userid=$journalid AND ".
                  "area=$area AND areaid=$areaid");
    }
    return 1;
}

# <LJFUNC>
# name: LJ::color_fromdb
# des: Takes a value of unknown type from the db and returns an #rrggbb string.
# args: color
# des-color: either a 24-bit decimal number, or an #rrggbb string.
# returns: scalar; #rrggbb string, or undef if unknown input format
# </LJFUNC>
sub color_fromdb
{
    my $c = shift;
    return $c if $c =~ /^\#[0-9a-f]{6,6}$/i;
    return sprintf("\#%06x", $c) if $c =~ /^\d+$/;
    return undef;
}

# <LJFUNC>
# name: LJ::color_todb
# des: Takes an #rrggbb value and returns a 24-bit decimal number.
# args: color
# des-color: scalar; an #rrggbb string.
# returns: undef if bogus color, else scalar; 24-bit decimal number, can be up to 8 chars wide as a string.
# </LJFUNC>
sub color_todb
{
    my $c = shift;
    return undef unless $c =~ /^\#[0-9a-f]{6,6}$/i;
    return hex(substr($c, 1, 6));
}

# <LJFUNC>
# name: LJ::add_friend
# des: Simple interface to add a friend edge.
# args: userida, useridb, opts?
# des-userida: Userid of source user (befriender)
# des-useridb: Userid of target user (befriendee)
# des-opts: hashref; 'defaultview' key means add $useridb to $userida's Default View friends group
# returns: boolean; 1 on success (or already friend), 0 on failure (bogus args)
# </LJFUNC>
sub add_friend
{
    &nodb;    
    my ($ida, $idb, $opts) = @_;

    $ida += 0; $idb += 0; 
    return 0 unless $ida and $idb;
    
    my $dbh = LJ::get_db_writer();

    my $black = LJ::color_todb("#000000");
    my $white = LJ::color_todb("#ffffff");

    my $groupmask = 1;
    if ($opts->{'defaultview'}) {
        my $grp = $dbh->selectrow_array("SELECT groupnum FROM friendgroup WHERE userid=? AND groupname='Default View'", undef, $ida);
        $groupmask |= (1 << $grp) if $grp;
    }

    LJ::friends_do($ida,
                   "INSERT INTO friends (userid, friendid, fgcolor, bgcolor, groupmask) " .
                   "VALUES (?,?,?,?,?)", $ida, $idb, $black, $white, $groupmask);

    return 1;
}

# <LJFUNC>
# name: LJ::event_register
# des: Logs a subscribable event, if anybody's subscribed to it.
# args: dbarg?, dbc, etype, ejid, eiarg, duserid, diarg
# des-dbc: Cluster master of event
# des-type: One character event type.
# des-ejid: Journalid event occured in.
# des-eiarg: 4 byte numeric argument
# des-duserid: Event doer's userid
# des-diarg: Event's 4 byte numeric argument
# returns: boolean; 1 on success; 0 on fail.
# </LJFUNC>
sub event_register
{
    &nodb;    
    my ($dbc, $etype, $ejid, $eiarg, $duserid, $diarg) = @_;
    my $dbr = LJ::get_db_reader();

    # see if any subscribers first of all (reads cheap; writes slow)
    return 0 unless $dbr;
    my $qetype = $dbr->quote($etype);
    my $qejid = $ejid+0;
    my $qeiarg = $eiarg+0;
    my $qduserid = $duserid+0;
    my $qdiarg = $diarg+0;

    my $has_sub = $dbr->selectrow_array("SELECT userid FROM subs WHERE etype=$qetype AND ".
                                        "ejournalid=$qejid AND eiarg=$qeiarg LIMIT 1");
    return 1 unless $has_sub;

    # so we're going to need to log this event
    return 0 unless $dbc;
    $dbc->do("INSERT INTO events (evtime, etype, ejournalid, eiarg, duserid, diarg) ".
             "VALUES (NOW(), $qetype, $qejid, $qeiarg, $qduserid, $qdiarg)");
    return $dbc->err ? 0 : 1;
}

# <LJFUNC>
# name: LJ::procnotify_add
# des: Sends a message to all other processes on all clusters.
# info: You'll probably never use this yourself.
# args: cmd, args?
# des-cmd: Command name.  Currently recognized: "DBI::Role::reload" and "rename_user"
# des-args: Hashref with key/value arguments for the given command.  See
#           relevant parts of [func[LJ::procnotify_callback]] for required args for different commands.
# returns: new serial number on success; 0 on fail.
# </LJFUNC>
sub procnotify_add
{
    &nodb;
    my ($cmd, $argref) = @_;
    my $dbh = LJ::get_db_writer();
    return 0 unless $dbh;

    my $args = join('&', map { LJ::eurl($_) . "=" . LJ::eurl($argref->{$_}) }
                    sort keys %$argref);
    $dbh->do("INSERT INTO procnotify (cmd, args) VALUES (?,?)",
             undef, $cmd, $args);

    return 0 if $dbh->err;
    return $dbh->{'mysql_insertid'};
}

# <LJFUNC>
# name: LJ::procnotify_callback
# des: Call back function process notifications.
# info: You'll probably never use this yourself.
# args: cmd, argstring
# des-cmd: Command name.
# des-argstring: String of arguments.
# returns: new serial number on success; 0 on fail.
# </LJFUNC>
sub procnotify_callback
{
    my ($cmd, $argstring) = @_;
    my $arg = {};
    LJ::decode_url_string($argstring, $arg);
    
    if ($cmd eq "rename_user") {
        # this looks backwards, but the cache hash names are just odd:
        delete $LJ::CACHE_USERNAME{$arg->{'userid'}};
        delete $LJ::CACHE_USERID{$arg->{'user'}};
        return;
    }

    # ip bans
    if ($cmd eq "ban_ip") {
        $LJ::IP_BANNED{$arg->{'ip'}} = $arg->{'exptime'};
        return;
    }

    if ($cmd eq "unban_ip") {
        delete $LJ::IP_BANNED{$arg->{'ip'}};
        return;
    }

    # uniq key bans
    if ($cmd eq "ban_uniq") {
        $LJ::UNIQ_BANNED{$arg->{'uniq'}} = $arg->{'exptime'};
        return;
    }

    if ($cmd eq "unban_uniq") {
        delete $LJ::UNIQ_BANNED{$arg->{'uniq'}};
        return;
    }
}

sub procnotify_check
{
    my $now = time;
    return if $LJ::CACHE_PROCNOTIFY_CHECK + 30 > $now;
    $LJ::CACHE_PROCNOTIFY_CHECK = $now;

    my $dbr = LJ::get_db_reader();
    my $max = $dbr->selectrow_array("SELECT MAX(nid) FROM procnotify");
    return unless defined $max;
    my $old = $LJ::CACHE_PROCNOTIFY_MAX;
    if (defined $old && $max > $old) {
        my $sth = $dbr->prepare("SELECT cmd, args FROM procnotify ".
                                "WHERE nid > ? AND nid <= $max ORDER BY nid");
        $sth->execute($old);
        while (my ($cmd, $args) = $sth->fetchrow_array) {
            LJ::procnotify_callback($cmd, $args);
        }
    }
    $LJ::CACHE_PROCNOTIFY_MAX = $max;
}

sub dbtime_callback {
    my ($dsn, $dbtime, $time) = @_;
    my $diff = abs($dbtime - $time);
    if ($diff > 2) {
        $dsn =~ /host=([^:\;\|]*)/;
        my $db = $1;
        print STDERR "Clock skew of $diff seconds between web($LJ::SERVER_NAME) and db($db)\n";
    }
}

# <LJFUNC>
# name: LJ::is_ascii
# des: checks if text is pure ASCII
# args: text
# des-text: text to check for being pure 7-bit ASCII text
# returns: 1 if text is indeed pure 7-bit, 0 otherwise.
# </LJFUNC>
sub is_ascii {
    my $text = shift;
    return ($text !~ m/[\x00\x80-\xff]/);
}

# <LJFUNC>
# name: LJ::is_utf8
# des: check text for UTF-8 validity
# args: text
# des-text: text to check for UTF-8 validity
# returns: 1 if text is a valid UTF-8 stream, 0 otherwise.
# </LJFUNC>
sub is_utf8 {
    my $text = shift;

    if (LJ::are_hooks("is_utf8")) {
        return LJ::run_hook("is_utf8", $text);
    }

    # for a discussion of the different utf8 validity checking methods,
    # see:  http://zilla.livejournal.org/657
    # in summary, this isn't the fastest, but it's pretty fast, it doesn't make
    # perl segfault, and it doesn't add new crazy dependencies.  if you want
    # speed, check out ljcom's is_utf8 version in C, using Inline.pm

    my $u = Unicode::String::utf8($text);
    my $text2 = $u->utf8;
    return $text eq $text2;
}

# <LJFUNC>
# name: LJ::text_out
# des: force outgoing text into valid UTF-8
# args: text
# des-text: reference to text to pass to output. Text if modified in-place.
# returns: nothing.
# </LJFUNC>
sub text_out
{
    my $rtext = shift;

    # if we're not Unicode, do nothing
    return unless $LJ::UNICODE;

    # is this valid UTF-8 already?
    return if LJ::is_utf8($$rtext);

    # no. Blot out all non-ASCII chars
    $$rtext =~ s/[\x00\x80-\xff]/\?/g;
    return;
}

# <LJFUNC>
# name: LJ::text_in
# des: do appropriate checks on input text. Should be called on all
#      user-generated text.
# args: text
# des-text: text to check
# returns: 1 if the text is valid, 0 if not.
# </LJFUNC>
sub text_in
{
    my $text = shift;
    return 1 unless $LJ::UNICODE;
    if (ref ($text) eq "HASH") {
        return ! (grep { !LJ::is_utf8($_) } values %{$text});
    }
    if (ref ($text) eq "ARRAY") {
        return ! (grep { !LJ::is_utf8($_) } @{$text});
    }
    return LJ::is_utf8($text);
}

# <LJFUNC>
# name: LJ::text_convert
# des: convert old entries/comments to UTF-8 using user's default encoding
# args: dbs?, text, u, error
# des-text: old possibly non-ASCII text to convert
# des-u: user hashref of the journal's owner
# des-error: ref to a scalar variable which is set to 1 on error 
#            (when user has no default encoding defined, but 
#            text needs to be translated)
# returns: converted text or undef on error
# </LJFUNC>
sub text_convert
{
    &nodb;
    my ($text, $u, $error) = @_;

    # maybe it's pure ASCII?
    return $text if LJ::is_ascii($text);

    # load encoding id->name mapping if it's not loaded yet
    LJ::load_codes({ "encoding" => \%LJ::CACHE_ENCODINGS } )
        unless %LJ::CACHE_ENCODINGS;

    if ($u->{'oldenc'} == 0 ||
        not defined $LJ::CACHE_ENCODINGS{$u->{'oldenc'}}) {
        $$error = 1;
        return undef;
    };

    # convert!
    my $name = $LJ::CACHE_ENCODINGS{$u->{'oldenc'}};
    unless (Unicode::MapUTF8::utf8_supported_charset($name)) {
        $$error = 1;
        return undef;
    }

    return Unicode::MapUTF8::to_utf8({-string=>$text, -charset=>$name});
}


# <LJFUNC>
# name: LJ::text_length
# des: returns both byte length and character length of a string. In a non-Unicode
#      environment, this means byte length twice. In a Unicode environment,
#      the function assumes that its argument is a valid UTF-8 string.
# args: text
# des-text: the string to measure
# returns: a list of two values, (byte_length, char_length).
# </LJFUNC>

sub text_length 
{
    my $text = shift;
    my $bl = length($text);
    unless ($LJ::UNICODE) {
        return ($bl, $bl);
    }
    my $cl = 0;
    my $utf_char = "([\x00-\x7f]|[\xc0-\xdf].|[\xe0-\xef]..|[\xf0-\xf7]...)";

    while ($text =~ m/$utf_char/go) { $cl++; }
    return ($bl, $cl);
}

# <LJFUNC>
# name: LJ::text_trim
# des: truncate string according to requirements on byte length, char
#      length, or both. "char length" means number of UTF-8 characters if
#      $LJ::UNICODE is set, or the same thing as byte length otherwise.
# args: text, byte_max, char_max
# des-text: the string to trim
# des-byte_max: maximum allowed length in bytes; if 0, there's no restriction
# des-char_max: maximum allowed length in chars; if 0, there's no restriction
# returns: the truncated string.
# </LJFUNC>
sub text_trim
{
    my ($text, $byte_max, $char_max) = @_;
    return $text unless $byte_max or $char_max;
    if ($char_max == 0 || !$LJ::UNICODE) {
        $byte_max = $char_max if $char_max and $char_max < $byte_max;
        $byte_max = $char_max unless $byte_max;
        return substr($text, 0, $byte_max);
    }
    my $cur = 0;
    my $utf_char = "([\x00-\x7f]|[\xc0-\xdf].|[\xe0-\xef]..|[\xf0-\xf7]...)";

    while ($text =~ m/$utf_char/gco) {
	last unless $char_max;
        last if $cur + length($1) > $byte_max and $byte_max;
        $cur += length($1);
        $char_max--;
    }
    return substr($text,0,$cur);
}

# <LJFUNC>
# name: LJ::text_compress
# des: Compresses a chunk of text, to gzip, if configured for site.  Can compress
#      a scalarref in place, or return a compressed copy.  Won't compress if
#      value is too small, already compressed, or size would grow by compressing.
# args: text
# des-test: either a scalar or scalarref
# returns: nothing if given a scalarref (to compress in-place), or original/compressed value,
#          depending on site config
# </LJFUNC>
sub text_compress
{
    my $text = shift;
    my $ref = ref $text;
    return $ref ? undef : $text unless $LJ::COMPRESS_TEXT;
    die "Invalid reference" if $ref && $ref ne "SCALAR";

    my $tref = $ref ? $text : \$text;
    my $pre_len = length($$tref);
    unless (substr($$tref,0,2) eq "\037\213" || $pre_len < 100) {
        my $gz = Compress::Zlib::memGzip($$tref);
        if (length($gz) < $pre_len) {
            $$tref = $gz;
        }
    }

    return $ref ? undef : $$tref;
}

# <LJFUNC>
# name: LJ::text_uncompress
# des: Uncompresses a chunk of text, from gzip, if configured for site.  Can uncompress
#      a scalarref in place, or return a compressed copy.  Won't uncompress unless
#      it finds the gzip magic number at the beginning of the text.
# args: text
# des-test: either a scalar or scalarref.
# returns: nothing if given a scalarref (to uncompress in-place), or original/uncompressed value,
#          depending on if test was compressed or not
# </LJFUNC>
sub text_uncompress
{
    my $text = shift;
    my $ref = ref $text;
    die "Invalid reference" if $ref && $ref ne "SCALAR";
    my $tref = $ref ? $text : \$text;

    # check for gzip's magic number
    if (substr($$tref,0,2) eq "\037\213") {
        $$tref = Compress::Zlib::memGunzip($$tref);
    }
    
    return $ref ? undef : $$tref;
}

# <LJFUNC>
# name: LJ::item_toutf8
# des: convert one item's subject, text and props to UTF8.
#      item can be an entry or a comment (in which cases props can be
#      left empty, since there are no 8bit talkprops).
# args: u, subject, text, props
# des-u: user hashref of the journal's owner
# des-subject: ref to the item's subject
# des-text: ref to the item's text
# des-props: hashref of the item's props
# returns: nothing.
# </LJFUNC>
sub item_toutf8
{
    my ($u, $subject, $text, $props) = @_;
    return unless $LJ::UNICODE;

    my $convert = sub {
        my $rtext = shift;
        my $error = 0;
        my $res = LJ::text_convert($$rtext, $u, \$error);
        if ($error) {
	    LJ::text_out($rtext);
        } else {
            $$rtext = $res;
        };
        return;
    };

    $convert->($subject);
    $convert->($text);
    foreach(keys %$props) {
        $convert->(\$props->{$_});
    }
    return;
}

# <LJFUNC>
# name: LJ::set_interests
# des: Change a user's interests
# args: dbarg?, u, old, new
# arg-old: hashref of old interests (hasing being interest => intid)
# arg-new: listref of new interests
# returns: 1
# </LJFUNC>
sub set_interests
{
    &nodb;    

    my ($u, $old, $new) = @_;

    $u = ref $u eq 'HASH' ? $u : LJ::load_userid($u);
    my $userid = $u->{'userid'};
    return unless $userid;

    my $dbh = LJ::get_db_writer();
    my %int_new = ();
    my %int_del = %$old;  # assume deleting everything, unless in @$new

    # user interests go in a different table than user interests,
    # though the schemas are the same so we can run the same queries on them
    my $uitable = $u->{'journaltype'} eq 'C' ? 'comminterests' : 'userinterests';

    foreach my $int (@$new)
    {
        $int = lc($int);       # FIXME: use utf8?
        $int =~ s/^i like //;  # *sigh*
        next unless $int;
        next if $int =~ / .+ .+ .+ /;  # prevent sentences
        next if $int =~ /[\<\>]/;
        my ($bl, $cl) = LJ::text_length($int);
        next if $bl > LJ::BMAX_INTEREST or $cl > LJ::CMAX_INTEREST;
        $int_new{$int} = 1 unless $old->{$int};
        delete $int_del{$int};
    }

    ### were interests removed?
    if (%int_del)
    {
        ## easy, we know their IDs, so delete them en masse
        my $intid_in = join(", ", values %int_del);
        $dbh->do("DELETE FROM $uitable WHERE userid=$userid AND intid IN ($intid_in)");
        $dbh->do("UPDATE interests SET intcount=intcount-1 WHERE intid IN ($intid_in)");
    }

    ### do we have new interests to add?
    if (%int_new)
    {
        ## difficult, have to find intids of interests, and create new ints for interests
        ## that nobody has ever entered before
        my $int_in = join(", ", map { $dbh->quote($_); } keys %int_new);
        my %int_exist;
        my @new_intids = ();  ## existing IDs we'll add for this user

        ## find existing IDs
        my $sth = $dbh->prepare("SELECT interest, intid FROM interests WHERE interest IN ($int_in)");
        $sth->execute;
        while (my ($intr, $intid) = $sth->fetchrow_array) {
            push @new_intids, $intid;       # - we'll add this later.
            delete $int_new{$intr};         # - so we don't have to make a new intid for
                                            #   this next pass.
        }

        if (@new_intids) {
            my $sql = "";
            foreach my $newid (@new_intids) {
                if ($sql) { $sql .= ", "; }
                else { $sql = "REPLACE INTO $uitable (userid, intid) VALUES "; }
                $sql .= "($userid, $newid)";
            }
            $dbh->do($sql);

            my $intid_in = join(", ", @new_intids);
            $dbh->do("UPDATE interests SET intcount=intcount+1 WHERE intid IN ($intid_in)");
        }
    }

    ### do we STILL have interests to add?  (must make new intids)
    if (%int_new)
    {
        foreach my $int (keys %int_new)
        {
            my $intid;
            my $qint = $dbh->quote($int);

            $dbh->do("INSERT INTO interests (intid, intcount, interest) ".
                     "VALUES (NULL, 1, $qint)");
            if ($dbh->err) {
                # somebody beat us to creating it.  find its id.
                $intid = $dbh->selectrow_array("SELECT intid FROM interests WHERE interest=$qint");
                $dbh->do("UPDATE interests SET intcount=intcount+1 WHERE intid=$intid");
            } else {
                # newly created
                $intid = $dbh->{'mysql_insertid'};
            }
            if ($intid) {
                ## now we can actually insert it into the userinterests table:
                $dbh->do("INSERT INTO $uitable (userid, intid) ".
                         "VALUES ($userid, $intid)");
            }
        }
    }

    ### if journaltype is community, clean their old userinterests from 'userinterests'
    if ($u->{'journaltype'} eq 'C') {
        $dbh->do("DELETE FROM userinterests WHERE userid=?", undef, $u->{'userid'});
    }

    return 1;
}

# returns 1 if action is permitted.  0 if above rate or fail.
# action isn't logged on fail.
#
# opts keys:
#   -- "limit_by_ip" => "1.2.3.4"  (when used for checking rate)
#   -- 
sub rate_log
{
    my ($u, $ratename, $count, $opts) = @_;
    my $rateperiod = LJ::get_cap($u, "rateperiod-$ratename");
    return 1 unless $rateperiod;

    my $dbu = LJ::get_cluster_master($u);
    return 0 unless $dbu;
    
    my $rp = LJ::get_prop("rate", $ratename);
    return 0 unless $rp;
    
    my $now = time();
    my $beforeperiod = $now - $rateperiod;
    
    # delete inapplicable stuff (or some of it)
    $dbu->do("DELETE FROM ratelog WHERE userid=$u->{'userid'} AND rlid=$rp->{'id'} ".
             "AND evttime < $beforeperiod LIMIT 1000");
    
    # check rate.  (okay per period)
    my $opp = LJ::get_cap($u, "rateallowed-$ratename");
    return 1 unless $opp;
    my $udbr = LJ::get_cluster_reader($u);
    my $ip = $udbr->quote($opts->{'limit_by_ip'} || "0.0.0.0");
    my $sum = $udbr->selectrow_array("SELECT COUNT(quantity) FROM ratelog WHERE ".
                                     "userid=$u->{'userid'} AND rlid=$rp->{'id'} ".
                                     "AND ip=INET_ATON($ip) ".
                                     "AND evttime > $beforeperiod");

    # would this transaction go over the limit?
    if ($sum + $count > $opp) {
        # TODO: optionally log to rateabuse, unless caller is doing it themselves
        # somehow, like with the "loginstall" table.
        return 0;
    }

    # log current
    $count = $count + 0;
    $dbu->do("INSERT INTO ratelog (userid, rlid, evttime, ip, quantity) VALUES ".
             "($u->{'userid'}, $rp->{'id'}, $now, INET_ATON($ip), $count)");
    return 1;
}

# We're not always running under mod_perl... sometimes scripts (syndication sucker)
# call paths which end up thinking they need the remote IP, but don't.
sub get_remote_ip
{
    my $ip;
    eval {
        $ip = Apache->request->connection->remote_ip;
    };
    return $ip || $ENV{'FAKE_IP'} || $ENV{'REMOTE_ADDR'};
}

sub login_ip_banned
{
    my $u = shift;
    return 0 unless $u;

    my $ip;
    return 0 unless ($ip = LJ::get_remote_ip());

    my $udbr;
    my $rateperiod = LJ::get_cap($u, "rateperiod-failed_login");
    if ($rateperiod && ($udbr = LJ::get_cluster_reader($u))) {
        my $bantime = $udbr->selectrow_array("SELECT time FROM loginstall WHERE ".
                                             "userid=$u->{'userid'} AND ip=INET_ATON(?)",
                                             undef, $ip);
        if ($bantime && $bantime > time() - $rateperiod) {
            return 1;
        }
    }
    return 0;
}

sub handle_bad_login
{
    my $u = shift;
    return 1 unless $u;

    my $ip;
    return 1 unless ($ip = LJ::get_remote_ip());
    # an IP address is permitted such a rate of failures
    # until it's banned for a period of time.
    my $udbh;
    if (! LJ::rate_log($u, "failed_login", 1, { 'limit_by_ip' => $ip }) &&
        ($udbh = LJ::get_cluster_master($u)))
    {
        $udbh->do("REPLACE INTO loginstall (userid, ip, time) VALUES ".
                  "(?,INET_ATON(?),UNIX_TIMESTAMP())", undef, $u->{'userid'}, $ip);
    }
    return 1;
}

sub md5_struct
{
    my ($st, $md5) = @_;
    $md5 ||= Digest::MD5->new;
    unless (ref $st) {
        # later Digest::MD5s die while trying to 
        # get at the bytes of an invalid utf-8 string.
        # this really shouldn't come up, but when it
        # does, we clear the utf8 flag on the string and retry.
        # see http://zilla.livejournal.org/show_bug.cgi?id=851
        eval { $md5->add($st); };
        if ($@) {
            $st = pack('C*', unpack('C*', $st));
            $md5->add($st);
        }
        return $md5;
    }
    if (ref $st eq "HASH") {
        foreach (sort keys %$st) {
            md5_struct($_, $md5);
            md5_struct($st->{$_}, $md5);           
        }
        return $md5;
    }
    if (ref $st eq "ARRAY") {
        foreach (@$st) {
            md5_struct($_, $md5);
        }
        return $md5;
    }
}

sub rand_chars
{
    my $length = shift;
    my $chal = "";
    my $digits = "abcdefghijklmnopqrstuvwzyzABCDEFGHIJKLMNOPQRSTUVWZYZ0123456789";
    for (1..$length) {
        $chal .= substr($digits, int(rand(62)), 1);
    }
    return $chal;
}

# with no arg, returns list:  ($time, $secret).
# with arg, return secret for that $time
sub get_secret
{
    my $time = int($_[0]);
    return undef if $_[0] && ! $time;
    my $want_new = 0;

    if (! $time) {
        $want_new = 1;
        $time = time();
        $time -= $time % 3600;  # one hour granularity
    }

    my $memkey = "secret:$time";
    my $secret = LJ::MemCache::get($memkey);
    return $want_new ? ($time, $secret) : $secret if $secret;

    my $dbh = LJ::get_db_writer();
    return undef unless $dbh;
    $secret = $dbh->selectrow_array("SELECT secret FROM secrets ".
                                    "WHERE stime=?", undef, $time);
    if ($secret) {
        LJ::MemCache::set($memkey, $secret) if $secret;
        return $want_new ? ($time, $secret) : $secret;
    }
    
    # return if they specified an explicit time they wanted.
    # (calling with no args means generate a new one if secret
    # doesn't exist)
    return undef unless $want_new;

    # don't generate new times that don't fall in our granularity
    return undef if $time % 3600;
    
    $secret = LJ::rand_chars(32);
    $dbh->do("INSERT IGNORE INTO secrets SET stime=?, secret=?",
             undef, $time, $secret);
    # check for races:
    $secret = get_secret($time);
    return ($time, $secret);
}

sub generate_session
{
    my ($u, $opts) = @_;
    my $udbh = LJ::get_cluster_master($u);
    my $sess = {};
    $opts->{'exptype'} = "short" unless $opts->{'exptype'} eq "long";
    $sess->{'auth'} = LJ::rand_chars(10);
    my $expsec = $opts->{'exptype'} eq "short" ? 60*60*24 : 60*60*24*7;
    $udbh->do("INSERT INTO sessions (userid, sessid, auth, exptype, ".
              "timecreate, timeexpire, ipfixed) VALUES (?,NULL,?,?,UNIX_TIMESTAMP(),".
              "UNIX_TIMESTAMP()+$expsec,?)", undef,
              $u->{'userid'}, $sess->{'auth'}, $opts->{'exptype'}, $opts->{'ipfixed'});
    return undef if $udbh->err;
    $sess->{'sessid'} = $udbh->{'mysql_insertid'};
    $sess->{'userid'} = $u->{'userid'};
    $sess->{'ipfixed'} = $opts->{'ipfixed'};
    $sess->{'exptype'} = $opts->{'exptype'};

    # clean up old sessions
    my $old = $udbh->selectcol_arrayref("SELECT sessid FROM sessions WHERE ".
                                        "userid=$u->{'userid'} AND ".
                                        "timeexpire < UNIX_TIMESTAMP()");
    LJ::kill_sessions($udbh, $u->{'userid'}, @$old) if $old;

    # mark account as being used
    my $dbh = LJ::get_db_writer();
    $dbh->do("UPDATE userusage SET timecheck=NOW() WHERE userid=?",
             undef, $u->{'userid'});
    LJ::mark_user_active($u, 'login');

    return $sess;
}

sub kill_all_sessions
{
    my $u = shift;
    return 0 unless $u;
    my $udbh = LJ::get_cluster_master($u);
    my $sessions = $udbh->selectcol_arrayref("SELECT sessid FROM sessions WHERE ".
					     "userid=$u->{'userid'}");
    LJ::kill_sessions($udbh, $u->{'userid'}, @$sessions) if @$sessions;
}

sub kill_sessions
{
    my ($udbh, $userid, @sessids) = @_;
    my $in = join(',', map { $_+0 } @sessids);
    return 1 unless $in;
    foreach (qw(sessions sessions_data)) {
        $udbh->do("DELETE FROM $_ WHERE userid=? AND ".
                  "sessid IN ($in)", undef, $userid);
    }
    foreach my $id (@sessids) {
        $id += 0;
        my $memkey = [$userid,"sess:$userid:$id"];
        LJ::MemCache::delete($memkey);
    }
    return 1;
}

sub kill_session
{
    my $u = shift;
    return 0 unless $u;
    return 0 unless exists $u->{'_session'};
    my $udbh = LJ::get_cluster_master($u);
    LJ::kill_sessions($udbh, $u->{'userid'}, $u->{'_session'}->{'sessid'});
    delete $BML::COOKIE{'ljsession'};
    return 1;
}

# <LJFUNC>
# name: LJ::load_rel_user
# des: Load user relationship information. Loads all relationships of type 'type' in
#      which user 'userid' participates on the left side (is the source of the
#      relationship).
# args: db?, userid, type
# arg-userid: userid or a user hash to load relationship information for.
# arg-type: type of the relationship
# returns: reference to an array of userids
# </LJFUNC>
sub load_rel_user
{
    my $db = isdb($_[0]) ? shift : undef;
    my ($userid, $type) = @_;
    return undef unless $type and $userid;
    $userid = LJ::want_userid($userid);
    $db ||= LJ::get_db_reader();
    return $db->selectcol_arrayref("SELECT targetid FROM reluser WHERE userid=? AND type=?",
                                   undef, $userid, $type);
}

# <LJFUNC>
# name: LJ::load_rel_target
# des: Load user relationship information. Loads all relationships of type 'type' in
#      which user 'targetid' participates on the right side (is the target of the
#      relationship).
# args: db?, targetid, type
# arg-targetid: userid or a user hash to load relationship information for.
# arg-type: type of the relationship
# returns: reference to an array of userids
# </LJFUNC>
sub load_rel_target
{
    my $db = isdb($_[0]) ? shift : undef;
    my ($targetid, $type) = @_;
    return undef unless $type and $targetid;
    $targetid = LJ::want_userid($targetid);
    my $dbr;
    $db ||= LJ::get_db_reader();
    return $db->selectcol_arrayref("SELECT userid FROM reluser WHERE targetid=? AND type=?",
                                   undef, $targetid, $type);
}

# <LJFUNC>
# name: LJ::check_rel
# des: Checks whether two users are in a specified relationship to each other.
# args: db?, userid, targetid, type
# arg-userid: source userid, nonzero; may also be a user hash.
# arg-targetid: target userid, nonzero; may also be a user hash.
# arg-type: type of the relationship
# returns: 1 if the relationship exists, 0 otherwise
# </LJFUNC>
sub check_rel
{
    my $db = isdb($_[0]) ? shift : undef;
    my ($userid, $targetid, $type) = @_;
    return undef unless $type and $userid and $targetid;
    $userid = LJ::want_userid($userid); 
    $targetid = LJ::want_userid($targetid);

    my $key = "$userid-$targetid-$type";
    return $LJ::REQ_CACHE_REL{$key} if defined $LJ::REQ_CACHE_REL{$key};

    $db ||= LJ::get_db_reader();
    my $res = $db->selectrow_array("SELECT COUNT(*) FROM reluser ".
                                   "WHERE userid=$userid AND type=? ".
                                   "AND targetid=$targetid", undef, $type);
    return $LJ::REQ_CACHE_REL{$key} = ($res ? 1 : 0);
}

# <LJFUNC>
# name: LJ::set_rel
# des: Sets relationship information for two users.
# args: dbs?, userid, targetid, type
# arg-userid: source userid, or a user hash
# arg-targetid: target userid, or a user hash
# arg-type: type of the relationship
# </LJFUNC>
sub set_rel 
{
    &nodb;
    my ($userid, $targetid, $type) = @_;
    return undef unless $type and $userid and $targetid;
    $userid = LJ::want_userid($userid);
    $targetid = LJ::want_userid($targetid);

    my $dbh = LJ::get_db_writer();
    $dbh->do("REPLACE INTO reluser (userid,targetid,type) ".
             "VALUES ($userid,$targetid,?)", undef, $type);
    return;
}

# <LJFUNC>
# name: LJ::clear_rel
# des: Deletes a relationship between two users or all relationships of a particular type
#      for one user, on either side of the relationship. One of userid,targetid -- bit not
#      both -- may be '*'. In that case, if, say, userid is '*', then all relationship 
#      edges with target equal to targetid and of the specified type are deleted. 
#      If both userid and targetid are numbers, just one edge is deleted.
# args: dbs?, userid, targetid, type
# arg-userid: source userid, or a user hash, or '*'
# arg-targetid: target userid, or a user hash, or '*'
# arg-type: type of the relationship
# </LJFUNC>
sub clear_rel 
{
    &nodb;
    my ($userid, $targetid, $type) = @_;
    return undef unless $type and $userid or $targetid;
    return undef if $userid eq '*' and $targetid eq '*';

    $userid = LJ::want_userid($userid) unless $userid eq '*';
    $targetid = LJ::want_userid($targetid) unless $targetid eq '*';

    my $dbh = LJ::get_db_writer();
    my $qtype = $dbh->quote($type);
    my $sql = "DELETE FROM reluser WHERE " . ($userid ne '*' ? "userid=$userid AND " : "") .
              ($targetid ne '*' ? "targetid=$targetid AND " : "") . "type=$qtype";
    $dbh->do($sql);
    return;
}

# $dom: 'L' == log, 'T' == talk, 'M' == modlog, 'B' == blob (userpic, etc)
sub alloc_user_counter
{
    my ($u, $dom, $recurse) = @_;
    return undef unless $dom =~ /^[LTMB]$/;
    my $dbcm = LJ::get_cluster_master($u);
    return undef unless $dbcm;

    my $newmax;
    my $uid = $u->{'userid'}+0;
    my $memkey = [$uid, "auc:$uid:$dom"];

    # in a master-master DB cluster we need to be careful that in
    # an automatic failover case where one cluster is slightly behind
    # that the same counter ID isn't handed out twice.  use memcache
    # as a sanity check to record/check latest number handed out.
    my $memmax = int(LJ::MemCache::get($memkey) || 0);

    my $rs = $dbcm->do("UPDATE counter SET max=LAST_INSERT_ID(GREATEST(max,$memmax)+1) ".
                       "WHERE journalid=? AND area=?", undef, $uid, $dom);
    if ($rs > 0) {
        $newmax = $dbcm->selectrow_array("SELECT LAST_INSERT_ID()");
        LJ::MemCache::set($memkey, $newmax);
        return $newmax;
    }

    if ($recurse) {
        # We shouldn't ever get here if all is right with the world.
        return undef;
    }

    # Make sure the counter table is populated for this uid/dom.
    if ($dom eq "L") {
        $newmax = $dbcm->selectrow_array("SELECT MAX(jitemid) FROM log2 WHERE journalid=?",
                    undef, $uid);
    } elsif ($dom eq "T") {
        $newmax = $dbcm->selectrow_array("SELECT MAX(jtalkid) FROM talk2 WHERE journalid=?",
                undef, $uid);
    } elsif ($dom eq "M") {
        $newmax = $dbcm->selectrow_array("SELECT MAX(modid) FROM modlog WHERE journalid=?",
                undef, $uid);
    }
    $newmax += 0;
    $dbcm->do("INSERT IGNORE INTO counter (journalid, area, max) VALUES (?,?,?)",
                undef, $uid, $dom, $newmax) or return undef;

    # The 2nd invocation of the alloc_user_counter sub should do the
    # intended incrementing.
    return LJ::alloc_user_counter($u, $dom, 1);
}

# $dom: 'S' == style
sub alloc_global_counter
{
    my ($dom, $recurse) = @_;
    return undef unless $dom =~ /^[S]$/;
    my $dbh = LJ::get_db_writer();
    return undef unless $dbh;

    my $newmax;
    my $uid = 0; # userid is not needed, we just use '0'

    my $rs = $dbh->do("UPDATE counter SET max=LAST_INSERT_ID(max+1) WHERE journalid=? AND area=?",
                      undef, $uid, $dom);
    if ($rs > 0) {
        $newmax = $dbh->selectrow_array("SELECT LAST_INSERT_ID()");
        return $newmax;
    }

    return undef if $recurse;

    if ($dom eq "S") {
        $newmax = $dbh->selectrow_array("SELECT MAX(styleid) FROM style");
    }
    $newmax += 0;
    $dbh->do("INSERT IGNORE INTO counter (journalid, area, max) VALUES (?,?,?)",
            undef, $uid, $dom, $newmax) or return undef;
    return LJ::alloc_global_counter($dom, 1);
}


# <LJFUNC>
# name: LJ::make_user_active
# des:  Record user activity per cluster to
#       make per-activity cluster stats easier.
# args: userobj, type
# arg-userid: source userobj ref
# arg-type: currently unused
# </LJFUNC>
sub mark_user_active {
    my ($u, $type) = @_;  # not currently using type
    my $uid = $u->{userid};
    return 0 unless $uid && $u->{clusterid};

    # Update the clustertrack table, but not if we've done it for this
    # user in the last hour
    if (LJ::MemCache::add("rate:tracked:$uid", 1, 3600)) {
        my $dbcm = LJ::get_cluster_master($u);
        return 0 unless $dbcm;
        $dbcm->do("REPLACE INTO clustertrack2 SET ".
                 "userid=?, timeactive=?, clusterid=?", undef,
                 $uid, time(), $u->{clusterid}) or return 0;
    }
    return 1;
}

# given a unix time, returns;
#   ($week, $ubefore)
# week: week number (week 0 is first 3 days of unix time)
# ubefore:  seconds before the next sunday, divided by 10
sub weekuu_parts {
    my $time = shift;
    $time -= 86400*3;  # time from the sunday after unixtime 0
    my $WEEKSEC = 86400*7;
    my $week = int(($time+$WEEKSEC) / $WEEKSEC);
    my $uafter = int(($time % $WEEKSEC) / 10);
    my $ubefore = int(60480 - ($time % $WEEKSEC) / 10);
    return ($week, $uafter, $ubefore);
}

sub weekuu_before_to_time
{
    my ($week, $ubefore) = @_;
    my $WEEKSEC = 86400*7;
    my $time = $week * $WEEKSEC + 86400*3;
    $time -= 10 * $ubefore;
    return $time;
}

sub weekuu_after_to_time
{
    my ($week, $uafter) = @_;
    my $WEEKSEC = 86400*7;
    my $time = ($week-1) * $WEEKSEC + 86400*3;
    $time += 10 * $uafter;
    return $time;
}

sub make_login_session
{
    my ($u, $exptype, $ipfixed) = @_;
    $exptype ||= 'short';
    return 0 unless $u;

    my $etime = 0;
    eval { Apache->request->notes('ljuser' => $u->{'user'}); };

    my $sess_opts = {
        'exptype' => $exptype,
        'ipfixed' => $ipfixed,
    };
    my $sess = LJ::generate_session($u, $sess_opts);
    $BML::COOKIE{'ljsession'} = [  "ws:$u->{'user'}:$sess->{'sessid'}:$sess->{'auth'}", $etime, 1 ];
    LJ::set_remote($u);

    LJ::load_user_props($u, "browselang", "schemepref" );
    my $bl = LJ::Lang::get_lang($u->{'browselang'});
    if ($bl) {
        BML::set_cookie("langpref", $bl->{'lncode'} . "/" . time(), 0, $LJ::COOKIE_PATH, $LJ::COOKIE_DOMAIN);
        BML::set_language($bl->{'lncode'});
    }
    
    # restore default scheme
    if ($u->{'schemepref'} ne "") {
      BML::set_cookie("BMLschemepref", $u->{'schemepref'}, 0, $LJ::COOKIE_PATH, $LJ::COOKIE_DOMAIN);
      BML::set_scheme($u->{'schemepref'});
    }
    
    LJ::run_hooks("post_login", {
        "u" => $u,
        "form" => {},
        "expiretime" => $etime,
    });

    LJ::mark_user_active($u, 'login');

    return 1;
}

sub last_error_code
{
    return $LJ::last_error;
}

sub last_error
{
    my $err = {
        'utf8' => "Encoding isn't valid UTF-8",
        'db' => "Database error",
    };
    my $des = $err->{$LJ::last_error};
    if ($LJ::last_error eq "db" && $LJ::db_error) {
        $des .= ": $LJ::db_error";
    }
    return $des || $LJ::last_error;
}

sub error
{
    my $err = shift;
    if (isdb($err)) {
        $LJ::db_error = $err->errstr;
        $err = "db";
    } elsif ($err eq "db") {
        $LJ::db_error = "";
    }
    $LJ::last_error = $err;
    return undef;
}

# to be called as &nodb; (so this function sees caller's @_)
sub nodb { 
    shift @_ if 
        ref $_[0] eq "LJ::DBSet" || ref $_[0] eq "DBI::db" ||
        ref $_[0] eq "DBIx::StateKeeper" || ref $_[0] eq "Apache::DBI::db";
}

sub isdb { return ref $_[0] && (ref $_[0] eq "DBI::db" || 
                                ref $_[0] eq "DBIx::StateKeeper" ||
                                ref $_[0] eq "Apache::DBI::db"); }


use vars qw($AUTOLOAD);
sub AUTOLOAD {
    if ($AUTOLOAD eq "LJ::send_mail") {
        require "$ENV{'LJHOME'}/cgi-bin/ljmail.pl";
        goto &$AUTOLOAD;
    }
    croak "Undefined subroutine: $AUTOLOAD";
}

# LJ::S1::get_public_styles lives here in ljlib.pl so that 
# cron jobs can call LJ::load_user_props without including
# ljviews.pl

package LJ::S1;

sub get_public_styles {

    # now try memcache
    my $memkey = "s1pubstyc";
    my $pubstyc = LJ::MemCache::get($memkey);
    return $pubstyc if $pubstyc;

    $pubstyc = {};

    # not cached, build from db
    my $sysid = LJ::get_userid("system");

    # first try new table
    my $dbh = LJ::get_db_writer();
    my $sth = $dbh->prepare("SELECT * FROM s1style WHERE userid=?");
    $sth->execute($sysid);
    $pubstyc->{$_->{'styleid'}} = $_ while $_ = $sth->fetchrow_hashref;

    # fall back to old table
    unless (%$pubstyc) {
        $sth = $dbh->prepare("SELECT * FROM style WHERE user='system' AND is_public='Y'");
        $sth->execute();
        $pubstyc->{$_->{'styleid'}} = $_ while $_ = $sth->fetchrow_hashref;
    }
    return undef unless %$pubstyc;

    # set in memcache
    my $expire = time() + 60*30; # 30 minutes
    LJ::MemCache::set($memkey, $pubstyc, $expire);

    return $pubstyc;
}

1;
