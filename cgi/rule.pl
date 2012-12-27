#!/usr/bin/perl
#
# Hatchet rule viewer cgi
# v 0.9.2
# Jason Dixon <jason@dixongroup.net>
# http://www.dixongroup.net/hatchet/
#

use strict;

our $chroot_db_file;
require "../conf/hatchet.conf";

my $dbh = DBI->connect("DBI:SQLite:dbname=$chroot_db_file", "", "") || die $DBI::errstr;
my $cgi = CGI->new;

if ($cgi->param('rule')) {

	my $select_query = "select rulenum, comment from logs where id=?";
	my $sth = $dbh->prepare($select_query);
	$sth->execute($cgi->param('rule'));
	my $result= $sth->fetchrow_hashref;
	my $rulenum = $result->{'rulenum'};
	my $description = $result->{'comment'};
	my $template = HTML::Template->new(filename => 'templates/rule.tmpl', die_on_bad_params => 0);
	$template->param(rulenum => $rulenum, description => $description);
	print "Content-Type: text/html\n\n", $template->output;

}
