use inc::Module::Install;
name 'App-CLI-Plugin-Proc-PID-File';
author 'Akira Horimoto';
all_from 'lib/App/CLI/Plugin/Proc/PID/File.pm';

build_requires 'Test::More';
requires(
      "App::CLI::Extension"   => 1.0,
      "Class::Data::Accessor" => 0,
      "Proc::PID::File"       => 1.27,
    );
use_test_base;
auto_include_deps;
author_tests('xt');
auto_set_repository;
WriteAll;
