package CGI::Application::Plugin::TT;

use Template 2.0;
use CGI::Application 3.0;
use Carp;

use strict;
use vars qw($VERSION @EXPORT);

require Exporter;

@EXPORT = qw(
  tt_obj
  tt_config
  tt_params
  tt_clear_params
  tt_process
);
sub import { goto &Exporter::import }

$VERSION = '0.03';

##############################################
###
###   tt_obj
###
##############################################
#
# Get a Template Toolkit object.  The same object
# will be returned everytime this method is called
# during a request cycle.
#
sub tt_obj {
  my $self = shift;

  if (!$self->{__TT_OBJ}) {
    $self->{__TT_OBJ} = Template->new( $self->{__TT_CONFIG}->{TEMPLATE_OPTIONS} ) || carp "Can't load Template";
  }
  return $self->{__TT_OBJ};
}

##############################################
###
###   tt_config
###
##############################################
#
# Configure the Template Toolkit object
#
sub tt_config {
    my $self = shift;

    if (@_) {
      carp "Calling tt_config after the tt object has already been created" if (defined $self->{__TT_OBJ});
      my $props;
      if (ref($_[0]) eq 'HASH') {
          my $rthash = %{$_[0]};
          $props = $self->_cap_hash($_[0]);
      } else {
          $props = $self->_cap_hash({ @_ });
      }

      # Check for TEMPLATE_OPTIONS
      if ($props->{TEMPLATE_OPTIONS}) {
        carp "tt_config error:  parameter TEMPLATE_OPTIONS is not a hash reference" if ref $props->{TEMPLATE_OPTIONS} ne 'HASH';
        $self->{__TT_CONFIG}->{TEMPLATE_OPTIONS} = delete $props->{TEMPLATE_OPTIONS};
      }

      # If there are still entries left in $props then they are invalid
      carp "Invalid option(s) (".join(', ', keys %$props).") passed to tt_config" if %$props;
    }

    $self->{__TT_CONFIG};
}

##############################################
###
###   tt_params
###
##############################################
#
# Set some parameters that will be added to 
# any template object we process in this
# request cycle.
#
sub tt_params {
  my $self = shift;
  my @data = @_;

  # Define the params stash if it doesn't exist
  $self->{__TT_PARAMS} ||= {};

  if (@data) {
    my $params    = $self->{__TT_PARAMS};
    my $newparams = {};
    if (ref $data[0] eq 'HASH') {
      # hashref
      %$newparams = %{ $data[0] };
    } elsif ( (@data % 2) == 0 ) {
      %$newparams = @data;
    } else {
      carp "tt_params requires a hash or hashref!";
    }

    # merge the new values into our stash of parameters
    @$params{keys %$newparams} = values %$newparams;
  }

  return $self->{__TT_PARAMS};
}

##############################################
###
###   tt_clear_params
###
##############################################
#
# Clear any template parameters that may have
# been set during this request cycle.
#
sub tt_clear_params {
  my $self = shift;

  my $params = $self->{__TT_PARAMS};
  $self->{__TT_PARAMS} = {};

  return $params;
}

##############################################
###
###   tt_pre_process
###
##############################################
#
# Overridable method that is called just before
# a Template is processed.
# Useful for setting global template params.
# It is passed the template filename and the hashref
# of template data
#
sub tt_pre_process {
  my $self = shift;
  my $file = shift;
  my $vars = shift;

  # Nothing to pre process, yet!
}

##############################################
###
###   tt_post_process
###
##############################################
#
# Overridable method that is called just after
# a Template is processed.
# Useful for post processing the HTML.
# It is passed a scalar reference to the HTML code.
#
# Note:  This can also be accomplished using the 
#        cgiapp_postrun method
#
sub tt_post_process {
  my $self    = shift;
  my $htmlref = shift;

  # Nothing to post process, yet!
}

##############################################
###
###   tt_process
###
##############################################
#
# Process a Template Toolkit template and return
#  the resulting html as a scalar ref
#
sub tt_process {
  my $self = shift;
  my $file = shift;
  my $vars = shift || {};
  my $html = '';

  # Call tt_pre_process hook
  $self->tt_pre_process($file, $vars) if $self->can('tt_pre_process');

  # Include any parameters that may have been
  # set with tt_params
  my %params = ( %{ $self->tt_params() }, %$vars );

  $self->tt_obj->process($file, \%params, \$html);

  # Call tt_post_process hook
  $self->tt_post_process(\$html) if $self->can('tt_post_process');

  return \$html;
}

1;
__END__

=head1 NAME

CGI::Application::Plugin::TT - Add Template Toolkit support to CGI::Application


=head1 SYNOPSIS

 use base qw(CGI::Application);
 use CGI::Application::Plugin::TT;

 sub myrunmode {
   my $self = shift;

   my %params = {
                 email       => 'email@company.com',
                 menu        => [
                                 { title => 'Home',     href => '/home.html',
                                   title => 'Download', href => '/download.html', },
                                ],
                 session_obj => $self->session,
   };

   return $self->tt_process('template.tmpl', \%params);
 }

=head1 DESCRIPTION

CGI::Application::Plugin::TT adds support for the popular Template Toolkit engine
to your L<CGI::Application> modules by providing several helper methods that
allow you to process template files from within your runmodes.

It compliments the support for L<HTML::Template> that is built into L<CGI::Application>
through the B<load_tmpl> method.  It also provides a few extra features than just the ability
to load a template.

=head1 METHODS

=head2 tt_process

This is a simple wrapper around the Template Toolkit process method.  It accepts two parameters,
a template filename, and a hashref of template parameters.  The return value will be a scalar
reference to the output of the template.

  sub myrunmode {
    my $self = shift;

    return $self->tt_process('my_runmode.tmpl', { foo => 'bar' });
  }
 

=head2 tt_config

This method can be used to customize the functionality of the CGI::Application::Plugin::TT module,
and the Template Toolkit module that it wraps.  The recommended place to call C<tt_config>
is in the C<cgiapp_init> stage of L<CGI::Application>.  If this method is called after a
call to tt_process or tt_obj, then it will die with an error message.

It is not a requirement to call this method, as the module will work without any
configuration.  However, most will find it useful to set at least a path to the
location of the template files.

The following parameters are accepted:

=over 4

=item TEMPLATE_OPTIONS

This allows you to customize how the L<Template> object is created by providing a list of
options that will be passed to the L<Template> constructor.  Please see the documentation
for the L<Template> module for the exact syntax of the parameters, or see below for an example.

=back

=head2 tt_obj

This method will return the underlying Template Toolkit object that is used
behind the scenes.  It is usually not necesary to use this object directly,
as you can process templates and configure the Template object through
the tt_process and tt_config methods.  Every call to this method will
return the same object during a single request.

It may be useful for debugging purposes.

=head2 tt_params

This method will accept a hash or hashref of parameters that will be included
in the processing of every call to tt_process.  It is important to note that
the parameters defined using tt_params will be passed to every template that is
processed during a given request cycle.  Usually only one template is processed
per request, but it is entirely possible to call tt_process multiple times with
different templates.  Everytime tt_process is called, the hashref of parameters
passed to tt_process will be merged with the parameters set using the tt_params
method.  Parameters passed through tt_process will have precidence in case of
duplicate parameters.

This can be useful to add global values to your templates, for example passing
the user's name automatically if they are logged in.

  sub cgiapp_prerun {
    my $self = shift;

    $self->tt_params(username => $ENV{REMOTE_USER}) if $ENV{REMOTE_USER};
  }

=head2 tt_params_clear

This method will clear all the currently stored parameters that have been set with
tt_params.


=head2 tt_pre_process

This is an overridable method that works in the spirit of cgiapp_prerun.  The method will
be called just before a template is processed, and will be passed the same parameters
that were passed to tt_process (ie the template filename, and a hashref of template parameters).
It can be used to make last minute changes to the template, or the parameters before
the template is processed.

=head2 tt_post_process

This, like it's counterpart cgiapp_postrun, is called right after a template has been processed.
It will be passed a scalar reference to the processed template.



=head1 EXAMPLE

In a CGI::Application module:

  use CGI::Application::Plugin::TT;
  use base qw(CGI::Application);
  
  # configure the template object once during the init stage
  sub cgiapp_init {
    my $self = shift;
 
    # Configure the template
    $self->tt_config(
              TEMPLATE_OPTIONS => {
                        INCLUDE_PATH => '/path/to/template/files',
                        POST_CHOMP   => 1,
                        FILTERS => {
                                     'currency' => sub { sprintf('$ %0.2f', @_) },
                        },
              },
    );
  }
 
  sub cgiapp_prerun {
    my $self = shift;
 
    # Add the username to all templates if the user is logged in
    $self->tt_params(username => $ENV{REMOTE_USER}) if $ENV{REMOTE_USER};
  }

  sub tt_pre_process {
    my $self = shift;
    my $template = shift;
    my $params = shift;

    # could add the username here instead if we want
    $params->{username} = $ENV{REMOTE_USER}) if $ENV{REMOTE_USER};

    return;
  }

  sub tt_post_process {
    my $self    = shift;
    my $htmlref = shift;
 
    # clean up the resulting HTML
    require HTML::Clean;
    my $h = HTML::Clean->new($htmlref);
    $h->strip;
    my $newref = $h->data;
    $$htmlref = $$newref;
    return;
  }
 
 
  sub my_runmode {
    my $self = shift;
 
    my %params = (
            foo => 'bar',
    );
 
    # return the template output
    return $self->tt_process('my_runmode.tmpl', \%params);
  }


=head1 BUGS

This is alpha software and as such, the features and interface
are subject to change.  So please check the Changes file when upgrading.


=head1 SEE ALSO

L<CGI::Application>, L<Template>, perl(1)


=head1 AUTHOR

Cees Hek <cees@crtconsulting.ca>


=head1 LICENSE

Copyright (C) 2004 Cees Hek <cees@crtconsulting.ca>

This library is free software. You can modify and or distribute it under the same terms as Perl itself.

=cut

