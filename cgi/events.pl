#!/usr/bin/perl
#
# Hatchet event viewer cgi
# v 0.9.2
# Jason Dixon <jason@dixongroup.net>
# http://www.dixongroup.net/hatchet/
#

use strict;
use Time::Local qw( timelocal );

our ($chroot_db_file, $mem_tables, $ipv6, $url_service, $url_address, $css_file);
require "../conf/hatchet.conf";


my $dbh = DBI->connect("DBI:SQLite:dbname=$chroot_db_file", "", "") || die $DBI::errstr;
my $cgi = CGI->new;

my $select_query = "select * from logs where date >= ? and date <= ?";
my $sort_field = "";

if ($cgi->param('sort')) {

	SWITCH: {

		# string sorts, perform in database
		if ($cgi->param('sort') eq 'action') { $select_query .= " order by action"; last SWITCH; }
		if ($cgi->param('sort') eq 'intf') { $select_query .= " order by interface"; last SWITCH; }
		if ($cgi->param('sort') eq 'src') { $select_query .= " order by src_host"; last SWITCH; }
		if ($cgi->param('sort') eq 'dst') { $select_query .= " order by dst_host"; last SWITCH; }

		# numeric sorts, do later
		if ($cgi->param('sort') eq 'svc') { $sort_field = "dst_port"; last SWITCH; }
		if ($cgi->param('sort') eq 'rule') { $sort_field = "rulenum"; last SWITCH; }

		$select_query .= " order by date";
	}

	if ($cgi->param('d')) {

		# string sorts, perform in database
		unless ($sort_field =~ /^\w+$/) {
			$select_query .= " desc" if ($cgi->param('d') eq 'desc');
		}
	}
}

# Set our tmp directory for temp SQLite tables
$dbh->do("PRAGMA temp_store=1");
$dbh->do("PRAGMA temp_store_directory='../tmp'");

my $sth = $dbh->prepare($select_query);
my ($date, $month, $day, $month_num);
my @timestamp = localtime(time);

# From input field
if ($cgi->param('month')) {
	$month = $cgi->param('month');
	$day = sprintf("%02d", $cgi->param('day'));

# From column links
} elsif ($cgi->param('date')) {
	$date = $cgi->param('date');
	($month, $day) = split(/ /, $date);
	$day = sprintf("%02d", $day);

# Everywhere else
} else {
	$month = $timestamp[4];
	$day = sprintf("%02d", $timestamp[3]);
}

$date = "$month $day";
my $date_param = '&date=' . $date;
my $year = $timestamp[5];
my $epoch_start_of_day = timelocal(0, 0, 0, $day, $month, $year);
my $epoch_end_of_day = timelocal(59, 59, 23, $day, $month, $year);
$sth->execute($epoch_start_of_day, $epoch_end_of_day);
my @log_loop;

while (my $result = $sth->fetchrow_hashref) {
	next if ((($result->{'src_host'} =~ /\:/) || ($result->{'dst_host'} =~ /\:/)) && ($ipv6 == 0));
	my $epoch = $result->{'date'};
	my ($sec, $min, $hour, $mday, $month) = (localtime($epoch))[0..4];
	my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	$month = $months[$month];
	$hour = sprintf("%02d", $hour);
	$min = sprintf("%02d", $min);
	$sec = sprintf("%02d", $sec);
	$result->{'date'} = "$month $mday $hour:$min:$sec";
	unless ($result->{'src_host'} eq 'encrypted') {
		$result->{'src_host'} = '<a href="' . $url_address . $result->{'src_host'} . '" target="new">' . $result->{'src_host'} . '</a>';
	}
	unless ($result->{'dst_host'} eq 'encrypted') {
		$result->{'dst_host'} = '<a href="' . $url_address . $result->{'dst_host'} . '" target="new">' . $result->{'dst_host'} . '</a>';
	}
	if ($result->{'dst_port'} =~ /^\d+$/) {
		$result->{'dst_port_href'} = '<a href="' . $url_service . $result->{'dst_port'} . '" target="new">' . $result->{'dst_port'} . '</a>';
	} else {
		$result->{'dst_port_href'} = $result->{'dst_port'};
	}
	push(@log_loop, $result);
}

# numeric sorting
if ($sort_field =~ /^\w+$/) {
	my @sorted_log_loop;
	my @rows_numeric;
	my @rows_alpha;

	while (my $result = shift @log_loop) {

		if ($result->{$sort_field} =~ /^\d+$/) {
			push(@rows_numeric, $result);
		} else {
			push(@rows_alpha, $result);
		}
	}

	if ($cgi->param('d')) {

		# descending sort
		if ($cgi->param('d') eq 'desc') {
			push(@sorted_log_loop, sort { $b->{$sort_field} cmp $a->{$sort_field} } @rows_alpha);
			push(@sorted_log_loop, sort { $b->{$sort_field} <=> $a->{$sort_field} } @rows_numeric);
		# ascending sort
		} else {
			push(@sorted_log_loop, sort { $a->{$sort_field} <=> $b->{$sort_field} } @rows_numeric);
			push(@sorted_log_loop, sort { $a->{$sort_field} cmp $b->{$sort_field} } @rows_alpha);
		}
	} else {
		# ascending sort
		push(@sorted_log_loop, sort { $a->{$sort_field} <=> $b->{$sort_field} } @rows_numeric);
		push(@sorted_log_loop, sort { $a->{$sort_field} cmp $b->{$sort_field} } @rows_alpha);
	}

	@log_loop = @sorted_log_loop;
}

my @data;
for (my $alt = 0; my $result = shift @log_loop; $alt++) {
	$result->{'alt'} = ' class="alt"' if ($alt % 2 == 0);
	push(@data, $result);
}

my $template = HTML::Template->new(filename => 'templates/output.tmpl', die_on_bad_params => 0);
my $time = localtime;
$template->param("month${timestamp[4]}" => ' selected="selected"');
$template->param(time => $time, date => $date_param, data => \@data);
$template->param(opts => '&d=desc') unless ($cgi->param('d') eq 'desc');
$template->param(css_file => $css_file);
print "Content-Type: text/html\n\n", $template->output;


