package F::Config;

use strict;
use warnings;

use Data::Dumper;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
    $SITE_PREFIX
    %DB
    %DB_OPTS
    $DBH
    %DB_FIELDS
    %DB_JOIN_FIELDS
);

our $DBH = undef;
our $SITE_PREFIX = '/forum';

our %DB = (
    DSN      => 'dbi:mysql:dbname=running',
    # USER     => 'ceci',
    # PASSWORD => 'alabala',

    USER     => 'root',
    PASSWORD => '',
);

our %DB_OPTS = (
    RaiseError => 1,
    AutoCommit => 1
);

our %DB_FIELDS = (
    users      => ['id', 'username', 'email', 'website', 'password'],
    groups     => ['id', 'name'],
    user_group => ['id', 'user_id', 'group_id'],
    topics    => ['id', 'subject', 'user_id', 'parent_topic'],
    posts      => ['id', 'text', 'topic_id', 'user_id'],
    comments   => ['id', 'text', 'post_id', 'user_id'],
);

our %DB_JOIN_FIELDS = (
    user_group => {'user_id'    => 'users:username',    'group_id'      => 'groups:name'},
    topics    => {'user_id'    => 'users:username',    'parent_topic' => 'topics:subject'},
    posts      => {'topic_id'  => 'topics:subject',   'user_id'       => 'users:username',},
    comments   => {'post_id'    => 'posts:id',   'user_id'       => 'users:username',},
);



1;
