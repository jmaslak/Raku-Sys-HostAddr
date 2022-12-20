use v6;

#
# Copyright © 2020-2022 Joelle Maslak
# Used Jeremy Kiester's Perl5 Sys::HostAddr as the source of inspiration.
#

unit class Sys::HostAddr:ver<0.2.0>:auth<zef:jmaslak>;

use Cro::HTTP::Client;
use Net::Netmask;
use X::Sys::HostAddr::WebServiceError;

has Int:D $.ipv               is rw where { $_ == 4|6 } = 4;
has Str:D $.path              is rw = get-default-path;
has Str:D $.ipv4-url          is rw = "https://api.ipify.org";
has Str:D $.ipv6-url          is rw = "https://api6.ipify.org";
has Str:D $.user-agent        is rw = self.get-default-user-agent;
has Bool  $.filter-localhost  is rw = True;
has Bool  $.filter-link-local is rw = True;

# Builds the path variable
sub get-default-path(-->Str:D) {
    my $UNIX-ADD = "/sbin:/usr/sbin:/etc/sbin:/usr/etc";

    return $UNIX-ADD unless %*ENV<PATH>:exists;
    return %*ENV<PATH> ~ ":" ~ $UNIX-ADD;
}

method get-default-user-agent(-->Str:D) {
    my $name = self.^name.subst("::", "-");
    return $name ~ "-" ~ self.^ver;
}

method public(-->Str:D) {
    my $url = $!ipv == 4 ?? $!ipv4-url !! $!ipv6-url;

    my $client = Cro::HTTP::Client.new(
        headers => [
            User-Agent => $!user-agent,
        ],
        body-parsers => [
            Cro::HTTP::BodyParser::TextFallback,
        ],
    );
    my $resp = await $client.get($url);
    my $text = await $resp.body;

    return $text;

    CATCH { default { die X::Sys::HostAddr::WebServiceError.new } }
}

method interfaces(-->Seq) {
    return self.get-addresses-using-ip.keys.sort;
}

method addresses(-->Seq) {
    return sort unique gather {
        for self.get-addresses-using-ip.values -> $v { 
            for $v<> -> $addr { take $addr }
        }
    }
}

method addresses-on-interface(Str:D $interface, -->Seq) {
    return sort unique gather {
        for self.get-addresses-using-ip{$interface}<> -> $addr { take $addr }
    }
}

method get-addresses-using-ip(-->Hash) {
    my $old-path = %*ENV<PATH>;
    %*ENV<PATH> = $!path;
    LEAVE { %*ENV<PATH> = $old-path };

    grammar IPAddrOutput {
        token TOP { <line>* }

        # We have to strip @... off of interfaces because ip addr shows
        # them in a docker container - example:
        #   root@635ee3145917:/Raku-Sys-HostAddr# ip -4 -br addr list
        #   lo               UNKNOWN        127.0.0.1/8
        #   eth0@if7         UP             172.17.0.2/16
        #
        # But ip route doesn't:
        #   default via 172.17.0.1 dev eth0
        #   172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2
        #
        # So...we strip off the @if7 part:
        token line { ^^ <interface> [ \@ \S+ ]? <.ws> [ <status> <.ws> ]? [ <address> '/' \d+ <.ws> | <address> '/' \d+ ]* \n }

        token interface { <-[\s \@]>+ }
        token status    { <-[ 0..9 a..f ]> \S* }
        token address   { <[ \. : 0..9 a..f ]>+ }
        token ws        { " "+ }
    }

    my $output = qqx{ip -br addr show 2>/dev/null};
    my $parsed = IPAddrOutput.parse($output);

    my %ret;
    if $parsed<line>:exists {
        for $parsed<line><> -> $line {
            %ret{$line<interface>} =
                self.filter-addresses($line<address>.map( { $_.Str } ));
        }
    }

    return %ret;
}

method get-routes(-->Hash) {
    my $old-path = %*ENV<PATH>;
    %*ENV<PATH> = $!path;
    LEAVE { %*ENV<PATH> = $old-path };

    my $output = qqx{ip -$!ipv route list 2>/dev/null};

    my %ret;
    for $output.lines -> $line {
        $line ~~ m/^ [ <-[ 0..9 a..f ]> \S* \s ]? ( \S+ ) .* \s dev \s ( \S+ )/;
        my $ip = ~$0;
        my $dev = ~$1;

        next unless $dev.defined;

        if $ip eq 'default' {
            $ip = ($!ipv == 4) ?? '0.0.0.0/0' !! '::/0';
        }

        %ret{$ip} = $dev;
    }

    return %ret;
}

method guess-ip-for-host(Str:D $dst -->Str) {
    CATCH { default { return Str } };

    my $interface = self.get-route($dst);
    return Str unless $interface.defined;

    # For now we just get the first one.
    my (@addr) = self.addresses-on-interface($interface).list;

    if @addr.elems {
        return @addr[0];
    } else {
        return Str;
    }
}

method guess-main(-->Str) {
    my $ip = ($!ipv == 4) ?? '0.0.0.0' !! '2000::';
    return self.guess-ip-for-host($ip);
}

method get-route(Str:D $dst -->Str) {
    my %routes = self.get-routes;
    for %routes.kv -> $k, $v {
        my $net = Net::Netmask.new($k);
        if $net.match($dst) {
            return $v;
        }
    }

    return Str;
}

method filter-addresses(Seq $addresses --> Seq) {
    return $addresses.grep: { self.is-address-family($^a) && self.is-right-type($^a) }
}

method is-address-family(Str:D $addr -->Bool) {
    if $addr ~~ m/\:/ {
        return ($!ipv == 6);
    } else {
        return ($!ipv == 4);
    }
}

method is-right-type(Str:D $addr -->Bool) {
    if $!filter-localhost {
        return False if $addr ~~ m/^127\./;
        return False if $addr eq '::1';
    }
    if $!filter-link-local {
        return False if $addr ~~ m:i/^fe <[8 9 a b c d e f]>/;
    }
    return True;
}

=begin pod

=head1 NAME

Sys::Domainname - Get IP address information about this host

=head1 SYNOPSIS

  use Sys::Domainname;

  my $sysaddr = Sys::HostAddr.new;
  my $string = $sysaddr->public;

  my @addresses = $sysaddr->addresses;
  my @interfaces = $sysaddr->interfaces;
  my @on-int-addresses = $sysaddr->addresses-on-interface('eth0');

=head1 DESCRIPTION

This module provides methods for determining IP address information about
a local host.

=head1 WARNING

This module only functions on relatively recent Linux.

=head1 ATTRIBUTES

=head2 ipv

This attribute refers to the IP Version the class operates against.  It must
be set to either C<4> or C<6>.  This defaults to C<4>.

=head2 ipv4-url

This is the API URL used to obtain the host's public IPv4 address.  It defaults
to using C<https://api.ipify.org>.  The URL must return the address as a
plain text response.

=head2 ipv6-url

This is the API URL used to obtain the host's public IPv4 address.  It defaults
to using C<https://api6.ipify.org>.  The URL must return the address as a
plain text response.

=head2 user-agent

This is the user agent string used to idenfiy this module when making web
calls.  It defaults to this module's name and version.

=head2 filter-localhost

If C<filter-localhost> is true, only non-localhost addresses will be returned
by this class's methods.  This defaults to true.

Localhost is defined as any IPv4 address that begins with C<127.> or the
IPv6 address C<::1>.

=head2 filter-link-local

If C<filter-link-local> is true, only non-link-local addresses will be returned
by this class's methods.  This defaults to true and has no impact when C<ipv>
is set to C<4>.

Link local is defined as any IPv4 address that belong to C<fe80::/10>.

=head1 METHODS

=head2 public(-->Str:D)

  my $ha = Sys::HostAddr.new;
  say "My public IP: { $ha.public }";

Returns the public IP address used by this host, as determined by contacting
an external web service.  When the C<ipv> property is set to C<6>, this may
return an IPv4 address if the API endpoint is not reachable via IPv6.

=head2 interfaces(-->Seq:D)

  my $ha = Sys::HostAddr.new;
  @interfaces = $ha.interfaces.list;

Returns the interface names for the interfaces on the system.  Note that all
interfaces available to the C<ip> command will be returned, even if they do
not have IP addresses assigned.  If the C<ip> command cannot be executed
(for instance, on Windows), this will return a sequene with no members.

=head2 addresses(-->Seq:D)

  my $ha = Sys::HostAddr.new;
  @addresses = $ha.addresses.list;

Returns the addresses on the system.  If the C<ip> command cannot be
executed (for instance, on Windows), this will return a sequene with no
members.

=head2 addresses-on-interface(Str:D $interface -->Seq:D)

  my $ha = Sys::HostAddr.new;
  @addresses = $ha.addresses-on-interface("eth1").list;

Returns the addresses on the interface provided.  If the C<ip> command cannot
be executed (for instance, on Windows), this will return a sequene with no
members.

=head2 guess-ip-for-host(Str:D $ip -->Str)

  my $ha = Sys::HostAddr.new;
  $address = $ha.guess-ip-for-host('192.0.2.1');

Returns an address associated with the interface used to route packets to
the given destination.  Where more than one address exists on that interface,
or more than one interface has a route to the given host, only one will be
returned.

This will return C<Str> (undefined type object) if either the host isn't
routed in the routing table or if the C<ip> command cannot be executed (for
instance, on Windows).

=head2 guess-main(-->Str)

  my $ha = Sys::HostAddr.new;
  $address = $ha.guess-main-for-ipv4

Returns the result of either C<.guess-ip-for-host('0.0.0.0')> or
C<.guess-ip-for-host('2000::')> depending on the value of C<$.ipv4>.

=head2 guess-main-for-ipv6(-->Str)

  my $ha = Sys::HostAddr.new;
  $address = $ha.guess-main-for-ipv6

Returns the result of C<.guess-ip-for-host('2000::')>.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

Inspired by Perl 5 C<Sys::Hostname> by Jeremy Kiester.

=head1 COPYRIGHT AND LICENSE

Copyright © 2020-2022 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

