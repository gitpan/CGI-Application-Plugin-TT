package TestAppBase;

use strict;

use CGI::Application;
use CGI::Application::Plugin::TT;
@TestAppBase::ISA = qw(CGI::Application);

sub cgiapp_init {
    my $self = shift;

    $self->tt_config(
              TEMPLATE_OPTIONS => {
                        INCLUDE_PATH => 't',
                        POST_CHOMP   => 1,
                        DEBUG => 1,
              },
    );
}

sub setup {
    my $self = shift;
    $self->start_mode('test_mode');
    $self->run_modes(test_mode => 'test_mode' );
}

1;
