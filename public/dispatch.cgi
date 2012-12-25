#!/usr/bin/env perl
use Dancer ':syntax';
use FindBin '$RealBin';
use Plack::Runner;

my $psgi = path($RealBin, '..', 'bin', 'app.pl');
Plack::Runner->run($psgi);
