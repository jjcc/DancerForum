package admin;

use Dancer ':syntax';

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Dancer::Plugin::Database;
use Dancer::Plugin::SimpleCRUD;
use Data::Dumper;

use SimpleDB;


simple_crud (
    record_title => 'User',    
    prefix => '/admin/users',
    db_table => 'users',
);

simple_crud (
    record_title => 'Groups',    
    prefix => '/admin/groups',
    db_table => 'groups',

);

simple_crud (
    record_title => 'Threads',
    prefix => '/admin/threads',
    db_table => 'threads'
);

simple_crud (
    record_title => 'Posts',
    prefix => '/admin/posts',
    db_table => 'posts'
);

get '/admin/test' => sub {
    my $db = SimpleDB->new(database);

    #my @rows = $db->get1('threads', 'id, l:user_id.username,l:user_id.website, subject',
    #    "f:id > ? and l:user_id.username = 'tspenov'",
    #    {BIND => [0], ORDERBY => 'f:id DESC'});
    
    #debug(Dumper(\@rows));

    #my ($id, $rv) = $db->insert('users', {username => 'pencho', 'website' => 'http://pencho.com'});
    #return "id=$id, rv=$rv";

    #my $rv = $db->update('users', {username => 'gencho'}, "id = 10");
    #return $rv;


    #$str .= $db->select('posts', 'id, user_id, thread_id.user_id.username, text', "id > 0", {})."\n\n\n";
    #$str .= $db->select('posts', 'id, user_id, thread_id.user_id.username, text', "id > 0 AND thread_id.user_id.username='tspenov\@datamax.bg'", {})."\n\n\n";

};

1;
