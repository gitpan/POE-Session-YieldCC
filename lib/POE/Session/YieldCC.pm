package POE::Session::YieldCC;

use strict;
use warnings;
use POE;
use Coro::State;

our $VERSION = '0.01';

BEGIN { *TRACE = sub () { 0 } unless defined *TRACE{CODE} }

our @ISA = qw/POE::Session/;

our $main;
sub _invoke_state {
  my $self = shift;
  my @args = @_; # so I can close on the args below

  my $next;
  $next = Coro::State->new(sub {
    print "  invoking the state $args[1]\n" if TRACE;
    $self->SUPER::_invoke_state(@args);
    print "  invoked ok $args[1]\n" if TRACE;
    # exit cleanly
    $next->transfer($main, 0);

    die "oops shouldn't get here";
  });

  print "  pre-invoking $args[1]\n" if TRACE;
  local $main = Coro::State->new;
  $main->transfer($next, 0);
  print "  post-invoking $args[1]\n" if TRACE;

  #Coro::State::flush();
}

sub yieldCC {
  my ($self, $state, @args) = @_;
  print "yieldCC! to $state\n" if TRACE;

  my @retval;
  my $save = Coro::State->new;
  $POE::Kernel::poe_kernel->yield(
    $state,
    sub { # the "continuation"
      @retval = @_;

      print "continuation invoked\n" if TRACE;
      local $main = Coro::State->new;
      $main->transfer($save, 0);
    },
    \@args,
  );

  print "jumping back out\n" if TRACE;
  $save->transfer($main, 0);

  return wantarray ? @retval : $retval[0];
}

1;

__END__

=head1 NAME

POE::Session::YieldCC - POE::Session extension for using continuations

=head1 SYNOPSIS

  use POE::Session::YieldCC;

  POE::Session::YieldCC->create(
    inline_states => {
      handler => sub {
	print "before\n";
	my $val = $_[SESSION]->yieldCC('do_async', 123);
	print "after: $val\n";
      },
      do_async => sub {
        my ($cont, $args) = @_[ARG0, ARG1];
        # do something synchronously, passing $cont about
        # when we're ready:
	$cont->("value");
      },
    },
  );
  $poe_kernel->run();

=head1 DESCRIPTION

POE::Session::YieldCC extends POE::Session to allow "continuations".  A new
method on the session object, C<yieldCC> is introduced.

C<yieldCC> takes as arguments a state name (in the current session) and
a list of arguments.  Control is yield to that state (via POE::Session->yield)
passing a "continuation" as ARG0 and the arguments as an array reference in
ARG1.  C<yieldCC> does B<not> return immediately.

The "continuation" is a anonymous subroutine that when invoked passes control
back to where C<yieldCC> was called returning any arguments to the continuation
from the C<yieldCC>.  Once the original state that called yieldCC finishes
control returns to where the continuation was invoked.

Examples can be found in the examples/ directory of the distribution.

THIS MODULE IS EXPERIMENTAL.  This means that I wouldn't be surprised if you
encountered segfaults, plagues, weird POE errors, memory leaks or other
unexpected behaviour.

=head1 SEE ALSO

L<POE>, L<POE::Session>, L<Coro::State>

=head1 AUTHOR

Benjamin Smith, E<lt>bsmith@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Benjamin Smith

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
