use Test::More tests => 2;
BEGIN { use_ok('CGI::Application::Plugin::TT') };

use lib './t';
use strict;

$ENV{CGI_APP_RETURN_ONLY} = 1;

use CGI;
use TestAppError;
my $t1_obj = TestAppError->new();

my $t1_output = eval { $t1_obj->run() };

like($@, qr/parse error/, 'template parse error');

