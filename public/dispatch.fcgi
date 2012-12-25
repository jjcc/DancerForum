#!/usr/bin/env perl
use Dancer ':syntax';
use FindBin '$RealBin';
use Plack::Handler::FCGI;

my $psgi = path($RealBin, '..', 'bin', 'app.pl');
my $app = do($psgi);
my $server = Plack::Handler::FCGI->new(nproc => 5, detach => 1);

$server->run($app);
