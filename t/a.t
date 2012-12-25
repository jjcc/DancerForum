#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);

use lib "$Bin/../lib";

use F::Config;
use F::SimpleDB;

use Data::Dumper;

F::SimpleDB->init_db() unless $DBH;

my $db = new F::SimpleDB;
my $hr = $db->get1('comments', "id", "l:post_id.topic_id = ?", 
    {BIND => [3], ORDERBY => "f:create_time DESC"});

print Dumper($hr);

