package CGI::Application::Plugin::TT;

use Template 2.0;
use CGI::Application 3.0;
use Carp;
use File::Spec ();
use Scalar::Util ();

use strict;
use vars qw($VERSION @EXPORT);

require Exporter;

@EXPORT = qw(
    tt_obj
    tt_config
    tt_params
    tt_clear_params
    tt_process
    tt_include_path
    tt_template_name
);
sub import {
    my $pkg = shift;
    my $callpkg = caller;
    no strict 'refs';
    foreach my $sym (@EXPORT) {
        *{"${callpkg}::$sym"} = \&{$sym};
    }
    $callpkg->tt_config(@_) if @_;
}

$VERSION = '0.06';

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

    my ($tt, $options, $frompkg) = _get_object_or_options($self);

    if (!$tt) {
        my $tt_options = $options->{TEMPLATE_OPTIONS};
        if (keys %{$options->{TEMPLATE_OPTIONS}}) {
          $tt = Template->new( $options->{TEMPLATE_OPTIONS} ) || carp "Can't load Template";
        } else {
          $tt = Template->new || carp "Can't load Template";
        }
        _set_object($frompkg||$self, $tt);
    }
    return $tt;
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
    my $class = ref $self ? ref $self : $self;

    my $tt_config;
    if (ref $self) {
        die "Calling tt_config after the tt object has already been created" if @_ && defined $self->{__TT};
        $tt_config = $self->{__TT_CONFIG} ||= {};
    } else {
        no strict 'refs';
        ${$class.'::__TT_CONFIG'} ||= {};
        $tt_config = ${$class.'::__TT_CONFIG'};
    }

    if (@_) {
      my $props;
      if (ref($_[0]) eq 'HASH') {
          my $rthash = %{$_[0]};
          $props = CGI::Application->_cap_hash($_[0]);
      } else {
          $props = CGI::Application->_cap_hash({ @_ });
      }

      my %options;
      # Check for TEMPLATE_OPTIONS
      if ($props->{TEMPLATE_OPTIONS}) {
          carp "tt_config error:  parameter TEMPLATE_OPTIONS is not a hash reference"
              if Scalar::Util::reftype($props->{TEMPLATE_OPTIONS}) ne 'HASH';
          $tt_config->{TEMPLATE_OPTIONS} = delete $props->{TEMPLATE_OPTIONS};
      }

      # Check for TEMPLATE_NAME_GENERATOR
      if ($props->{TEMPLATE_NAME_GENERATOR}) {
          carp "tt_config error:  parameter TEMPLATE_NAME_GENERATOR is not a subroutine reference"
              if Scalar::Util::reftype($props->{TEMPLATE_NAME_GENERATOR}) ne 'CODE';
          $tt_config->{TEMPLATE_NAME_GENERATOR} = delete $props->{TEMPLATE_NAME_GENERATOR};
      }

      # If there are still entries left in $props then they are invalid
      carp "Invalid option(s) (".join(', ', keys %$props).") passed to tt_config" if %$props;
    }

    $tt_config;
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
    my $vars = shift;
    my $html = '';

    if (! defined($vars) && Scalar::Util::reftype($file) eq 'HASH') {
        $vars = $file;
        $file = $self->tt_template_name;
    }
    $vars ||= {};

    # Call tt_pre_process hook
    $self->tt_pre_process($file, $vars) if $self->can('tt_pre_process');

    # Include any parameters that may have been
    # set with tt_params
    my %params = ( %{ $self->tt_params() }, %$vars );

    $self->tt_obj->process($file, \%params, \$html) || croak $self->tt_obj->error();

    # Call tt_post_process hook
    $self->tt_post_process(\$html) if $self->can('tt_post_process');

    return \$html;
}

##############################################
###
###   tt_include_path
###
##############################################
#
# Change the include path after the template object
# has already been created
#
sub tt_include_path {
    my $self = shift;

    $self->tt_obj->context->load_templates->[0]->include_path(ref($_[0]) ? $_[0] : [@_]);

    return;
}

##############################################
###
###   tt_template_name
###
##############################################
#
# Auto-generate the filename of a template based on
# the current module, and the name of the 
# function that called us.
#
sub tt_template_name {
    my $self = shift;

    my ($tt, $options, $frompkg) = _get_object_or_options($self);

    my $func = $options->{TEMPLATE_NAME_GENERATOR} || \&__tt_template_name;
    return $self->$func;
}

##############################################
###
###   __tt_template_name
###
##############################################
#
# Generate the filename of a template based on
# the current module, and the name of the 
# function that called us.
#
# example:
#   module $self is blessed into:  My::Module
#   function name that called us:  my_function
#
#   generates:  My/Module/my_function.tmpl
#
sub __tt_template_name {
    my $self = shift;

    # the directory is based on the object's package name
    my $dir = File::Spec->catdir(split(/::/, ref($self)));
    #ref($self) =~ /([^:]+)$/;
    #my $dir = $1;

    # the filename is the method name of the caller
    (caller(2))[3] =~ /([^:]+)$/;
    my $name = $1;
    if ($name eq 'tt_process') {
        # we were called from tt_process, so go back once more on the caller stack
        (caller(3))[3] =~ /([^:]+)$/;
        $name = $1;
    }
    return File::Spec->catfile($dir, $name.'.tmpl');
}

##
## Private methods
##
sub _set_object {
    my $self = shift;
    my $tt  = shift;
    my $class = ref $self ? ref $self : $self;

    if (ref $self) {
        $self->{__TT_OBJECT} = $tt;
    } else {
        no strict 'refs';
        ${$class.'::__TT_OBJECT'} = $tt;
    }
}

sub _get_object_or_options {
    my $self = shift;
    my $class = ref $self ? ref $self : $self;

    # Handle the simple case by looking in the object first
    if (ref $self) {
        return ($self->{__TT_OBJECT}, $self->{__TT_CONFIG}) if $self->{__TT_OBJECT};
        return (undef, $self->{__TT_CONFIG}) if $self->{__TT_CONFIG};
    }

    # See if we can find them in the class hierarchy
    #  We look at each of the modules in the @ISA tree, and
    #  their parents as well until we find either a tt
    #  object or a set of configuration parameters
    require Class::ISA;
    foreach my $super ($class, Class::ISA::super_path($class)) {
        no strict 'refs';
        return (${$super.'::__TT_OBJECT'}, ${$super.'::__TT_CONFIG'}, $super) if ${$super.'::__TT_OBJECT'};
        return (undef, ${$super.'::__TT_CONFIG'}, $super) if ${$super.'::__TT_CONFIG'};
    }
    return;
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

This is a simple wrapper around the Template Toolkit process method.  It accepts one or two parameters,
a template filename, and a hashref of template parameters (the template filename is optional, and will
be autogenerated by a call to $self->tt_template_name if not provided).  The return value will be a scalar
reference to the output of the template.

  package My::App::Browser
  sub myrunmode {
    my $self = shift;

    return $self->tt_process( 'Browser/myrunmode.tmpl', { foo => 'bar' } );
  }
 
  sub myrunmode2 {
    my $self = shift;

    return $self->tt_process( { foo => 'bar' } ); # will process template 'My/App/Browser/myrunmode2.tmpl'
  }
 

=head2 tt_config

This method can be used to customize the functionality of the CGI::Application::Plugin::TT module,
and the Template Toolkit module that it wraps.  The recommended place to call C<tt_config>
is in the C<cgiapp_init> stage of L<CGI::Application>.  If this method is called after a
call to tt_process or tt_obj, then it will die with an error message.

It is not a requirement to call this method, as the module will work without any
configuration.  However, most will find it useful to set at least a path to the
location of the template files ( or you can set the path later using the tt_include_path
method).

The following parameters are accepted:

=over 4

=item TEMPLATE_OPTIONS

This allows you to customize how the L<Template> object is created by providing a list of
options that will be passed to the L<Template> constructor.  Please see the documentation
for the L<Template> module for the exact syntax of the parameters, or see below for an example.

=item TEMPLATE_NAME_GENERATOR

This allows you to provide your own method for auto-generating the template filename.  It requires
a reference to a function that will be passed the $self object as it's only parameter.  This function
will be called everytime $self->tt_process is called without providing the filename of the template
to process.  This can standardize the way templates are organized and structured by making the
template filenames follow a predefined pattern.

The default template filename generator uses the current module name, and the name of the calling
function to generate a filename.  This means your templates are named by a combination of the
module name, and the runmode.

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

=head2 tt_template_name

This method will generate a template name for you based on two pieces of information:  the
method name of the caller, and the package name of the caller.  It allows you to consistently
name your templates based on a directory hierarchy and naming scheme defined by the structure
of the code.  This can simplify development and lead to more consistent, readable code.

For example:

 package My::App::Browser

 sub view {
   my $self = shift;

   my $template = $self->tt_template_name; # returns 'My/App/Browser/view.tmpl'
   return $self->tt_process($template, { var1 => param1 });
 }

To simplify things even more, tt_process automatically calls $self->tt_template_name for
you if you do not pass a template name, so the above can be reduced to this:

 package MyApp::Example

 sub view {
   my $self = shift;

   return $self->tt_process({ var1 => param1 }); # process template 'MyApp/Example/view.tmpl'
 }

Since the path is generated based on the name of the module, you could place all of your templates
in the same directory as your perl modules, and then pass @INC as your INCLUDE_PATH parameter.
Whether that is actually a good idea is left up to the reader.

 $self->tt_include_path(\@INC);


=head2 tt_include_path

This method will allow you to set the include path for the Template Toolkit object after
the object has already been created.  Normally you set the INCLUDE_PATH option when creating
the Template Toolkit object, but sometimes it can be useful to change this value after the
object has already been created.  this method will allow you to do that without needing to
create an entirely new Template Toolkit object.  This can be especially handy when using
the Singleton support mentioned below, where a Template Toolkit object may persist across many request.
It is important to note that a call to tt_include_path will change the INCLUDE_PATH for all
subsequent calls to this object, until tt_include_path is called again.  So if you change the
INCLUDE_PATH based on the user that is connecting to your site, then make sure you call
tt_include_path on every request.

  my $root = '/var/www/';
  $self->tt_include_path( [$root.$ENV{SERVER_NAME}, $root.'default'] );


=head1 EXAMPLE

In a CGI::Application module:

  package My::App

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

  sub my_otherrunmode {
    my $self = shift;
 
    my %params = (
            foo => 'bar',
    );
 
    # Since we don't provide the name of the template to tt_process, it
    # will be auto-generated by a call to $self->tt_template_name,
    # which will result in a filename of 'Example/my_otherrunmode.tmpl'.
    return $self->tt_process(\%params);
  }


=head1 SINGLETON SUPPORT

Creating a Template Toolkit object can be an expensive operation if it needs to be done for every
request.  This startup cost increases dramatically as the number of templates you use
increases.  The reason for this is that when TT loads and parses a template, it
generates actual perlcode to do the rendering of that template.  This means that the rendering of
the template is extremely fast, but the initial parsing of the templates can be inefficient.  Even
by using the builting caching mechanism that TT provides only writes the generated perl code to
the filesystem.  The next time a TT object is created, it will need to load these templates from disk,
and eval the sourcecode that they contain.

So to improve the efficiency of Template Toolkit, we should keep the object (and hence all the compiled
templates) in memory across multiple requests.  This means you only get hit with the startup cost
the first time the TT object is created.

All you need to do to use this module as a singleton is to call tt_config as a class method
instead of as an object method.  All the same parameters can be used when calling tt_config
as a class method.

When creating the singleton, the Template Toolkit object will be saved in the namespace of the
module that created it.  The singleton will also be inherited by any subclasses of
this module.  So in effect this is not a traditional Singleton, since an instance of a Template
Toolkit object is only shared by a module and it's children.  This allows you to still have different
configurations for different CGI::Application modules if you require it.  If you want all of your
CGI::Application applications to share the same Template Toolkit object, just create a Base class that
calls tt_config to configure the plugin, and have all of your applications inherit from this Base class.


=head1 SINGLETON EXAMPLE

  package My::App;
  
  use base qw(CGI::Application);
  use CGI::Application::Plugin::TT;
  My::App->tt_config(
              TEMPLATE_OPTIONS => {
                        POST_CHOMP   => 1,
              },
  );
 
  sub cgiapp_prerun {
    my $self = shift;
 
    # Set the INCLUDE_PATH (will change the INCLUDE_PATH for
    # all subsequent requests as well, until tt_include_path is called
    # again)
    my $basedir = '/path/to/template/files/',
    $self->tt_include_path( [$basedir.$ENV{SERVER_NAME}, $basedir.'default'] );
  }
 
  sub my_runmode {
    my $self = shift;

    # Will use the same TT object across multiple request
    return $self->tt_process({ param1 => 'value1' });
  }

  package My::App::Subclass;

  use base qw(My::App);

  sub my_other_runmode {
    my $self = shift;

    # Uses the TT object from the parent class (My::App)
    return $self->tt_process({ param2 => 'value2' });
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

