[![SparrowCI](https://ci.sparrowhub.io/project/gh-jmaslak-Raku-Sys-HostAddr/badge?)](https://ci.sparrowhub.io)

NAME
====

Sys::Domainname - Get IP address information about this host

SYNOPSIS
========

    use Sys::Domainname;

    my $sysaddr = Sys::HostAddr.new;
    my $string = $sysaddr->public;

    my @addresses = $sysaddr->addresses;
    my @interfaces = $sysaddr->interfaces;
    my @on-int-addresses = $sysaddr->addresses-on-interface('eth0');

DESCRIPTION
===========

This module provides methods for determining IP address information about a local host.

WARNING
=======

This module only functions on relatively recent Linux.

ATTRIBUTES
==========

ipv
---

This attribute refers to the IP Version the class operates against. It must be set to either `4` or `6`. This defaults to `4`.

ipv4-url
--------

This is the API URL used to obtain the host's public IPv4 address. It defaults to using `https://api.ipify.org`. The URL must return the address as a plain text response.

ipv6-url
--------

This is the API URL used to obtain the host's public IPv4 address. It defaults to using `https://api6.ipify.org`. The URL must return the address as a plain text response.

user-agent
----------

This is the user agent string used to idenfiy this module when making web calls. It defaults to this module's name and version.

filter-localhost
----------------

If `filter-localhost` is true, only non-localhost addresses will be returned by this class's methods. This defaults to true.

Localhost is defined as any IPv4 address that begins with `127.` or the IPv6 address `::1`.

filter-link-local
-----------------

If `filter-link-local` is true, only non-link-local addresses will be returned by this class's methods. This defaults to true and has no impact when `ipv` is set to `4`.

Link local is defined as any IPv4 address that belong to `fe80::/10`.

METHODS
=======

public(-->Str:D)
----------------

    my $ha = Sys::HostAddr.new;
    say "My public IP: { $ha.public }";

Returns the public IP address used by this host, as determined by contacting an external web service. When the `ipv` property is set to `6`, this may return an IPv4 address if the API endpoint is not reachable via IPv6.

interfaces(-->Seq:D)
--------------------

    my $ha = Sys::HostAddr.new;
    @interfaces = $ha.interfaces.list;

Returns the interface names for the interfaces on the system. Note that all interfaces available to the `ip` command will be returned, even if they do not have IP addresses assigned. If the `ip` command cannot be executed (for instance, on Windows), this will return a sequene with no members.

addresses(-->Seq:D)
-------------------

    my $ha = Sys::HostAddr.new;
    @addresses = $ha.addresses.list;

Returns the addresses on the system. If the `ip` command cannot be executed (for instance, on Windows), this will return a sequene with no members.

addresses-on-interface(Str:D $interface -->Seq:D)
-------------------------------------------------

    my $ha = Sys::HostAddr.new;
    @addresses = $ha.addresses-on-interface("eth1").list;

Returns the addresses on the interface provided. If the `ip` command cannot be executed (for instance, on Windows), this will return a sequene with no members.

guess-ip-for-host(Str:D $ip -->Str)
-----------------------------------

    my $ha = Sys::HostAddr.new;
    $address = $ha.guess-ip-for-host('192.0.2.1');

Returns an address associated with the interface used to route packets to the given destination. Where more than one address exists on that interface, or more than one interface has a route to the given host, only one will be returned.

This will return `Str` (undefined type object) if either the host isn't routed in the routing table or if the `ip` command cannot be executed (for instance, on Windows).

guess-main(-->Str)
------------------

    my $ha = Sys::HostAddr.new;
    $address = $ha.guess-main-for-ipv4

Returns the result of either `.guess-ip-for-host('0.0.0.0')` or `.guess-ip-for-host('2000::')` depending on the value of `$.ipv4`.

guess-main-for-ipv6(-->Str)
---------------------------

    my $ha = Sys::HostAddr.new;
    $address = $ha.guess-main-for-ipv6

Returns the result of `.guess-ip-for-host('2000::')`.

AUTHOR
======

Joelle Maslak <jmaslak@antelope.net>

Inspired by Perl 5 `Sys::Hostname` by Jeremy Kiester.

COPYRIGHT AND LICENSE
=====================

Copyright © 2020-2022 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

