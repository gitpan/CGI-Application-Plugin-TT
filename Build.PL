use Module::Build;

Module::Build->new(
    module_name => 'CGI::Application::Plugin::TT',
    license => 'perl',
    requires => {
        'CGI::Application' => 3.0,
        'Template' => '2.0'
    },
    create_makefile_pl => 'traditional',
    create_readme => 1,
    dist_author => 'Cees Hek <cees@crtconsulting.ca>',
    dist_abstract => 'Plugin that adds Template Toolkit support to CGI::Application',
)->create_build_script;

