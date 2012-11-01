#!/usr/bin/perl -w

# Copyright (C) 2010 Phillip Smith
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 
use strict;
use warnings;
use Config::General;
use Switch;

# Configuration
my $conf_file;
# TODO: Actually use this variable :P
my $verbose;
my $PRINT_ONLY;
# Get command line args, if any
if (@ARGV > 0) {
	GetOptions (
		'config=s'	=> \$conf_file,
		'print-only'	=> \$PRINT_ONLY,
		'verbose'	=> \$verbose
	)
}
$conf_file	= './pb-route.conf'	unless defined($conf_file);
$PRINT_ONLY	= 1			unless defined($PRINT_ONLY);
$verbose	= 1			unless defined($verbose);

# Runtime variables
my $IPT;	# Path to 'iptables' binary
my $IP2;	# Path to iproute2 'ip' binary
my $TC;		# Path to 'tc' binary

# Read the config file (or die)
my %config; # The hash where the config will be stored once read
{
	my $conf;				# The conf object to read config files
	my %confHash;				# Hash storing details of the config to read
	unless ( -e $conf_file ) {
		&bomb(sprintf('Config file "%s" not found!', $conf_file));
	}

	$confHash{-ConfigFile} = $conf_file;	# Path to the conf file
	$confHash{-LowerCaseNames} = 1;		# Fold keys lowercase
	$conf = new Config::General(%confHash);	# Create the config reading object
	%config = $conf->getall;		# Read the config into the hash

	$IPT = defined($config{iptables}) ? $config{iptables} : '/sbin/iptables';
	$IP2 = defined($config{ip}) ? $config{ip} : '/sbin/ip';
	$TC  = defined($config{tc}) ? $config{tc} : '/sbin/tc';
	$PRINT_ONLY = defined($config{print_only}) ? $config{print_only} : 1;
}

###############################################################################
### Initialize and Setup Standard Configuration
###############################################################################
&comment('');
&comment('pb-route, Copyright (C) 2010 Phillip Smith');
&comment('This program comes with ABSOLUTELY NO WARRANTY; This is free software, and you are');
&comment('welcome to use and redistribute it under the conditions of the GPL license version 2');
&comment('See the "COPYING" file for further details.');
&comment('');
&setup_route_tables;
&ipt_flush;
&setup_mark_chains;	# sets up MARK-gw1 and MARK-gw2 chains
&initialize_mangle;

###############################################################################
### Setup Policies
###############################################################################
my $cnt; # Count number of policies for feedback

my @dests;
@dests = ref($config{destination}) eq 'ARRAY' ? @{$config{destination}} : ($config{destination});
$cnt = @dests;
&comment("Setting up DESTINATION based routing policies ($cnt policies)");
foreach (@dests) {
	next unless (defined($_));	# In case the conf doesn't have any of these
	my($dest_address, $gw) = split(' ', $_);
	next unless ($dest_address =~ /^((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/[0-9]{1,2})$/);
	$dest_address = $1;
	&ipt("-t mangle -A PREROUTING -m comment --comment '$dest_address via $gw' -m state --state NEW -d $dest_address -j MARK-$gw");
	&ipt("-t mangle -A PREROUTING -m comment --comment '$dest_address via $gw' -m state --state NEW -d $dest_address -j ACCEPT");
	&ipt("-t mangle -A OUTPUT -m comment --comment '$dest_address via $gw' -m state --state NEW -d $dest_address -j MARK-$gw");
	&ipt("-t mangle -A OUTPUT -m comment --comment '$dest_address via $gw' -m state --state NEW -d $dest_address -j ACCEPT");
}
my @ports;
@ports = ref($config{port}) eq 'ARRAY' ? @{$config{port}} : ($config{port});
$cnt = @ports;
&comment("Setting up PORT based routing policies ($cnt policies)");
foreach (@ports) {
	next unless (defined($_));	# In case the conf doesn't have any of these
	my($dest_port, $gw) = split(' ', $_);
	next unless ($dest_port =~ /^([0-9]+)$/);
	$dest_port = $1;
	my $CHAIN=sprintf("PORT_%s_%s", $dest_port, $gw);
	&ipt("-t mangle -N $CHAIN");
	&ipt("-t mangle -A $CHAIN -m comment --comment 'tcp $dest_port via $gw' -p tcp --dport $dest_port -j MARK-$gw");
	&ipt("-t mangle -A $CHAIN -m comment --comment 'tcp $dest_port via $gw' -p tcp --dport $dest_port -j ACCEPT");
	&ipt("-t mangle -A $CHAIN -m comment --comment 'udp $dest_port via $gw' -p udp --dport $dest_port -j MARK-$gw");
	&ipt("-t mangle -A $CHAIN -m comment --comment 'udp $dest_port via $gw' -p udp --dport $dest_port -j ACCEPT");
	&ipt("-t mangle -A $CHAIN -j RETURN");
	&ipt("-t mangle -A PREROUTING -m comment --comment 'tcp $dest_port via $gw' -m state --state NEW  -j $CHAIN");
	&ipt("-t mangle -A OUTPUT -m comment --comment 'tcp $dest_port via $gw' -m state --state NEW -j $CHAIN");
}
my @protos;
@protos = ref($config{proto}) eq 'ARRAY' ? @{$config{proto}} : ($config{proto});
$cnt = @protos;
&comment("Setting up PROTOCOL based routing policies ($cnt policies)");
foreach (@protos) {
	next unless (defined($_));	# In case the conf doesn't have any of these
	my($protocol, $gw) = split(' ', $_);
	next unless ($protocol =~ /^(tcp|udp|icmp|gre)$/);
	$protocol = $1;
	&ipt("-t mangle -A PREROUTING -m comment --comment '$protocol via $gw' -m state --state NEW -p $protocol -j MARK-$gw");
	&ipt("-t mangle -A PREROUTING -m comment --comment '$protocol via $gw' -m state --state NEW -p $protocol -j ACCEPT");
	&ipt("-t mangle -A OUTPUT -m comment --comment '$protocol via $gw' -m state --state NEW -p $protocol -j MARK-$gw");
	&ipt("-t mangle -A OUTPUT -m comment --comment '$protocol via $gw' -m state --state NEW -p $protocol -j ACCEPT");
}

&comment("Setting up DEFAULT routing policy");
switch ($config{default}) {
	&ipt("-t mangle -N DEF_POL");
	case "balanced" {
		# Default balance between connections
		&ipt("-t mangle -A DEF_POL -m comment --comment 'default balancing' -p tcp -m state --state ESTABLISHED,RELATED -j CONNMARK --restore-mark");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'default balancing' -p udp -m state --state ESTABLISHED,RELATED -j CONNMARK --restore-mark");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'balance gw1 tcp' -m mark --mark 0 -p tcp -m state --state NEW -m statistic --mode nth --every 2 --packet 0 -j MARK-gw1");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'balance gw1 tcp' -m mark --mark 0 -p tcp -m state --state NEW -m statistic --mode nth --every 2 --packet 0 -j ACCEPT");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'balance gw2 tcp' -m mark --mark 0 -p tcp -m state --state NEW -m statistic --mode nth --every 2 --packet 1 -j MARK-gw2");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'balance gw2 tcp' -m mark --mark 0 -p tcp -m state --state NEW -m statistic --mode nth --every 2 --packet 1 -j ACCEPT");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'balance gw1 udp' -m mark --mark 0 -p udp -m state --state NEW -m statistic --mode nth --every 2 --packet 0 -j MARK-gw1");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'balance gw1 udp' -m mark --mark 0 -p udp -m state --state NEW -m statistic --mode nth --every 2 --packet 0 -j ACCEPT");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'balance gw2 udp' -m mark --mark 0 -p udp -m state --state NEW -m statistic --mode nth --every 2 --packet 1 -j MARK-gw2");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'balance gw2 udp' -m mark --mark 0 -p udp -m state --state NEW -m statistic --mode nth --every 2 --packet 1 -j ACCEPT");
	}
	case /gw[0-9]/ {
		# Default via a specific connection
		&ipt("-t mangle -A DEF_POL -m comment --comment 'default via connection $config{default}' -p tcp -m state --state ESTABLISHED,RELATED -j CONNMARK --restore-mark");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'default via connection $config{default}' -p udp -m state --state ESTABLISHED,RELATED -j CONNMARK --restore-mark");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'default via connection $config{default}' -m mark --mark 0 -p tcp -m state --state NEW -j MARK-$config{default}");
		&ipt("-t mangle -A DEF_POL -m comment --comment 'default via connection $config{default}' -m mark --mark 0 -p tcp -m state --state NEW -j ACCEPT");
	}
	&ipt("-t mangle -A PREROUTING -m comment --comment 'apply default - balanced' -j DEF_POL");
	&ipt("-t mangle -A OUTPUT -m comment --comment 'apply default - balanced' -j DEF_POL");
}

###############################################################################
### Setup Traffic Shaping
###############################################################################
if (defined($config{if1speed}) and defined($config{if2speed})) {
	my @ifaces;
	my @ifspeeds;
	@ifaces = ($config{if1}, $config{if2});
	@ifspeeds = ($config{if1speed}, $config{if2speed});
	$cnt = @ifaces;
	&comment("Setting up TRAFFIC SHAPING Policies");
	for(my $X = 0; $X < $cnt; $X++) {
		my $iface   = $ifaces[$X];
		my $ifspeed = $ifspeeds[$X];
	
		my @ipt_protos = ('tcp', 'udp');
		my @ipt_ports  = ('dports', 'sports');
	
		&comment("---> Special Policies for interface $iface");
		&ipt("-t mangle -A POSTROUTING -m comment --comment 'high priority' -o $iface -p tcp --syn -m length --length 40:68 -j CLASSIFY --set-class 1:10");
		&ipt("-t mangle -A POSTROUTING -m comment --comment 'high priority' -o $iface -p tcp --tcp-flags ALL SYN,ACK -m length --length 40:68 -j CLASSIFY --set-class 1:10");
		&ipt("-t mangle -A POSTROUTING -m comment --comment 'high priority' -o $iface -p tcp --tcp-flags ALL ACK -m length --length 40:100 -j CLASSIFY --set-class 1:10");
		&ipt("-t mangle -A POSTROUTING -m comment --comment 'high priority' -o $iface -p tcp --tcp-flags ALL RST -j CLASSIFY --set-class 1:10");
		&ipt("-t mangle -A POSTROUTING -m comment --comment 'high priority' -o $iface -p tcp --tcp-flags ALL ACK,RST -j CLASSIFY --set-class 1:10");
		&ipt("-t mangle -A POSTROUTING -m comment --comment 'high priority' -o $iface -p tcp --tcp-flags ALL ACK,FIN -j CLASSIFY --set-class 1:10");
		&ipt("-t mangle -A POSTROUTING -m comment --comment 'icmp high priority' -o $iface -p icmp -m length --length 40:256 -j CLASSIFY --set-class 1:10");
		# High Priority Ports
		&comment("---> High Priority Ports for interface $iface");
		foreach (@ipt_protos) {
			my $proto = $_;
			foreach (@ipt_ports) {
				my $port_rule = $_;
				&ipt("-t mangle -A POSTROUTING -m comment --comment 'high priority' -o $iface -p $proto -m multiport --$port_rule 22,53,80 -j CLASSIFY --set-class 1:10");
			}
		}
		# Low Priority Ports
		&comment("---> Low Priority Ports for interface $iface");
		foreach (@ipt_protos) {
			my $proto = $_;
			foreach (@ipt_ports) {
				my $port_rule = $_;
				&ipt("-t mangle -A POSTROUTING -m comment --comment 'low priority' -o $iface -p $proto -m multiport --$port_rule 873,110,20,21,143 -j CLASSIFY --set-class 1:20");
			}
		}
		# Extra Low Priority Ports
		&comment("---> Extra Low Priority Ports for interface $iface");
		foreach (@ipt_protos) {
			my $proto = $_;
			foreach (@ipt_ports) {
				my $port_rule = $_;
				&ipt("-t mangle -A POSTROUTING -m comment --comment 'extra low priority' -o $iface -p $proto -m multiport --$port_rule 25,18925,49162 -j CLASSIFY --set-class 1:30");
			}
		}
		# Install TC shaping policies
		&comment("---> tc rules for interface $iface ($ifspeed kbps)");
		&tc(sprintf("qdisc del dev %s root;", $iface));
		&tc(sprintf("qdisc add dev %s root handle 1: htb default 20;", $iface));
		&tc(sprintf("class add dev %s parent 1: classid 1:1 htb rate %skbit", $iface, $ifspeed));
		&tc(sprintf("class add dev %s parent 1:1 classid 1:10 htb rate %skbit ceil %skbit prio 0", $iface, int($ifspeed/1.3), $ifspeed+10));
		&tc(sprintf("class add dev %s parent 1:1 classid 1:20 htb rate %skbit ceil %skbit prio 1", $iface, int(($ifspeed+10)/8), $ifspeed));
		&tc(sprintf("class add dev %s parent 1:1 classid 1:30 htb rate %skbit ceil %skbit prio 2", $iface, int($ifspeed/15), int($ifspeed-($ifspeed/3))));
		&tc(sprintf("qdisc add dev %s parent 1:10 handle 10: sfq perturb 10", $iface));
		&tc(sprintf("qdisc add dev %s parent 1:20 handle 20: sfq perturb 10", $iface));
		&tc(sprintf("qdisc add dev %s parent 1:30 handle 30: sfq perturb 10", $iface));
	}
}

###############################################################################
### Cleanup
###############################################################################
&setup_snat;
# Flush the route cache to make it picks up our new routing policies
&comment('Flushing route cache so new routes take effect');
&ip2('route flush cache');

###############################################################################
### SUBROUTINES
###############################################################################

sub bomb {
	# Bomb out for some reason
	printf ("BOMBS AWAY: %s\n", @_);
	exit 1;
}

sub setup_route_tables {
	&comment('Setting up multiple routing tables');
	my @routes = map { chomp; $_ } grep { !/^default/ } `$IP2 route list table main`;

	# Routing Table for packets directed out Connection 1
	&ip2('route flush table 1 2>/dev/null');
	&ip2('rule del fwmark 101 table 1 2>/dev/null');
	foreach (@routes) {
	        &ip2('route add table 1 '.&trim($_).' 2>/dev/null');
	}
	&ip2("route add table 1 default via $config{gw1ip} dev $config{if1}");
	&ip2('rule add fwmark 101 table 1');

	# Routing Table for packets directed out Connection 2
	&ip2('route flush table 2 2>/dev/null');
	&ip2('rule del fwmark 102 table 2 2>/dev/null');
	foreach (@routes) {
	        &ip2('route add table 2 '.&trim($_).' 2>/dev/null');
	}
	&ip2("route add table 2 default via $config{gw2ip} dev $config{if2}");
	&ip2('rule add fwmark 102 table 2');
}

sub ipt_flush {
	# Flush all iptables rules
	&comment('Flushing all chains in the "mangle" table');
	&ipt('-t mangle -F');
	&ipt('-t mangle -X');
	return undef;
}

sub initialize_mangle {
	&comment('Initializing "mangle" table');
	&comment('==> Handle connection streams that have already been marked');
	&ipt('-t mangle -A PREROUTING -j CONNMARK --restore-mark');
	&ipt('-t mangle -A PREROUTING -m comment --comment "this stream is already marked; escape early" -m mark ! --mark 0 -j ACCEPT');
	# This marks any NEW incoming connections with the connection
	# they came in via so replies go back the same way.
	&comment('==> Handle incoming connection streams to route back via where they came in');
	if (defined($config{gw1mac})) {
		&ipt("-t mangle -A PREROUTING -m comment --comment 'prevent asynchronous routing' -i $config{if1} -m mac --mac-source $config{gw1mac} -m state --state NEW -j MARK-gw1");
	} else {
		# No mac in conf file; differentiate on interface only
		&ipt("-t mangle -A PREROUTING -m comment --comment 'prevent asynchronous routing' -i $config{if1} -m state --state NEW -j MARK-gw1");
	}
	if (defined($config{gw2mac})) {
		&ipt("-t mangle -A PREROUTING -m comment --comment 'prevent asynchronous routing' -i $config{if2} -m mac --mac-source $config{gw2mac} -m state --state NEW -j MARK-gw2");
	} else {
		# No mac in conf file; differentiate on interface only
		&ipt("-t mangle -A PREROUTING -m comment --comment 'prevent asynchronous routing' -i $config{if2} -m state --state NEW -j MARK-gw2");
	}
}

sub setup_mark_chains {
	&comment('Setting up marking chains');
	&ipt('-t mangle -N MARK-gw1');
	&ipt("-t mangle -A MARK-gw1 -m comment --comment 'send via $config{gw1ip}' -j MARK --set-mark 101");
	&ipt('-t mangle -A MARK-gw1 -j CONNMARK --save-mark');
	&ipt('-t mangle -A MARK-gw1 -j RETURN');
	&ipt('-t mangle -N MARK-gw2');
	&ipt("-t mangle -A MARK-gw2 -m comment --comment 'send via $config{gw2ip}' -j MARK --set-mark 102");
	&ipt('-t mangle -A MARK-gw2 -j CONNMARK --save-mark');
	&ipt('-t mangle -A MARK-gw2 -j RETURN');
}

sub setup_snat {
	&comment('Setting up Source NATs');
	foreach (split(' ', $config{snat})) {
		next unless (/^((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/[0-9]{1,2})$/);
		my $snat_source = $1;
		&comment('==> Adding SNAT for '.$snat_source);
		&ipt("-t nat -A POSTROUTING -m comment --comment 'snat outbound $config{if1}' -o $config{if1} -s $snat_source -m mark --mark 101 -j SNAT --to-source $config{ip1}");
		&ipt("-t nat -A POSTROUTING -m comment --comment 'snat outbound $config{if2}' -o $config{if2} -s $snat_source -m mark --mark 102 -j SNAT --to-source $config{ip2}");
	}
}

sub ip2 {
	# Do an iproute2 command
	$PRINT_ONLY == 1 ? printf("%s %s\n", $IP2, @_) : system(sprintf('%s %s', $IP2, @_));
}
sub ipt {
	# Do an iptables command
	$PRINT_ONLY == 1 ? printf("%s %s\n", $IPT, @_) : system(sprintf('%s %s', $IPT, @_));
}
sub tc {
	# Do a 'tc' command
	$PRINT_ONLY == 1 ? printf("%s %s\n", $TC, @_) : system(sprintf('%s %s', $TC, @_));
}
sub comment {
	# Make a comment in print mode
	printf("# %s\n", @_) if $PRINT_ONLY == 1;
}

sub trim($) {
	my $string = shift;
	$string =~ s/\s{2,}/ /;	# Multiple Spaces
	$string =~ s/^\s//;	# Leading Spaces
	$string =~ s/\s$//;	# Trailing Spaces
	return $string;
}
