package running;

use Dancer ':syntax';
our $VERSION = '0.1';

use FindBin qw($Bin);
use lib "$Bin/../lib";

#use Dancer::Plugin::Email;

use Data::Dumper;
use Text::Markdown qw(markdown);
use Gravatar::URL;
use Digest::SHA1 qw(sha1_hex);
use Net::OpenID::Consumer;
use LWP::UserAgent;
#use Cache::File;

use F::Config;
use F::SimpleDB;
use F::Utils;

use utf8;

prefix $SITE_PREFIX if $SITE_PREFIX;
print STDERR Dumper(request);
F::SimpleDB->init_db() unless $DBH; 

before sub {
};

before_template sub {
    my $tokens = shift;
    $tokens->{'site_prefix'} = $SITE_PREFIX if $SITE_PREFIX; #pass site_prefix to all templates
};

get '/' => sub {
    template 'index';
};

get '/openid' => sub {
    if (params->{openid}) {
        my $openid = params->{openid};
        $openid =~ s#(^http://|^(?!https))#https://# if $openid =~ /myopenid/;

        my $csr = Net::OpenID::Consumer->new(
            ua    => LWP::UserAgent->new,
            required_root => 'http://localhost:3000/',
            consumer_secret => 'xYZabC0123',
            debug => 1,
	    #cache => Cache::File->new( cache_root => '/tmp/mycache' ),
        );

        my $cident = $csr->claimed_identity($openid);
        debug("claimed_id".Dumper($cident));
        
        if ($cident) {
	#my $url = $cident->claimed_url;
        #my $id_server = $cident->identity_server;
        #my $del_url = $cident->delegated_url;
        #my $version = $cident->protocol_version;
	#debug("################# \n url=$url| id_server=$id_server | del_url=$del_url | version=$version");
            
            my $check_url = $cident->check_url(
                return_to  => "http://localhost:3000$SITE_PREFIX/openid_response",
                trust_root => 'http://localhost:3000/',
                delayed_return => 1,
            );
            
            my $sreg_ns 	= "openid.ns.sreg=http://openid.net/extensions/sreg/1.1";
            my $sreg_params = "openid.sreg.optional=nickname,email,fullname,dob,country,gender,timezone,postcode,language";

            $check_url = "$check_url&$sreg_ns&$sreg_params";
            debug("check_url".Dumper($check_url));
            redirect $check_url;
        }else {
			return "The provided URL doesn't declare its OpenID identity server!";
		}
    }else {
        template 'openid';
    }
};


get '/openid_response' => sub {
    my %allparams = request->params;
    debug("allparams=".Dumper(\%allparams));

    my $csr = Net::OpenID::Consumer->new(
        required_root => 'http://localhost:3000/',
        consumer_secret => 'xYZabC0123',
        args  => \%allparams,
        debug => 1,
    );

    $csr->handle_server_response (
        not_openid => sub {
            return "That's not an OpenID message. Did you just type in the URL?";
        },
        setup_required => sub {
            my $setup_url = shift;
            debug("setup_url: $setup_url");
            redirect $setup_url;
        },
        cancelled => sub {
            return 'You cancelled your login.\n';
        },
        verified => sub {
            my $vident = shift;
            debug("vident".Dumper($vident));
            my $url = $vident->url;
            
			_login_or_register_user($url, \%allparams);
			#my $msg = join " | ", ($vident->display, $vident->signed_fields->{'sreg.fullname'}, $vident->{signed_fields}{'sreg.nickname'}, $vident->signed_fields->{'sreg.email'}, $vident->signed_fields->{'sreg.country'});
			#return "You are verified as '$url'. $msg";
			redirect "$SITE_PREFIX";
        },
        error => \&_handle_errors,
    );
};

sub _login_or_register_user {
	my $openid_url = shift;
	my $extra_info = shift;

	my $db = new F::SimpleDB;
	my $hr = $db->get1('users', 'id, username', "f:openid_url = ?", {BIND => [$openid_url]});
	if ($hr->{'id'}) {
		session username => $hr->{username};
		session user_id  => $hr->{id};

	}else {

		my $username  = $extra_info->{'openid.sreg.nickname'} || $openid_url;
		my $real_name = $extra_info->{'openid.sreg.fullname'};
		my $email     = $extra_info->{'openid.sreg.email'}; 

		my ($user_id, $rv) = $db->insert('users', 
				{
						openid_url => $openid_url,
						username => $username, 
						email => $email, 
				}
		);

		session username => $username;
		session user_id  => $user_id;
	}

}

sub _handle_errors {
    my ($err) = @_;

    return "<b>Error: $err</b> \n";
    
    if ($err eq 'server_not_allowed') {
        return qq|You may have gone to an http: server and come back from an https: server. This happens with "myopenid.com".|;
    } elsif ($err eq 'naive_verify_failed_return') {
        print 'Oops! Did you reload this page?';
    }
}


### register, login, logout
get '/register' => sub {
    my $tmpl_opts;
    if (params->{failed}) {
        $tmpl_opts->{'typed_username'}  = session('typed_username');
        $tmpl_opts->{'typed_email'}     = session('typed_email');
        $tmpl_opts->{'typed_website'}   = session('typed_website');
        $tmpl_opts->{'error_msg'}       = session('register_error_msg');     
    }
    template 'register', $tmpl_opts;
};

post '/register' => sub {
    my $error_msg;
 
    
    if (params->{username}) {
        if (params->{password} ne params->{conf_password}) {
            $error_msg = "Passwords don't match";
        }
       

        my $db = new F::SimpleDB;
        unless($error_msg) {
            my ($user_id, $rv) = $db->insert('users', 
                {
                    username => params->{username}, 
                    email => params->{email}, 
                    password => lc sha1_hex(params->{password}),
                    website =>  params->{website},
                    
                }
            );
            session username => params->{username};
            session user_id  => $user_id;

            debug("########### PATH=".params->{path});
            redirect params->{path} || "$SITE_PREFIX";
        }
        else {
            session typed_username => params->{username};
            session typed_email    => params->{email};
            session typed_website    => params->{website};
            session register_error_msg => $error_msg;
            redirect "$SITE_PREFIX/register?failed=1";
        }
    }
    else{
    	
 		$error_msg = "username is manatory";
 		
        session typed_email    => params->{email};
        session typed_website    => params->{website};
        session register_error_msg => $error_msg; 		
		redirect "$SITE_PREFIX/register?failed=1";   	
    }
};

get '/login' => sub {
    my $tmpl_opts;
    if (params->{failed}) {
        $tmpl_opts->{'typed_username'}  = session('typed_username');
        $tmpl_opts->{'error_msg'}       = session('login_error_msg') || "Invalid username or password";
        session login_error_msg => '';
    }

    template 'login', $tmpl_opts;
};

post '/login' => sub {
    my $db = new F::SimpleDB;
    if (params->{username} && params->{password} ) {
        my $user = $db->get1('users', "id, username", "f:username = ? and f:password = ?", 
                { BIND => [params->{username}, lc sha1_hex(params->{password}) ] }
            );
        
        if ($user->{id}) {
            session username => $user->{username};
            session user_id  => $user->{id};

            redirect params->{path} || "$SITE_PREFIX";
        }
        else {
            session typed_username => params->{username};
            redirect "$SITE_PREFIX/login?failed=1";
        }
    }
    else{
        session typed_username => params->{username};
        redirect "$SITE_PREFIX/login?failed=1";
    }
};

get '/logout' => sub {
    session->destroy;
    redirect "$SITE_PREFIX";
};

post '/markdown' => sub {
    my $html = markdown(params->{data});
    debug("\n\n$html\n\n");

    return $html;
};

post '/bbcode' => sub {

    my $data = params->{data};
    my $html = bb2html($data);

    return $html;
};

get '/topics' => sub {
    my $db = new F::SimpleDB;
    my @rows = $db->get_all('topics', 'id, subject, create_time',
        "f:id > 0 AND f:parent_topic = 1" , {ORDERBY => "ID ASC"});

	my @topics = ();
	for my $t (@rows) {
		$t->{'posts_count'} = _get_posts_count_by_topic($t->{'id'});
		$t->{'comments_count'} = _get_replies_count_by_topic($t->{'id'});
        $t->{'last_reply'} = _get_last_reply_for_topic($t->{'id'}) || '0';
		push @topics, $t;
	}

    debug(Dumper(\@topics));
    template 'forum', {topics => \@topics};
};



sub _get_posts_count_by_topic {
	my $topic_id = shift;
	my $sth = $DBH->prepare(qq|SELECT count(*) FROM posts WHERE topic_id = ?|);
	$sth->execute($topic_id);
	my $row = $sth->fetchrow_hashref;
	debug(Dumper($row));

	return $row->{'count'} || 0; 
}

sub _get_replies_count_by_topic {
	my $topic_id = shift;
	my $sth = $DBH->prepare(qq|SELECT count(*) FROM comments WHERE post_id IN (SELECT id FROM posts WHERE topic_id = ?)|);
	$sth->execute($topic_id);
	my $row = $sth->fetchrow_hashref;
	debug(Dumper($row));

	return $row->{'count'} || 0;
}

sub _get_last_reply_for_topic {
    my $topic_id = shift;

    my $db = new F::SimpleDB;
    my $hr = $db->get1('comments', "id, create_time, post_id", "l:post_id.topic_id = ?",
            {BIND => [$topic_id], ORDERBY => "f:create_time DESC"});
    return $hr;
}

sub _get_last_reply_for_post {
    my $post_id = shift;

    my $db = new F::SimpleDB;
    my $hr = $db->get1('comments', "id, create_time, post_id, user_id, l:user_id.username", "f:post_id = ?",
            {BIND => [$post_id], ORDERBY => "f:create_time DESC"});
    return $hr;
}

sub _get_replies_count_for_post {
    my $post_id = shift;
    my $db = new F::SimpleDB;
    my $sth = $DBH->prepare(qq|SELECT count(*) FROM comments WHERE post_id = ?|);
    $sth->execute($post_id);
    my $row = $sth->fetchrow_hashref;
    debug(Dumper($row));

    return $row->{'count'} || 0;
}



get '/topic/:id' => sub {
    my $id = params->{'id'};

	my $page = params->{'page'} || 1;
	my $count_pp = 2;
	my $posts_count = _get_posts_count_by_topic($id);
	my $pages = $posts_count / $count_pp;
	$pages++ if ($posts_count % $count_pp != 0);
	my $limit = $count_pp;
	my $offset = ($page - 1) * $count_pp;

    my $args;

	$args->{pages} = $pages;
	$args->{current_page} = $page;

    my $db = new F::SimpleDB;
    
    my $topic = $db->get1('topics', 'id, subject', "f:id = ?", {BIND => [$id] });
    
    unless ($topic->{'id'}) { send_error("Not Found", 404); };
    $args->{'parent_topic'} = $topic;

    my @rows = $db->get_all('posts',
        'id, subject, text, user_id, topic_id, l:user_id.username, create_time, comments, views', 
        'f:topic_id = ?', 
        {BIND => [$id], LIMIT => $limit, OFFSET => $offset, ORDERBY => "create_time DESC"});

    debug(Dumper(\@rows));
    my @posts = ();
    if (@rows) {
        for my $hr (@rows) {
            $hr->{comments}   = _get_replies_count_for_post($hr->{id});
            $hr->{last_reply} = _get_last_reply_for_post($hr->{id});
            push @posts, $hr;
        }
        $args->{posts} = \@posts;
    }else {
        $args->{no_posts} = 1;
    }

    debug(Dumper($args));

    template 'topic', $args;
};

get '/admin/topic/new' => sub {
   template 'topic_new'; 
};

post '/admin/topic/new' => sub {
    my $subject = params->{subject};
    my $user_id = params->{user_id};
    my $parent_topic = params->{parent_topic};

    my $db = new F::SimpleDB;
    $db->insert('topics',
        {
            subject => $subject,
            user_id => session('user_id'),
            parent_topic => 1,
            create_time => time,
            views => 0,
        }
    );
    
    redirect "$SITE_PREFIX/topics";
};




get '/topic/:topic/post/new' => sub {
    my $parent_topic = params->{topic};

    template 'post_new', {parent_topic => $parent_topic};
};

post '/topic/:topic/post/new' => sub {
    my $text = params->{text};
    my $subject = params->{subject};
    my $parent_topic = params->{topic};

    my $user_id = session('user_id');

    my $db = new F::SimpleDB;
    my ($id, $rv) = $db->insert('posts', 
        {
            subject => $subject,
            text => $text, 
            user_id => $user_id,
            topic_id => $parent_topic,
            create_time => time,
        }
    );

    redirect "$SITE_PREFIX/topic/$parent_topic";
};


get '/topic/:topic/post/:id' => sub {
    my $parent_topic = params->{topic};
    my $post_id       = params->{id};
    
    my $args;
    my $db = new F::SimpleDB;

    my $topic = $db->get1('topics', 'id, subject', "f:id = ?", {BIND => [$parent_topic] });

    $args->{parent_topic} = $topic if $topic;

    my $post = $db->get1('posts', 'id, text, views, subject, user_id, l:user_id.username, l:user_id.email, create_time', 
        "f:id = ?", {BIND => [$post_id]});

    if ($post) {
        $db->update('posts', { views => $post->{'views'} + 1}, "id = ?", {BIND => [$post_id]});
    }

    $post->{text} = bb2html($post->{text});
    $post->{avatar} = gravatar_url(email => $post->{email});
    $args->{post} = $post if $post;
    
    my @rows = $db->get_all('comments', "id, text, user_id, l:user_id.username, l:user_id.email,create_time ", 
        "f:post_id = ?", {BIND => [$post_id], ORDERBY => "create_time DESC"});

    debug(Dumper(\@rows));
    
    my @comments;
    if (@rows) {
        for my $hr (@rows) {
            $hr->{text} = bb2html($hr->{text});
            $hr->{avatar} = gravatar_url(email => $hr->{email});
            push @comments, $hr;
        }
        $args->{comments} = \@comments;
    }else {
        $args->{no_comments} =1;
    }


    template 'post_show', $args;
};

get '/topic/:topic/post/:id/reply' => sub {
    my $parent_topic = params->{topic};
    my $post_id       = params->{id};
        
    my $args;
    my $db = new F::SimpleDB;
    my $topic = $db->get1('topics', 'id, subject', "f:id = ?", {BIND => [$parent_topic] });

    $args->{topic} = $topic if $topic;

    my $post = $db->get1('posts', 'id, text, subject, user_id, l:user_id.username, create_time', 
        "f:id = ?", {BIND => [$post_id]});

    $post->{text} = bb2html($post->{text});
    $args->{post} = $post if $post;

    template 'post_reply', $args;
};

post '/topic/:topic/post/:id/reply' => sub {
    my $parent_topic = params->{topic};
    my $post_id       = params->{id};

    my $text = params->{text};
   
    my $db = new F::SimpleDB;
    my ($id, $rv) = $db->insert('comments', 
        {
            text => $text, 
            user_id => session('user_id'),
            post_id => $post_id,
            create_time => time,
        }
    );

    redirect "$SITE_PREFIX/topic/$parent_topic/post/$post_id";
};

true;
