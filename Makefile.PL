use v5.6;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'POE::Session::YieldCC',
    VERSION_FROM      => 'lib/POE/Session/YieldCC.pm',
    PREREQ_PM         => {
      'POE' => 0.30,
      'Coro' => 1.11,
    },
    ABSTRACT_FROM  => 'lib/POE/Session/YieldCC.pm',
    AUTHOR         => 'Benjamin Smith <bsmith@cpan.org>',
);
