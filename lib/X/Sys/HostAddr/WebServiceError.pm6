use v6;

#
# Copyright © 2020 Joelle Maslak
# All Rights Reserved - See License
#

unit class X::Sys::HostAddr::WebServiceError:ver<0.2.0>:auth<zef:jmaslak>
    is Exception;

method message() { "Could not obtain IP address from web service" }

=begin pod

=head1 NAME

X::Sys::HostAddr::WebServiceError - Web Service Error Exception

=head1 DESCRIPTION

This inherits from C<Exception>.  It is used to throw an error when the public
IP API lookup fails.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2020 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

