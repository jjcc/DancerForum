package F::Utils;

use strict;
use warnings;

use Data::Dumper;
use HTML::BBCode;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
    bb2html
);

sub bb2html {
   my $data = shift;

   my $bbc  = HTML::BBCode->new( {linebreaks   => 1,} );
   my $html = $bbc->parse($data); 


   $html =~ s#:\)#<img src="/images/emoticons/emoticon-happy.png" alt=":)">#g;
   $html =~ s#:\(#<img src="/images/emoticons/emoticon-unhappy.png" alt=":(">#g;
   $html =~ s#:o#<img src="/images/emoticons/emoticon-surprised.png" alt=":o">#g;
   $html =~ s#:p#<img src="/images/emoticons/emoticon-tongue.png" alt=":p">#g;
   $html =~ s#;\)#<img src="/images/emoticons/emoticon-wink.png" alt=";)">#g;
   $html =~ s#:D#<img src="/images/emoticons/emoticon-smile.png" alt=":D">#g; 

   return $html;
}

1;
