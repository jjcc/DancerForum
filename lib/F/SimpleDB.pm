package F::SimpleDB;

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../";

use Data::Dumper;
use DBI;
use DBD::Pg;

use Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw();

use F::Config;

sub new {
    my $class = shift;

    $class = ref $class if ref $class;
    my $self = bless {}, $class;

    $self;
}

sub init_db {
   $DBH = DBI->connect($DB{'DSN'},$DB{'USER'},$DB{'PASSWORD'},\%DB_OPTS);
}

sub disconnect {
   $DBH->disconnect; 
}

sub seq_next {
    my $self   = shift;
    my $table  = lc shift;

    my $seq_key = lc shift || 'id';

    #my $stmt = qq|SELECT nextval ('$table\_$seq_key\_seq')|;
    #debug("get nextval: $stmt\n");
    


    #my $hr = $DBH->selectrow_hashref($stmt);
    #debug("seq_next=$hr->{'nextval'}|".Dumper($hr));
   
    #by CJ

    my $stmt = qq|SHOW TABLE STATUS LIKE '$table' |;
    debug("sql statement: $stmt\n");
    my $hr = $DBH->selectrow_hashref($stmt);
    my $next_id= $hr->{'Auto_increment'} ;

    debug("Next id: $next_id");

    return $next_id;#$hr->{'nextval'};
}

sub insert {
    my $self    = shift;
    my $table  = shift;
    my $data   = shift;

    my @fields = keys %{$data};
    my @values = values %{$data};

    my $id = $self->seq_next($table);
    unshift @fields, 'id';
    unshift @values, $id;

    my $fields = join ",", @fields;
    my $placeholders = join ",", (split //, ('?' x (scalar @fields)));

    my $insert_stmt = qq|INSERT INTO $table ($fields) VALUES ($placeholders) |;
    debug($insert_stmt);
    my $sth = $DBH->prepare($insert_stmt);
    debug(join "|", @values);
    my $rv = $sth->execute(@values);

    return ($id, $rv);
}

sub update {
    my $self    = shift;
    my $table  = shift;
    my $data   = shift;
    my $where  = shift;
    my $opts   = shift;

    my @fields = keys %{$data};
    my @values = values %{$data};

    my @set = map {"$_ = ?"} @fields;
    my $set = join ",", @set;

    push @values, @{$opts->{'BIND'}} if $opts->{'BIND'};

    my $update_stmt = qq|UPDATE $table SET $set WHERE $where|;
    debug($update_stmt);
    
    my $sth = $DBH->prepare($update_stmt);
    my $rv = $sth->execute(@values);
    debug(Dumper(\@values));

    return $rv;
}

sub get1 {
    my $self = shift;

    $_[3]->{'LIMIT'} = 1;
    my @row = $self->get_all(@_);

    debug(Dumper($row[0]));
    return $row[0];
}

sub get_all {
    my $self   = shift;
    my $table  = lc shift;
    my $fields = lc shift;
    my $where  = shift;
    my $opts   = shift;

    my %tables = ();
    $tables{$table} = 'T1';
    my @fields = split /\s*,\s*/, $fields;
    
    my @where;
    
    ######### fields
    my @new_fields = ();
    for my $f (@fields) {
        if ($f =~ /^l:/) {
            $f =~ s/l://;
            $f = resolv($table,$f,\%tables,\@where);
        } else {
            $f = "T1.$f";
        }
        push @new_fields, $f;
    }

    ########## where 
    debug("before:" .$where);
    $where =~ s/l:([\w\.]+)/" ".resolv($table,$1,\%tables,\@where)/egs;
    $where =~ s/f:([\w]+)/"T1.$1"/egs;

    debug("after:" .$where);
    unshift @where, $where;

    ########### orderby
    
    my $orderby = '';
    if ($opts->{'ORDERBY'}) {
       $orderby  = $opts->{'ORDERBY'};
        debug("before:" .$orderby);
        $orderby =~ s/l:([\w\.]+)/" ".resolv($table,$1,\%tables,\@where)/egs;
        $orderby =~ s/f:([\w]+)/" T1.$1"/egs;
        debug("after:" .$orderby);
    
        $orderby = "ORDER BY $orderby\n";
    }

    ######### limit + offset
    my $limit  = $opts->{'LIMIT'}  ? "LIMIT $opts->{'LIMIT'}\n"   : '';
    my $offset = $opts->{'OFFSET'} ? "OFFSET $opts->{'OFFSET'}\n" : '';

    my $cond = join " AND ", @where;
    my $select_fields = join ", ", @new_fields;
    my $select_tables = '';
    
    ############ joined tables
    my @st = ();
    for my $t (keys %tables) {
        push @st, "$t AS $tables{$t}";
    }
    $select_tables = join ", ", @st;

    ########## combine
    my $select 
= qq|
SELECT\n
    $select_fields\n
FROM\n 
    $select_tables\n
WHERE\n
    $cond\n
$orderby
$limit
$offset
    |;

    debug($select);

    my $sth = $DBH->prepare($select);
    if ($opts->{'BIND'}) {
        $sth->execute(@{$opts->{'BIND'}});
    }else {
        $sth->execute();
    }
    my @table_rows;
    while(my $hr = $sth->fetchrow_hashref) {
        push @table_rows, $hr;
    }

    return @table_rows;
}

sub resolv {
    my $t = shift;
    my $f = shift;
    my $tables = shift;
    my $where  = shift;

    my @path = split /\./, $f;
    if (scalar @path < 2) {
        die "error: invalid field f=[$f]";
    }

    my $link_table = $t;
    while (scalar @path > 1) {
        $link_table = resolv_short($link_table, $path[0], $path[1], $tables, $where);
        shift @path;
    }

    my $count = keys %{$tables};

    return $tables->{$link_table}.".".$path[0];
}


sub resolv_short {
    my $t  = shift;
    my $f1 = shift;
    my $f2 = shift;
    my $tables = shift;
    my $where  = shift;

   if ($DB_JOIN_FIELDS{$t}->{$f1}) {
        my ($lt, $lf) = split /\s*:\s*/, $DB_JOIN_FIELDS{$t}->{$f1};
        my $count = keys %{$tables};
        unless ($tables->{$lt}) {
            my $next = $count + 1;
            $tables->{$lt} = 'T'.$next;

            my $join_where = "T$count.$f1 = T$next.id";
            debug($join_where);
            push @{$where}, $join_where;
        }

        return $lt;
   }else {
        die "error: missing in join fields t=[$t]f1=[$f1]";
   }
   
}

sub debug {
    my $msg = shift;
    print STDERR $msg, "\n";
}

1;
