package POE::Session::YieldCC;

use strict;
use warnings;
use POE;
use Coro::State;

our $VERSION = '0.012';

BEGIN { *TRACE = sub () { 0 } unless defined *TRACE{CODE} }
BEGIN { *LEAK  = sub () { 1 } unless defined *LEAK{CODE} }

our @ISA = qw/POE::Session/;

our $_uniq = 1;
sub _get_uniq { $_uniq++ }

our $main;
our $last_state; # XXX
sub _invoke_state {
  my $self = shift;
  my $args = \@_; # so I can close on the args below

  # delimit the continuation stack
  local $main = Coro::State->new;
  #print ">>main=$main\n";

  my $next;
  $next = Coro::State->new(sub {
    print "  invoking the state $args->[1]\n" if TRACE;
    $self->SUPER::_invoke_state(@$args);
    print "  invoked ok $args->[1]\n" if TRACE;

    # jump out to main, there's no need to save state
    # $next is just discarded when _invoke_state is left

    # FACT: at this point there are no continuations into this state
    # hence we're all done, and everything should be destroyed!

    #my $save = Coro::State->new;
    $last_state = Coro::State->new; # XXX
    register_object($last_state, "last_state") if LEAK;
    $last_state->transfer($main, 0); # XXX

    die "oops shouldn't get here"; # ie you should have discarded $next
  });

  register_object($main, "main") if LEAK;
  register_object($next, "next") if LEAK;

  print "  pre-invoking $args->[1]\n" if TRACE;
  $main->transfer($next, 0);
  print "  post-invoking $args->[1]\n" if TRACE;

  $main = $next = undef;
  if ($last_state) {
    #print "last state!!!\n";
    $last_state = undef;
    #exit;
  }
}

sub yieldCC {
  my ($self, $state, @args) = @_;
  print "yieldCC! to $state\n" if TRACE;

  # this makes a continuation
  my @retval;
  my $save = Coro::State->new;
  $POE::Kernel::poe_kernel->yield(
    $state,
    sub { # the "continuation"
      @retval = @_;
      @_ = ();

      print "continuation invoked\n" if TRACE;
      local $main = Coro::State->new;
      register_object($main, "continuation-main") if LEAK;
      $main->transfer($save, 0);
      $save = undef;
      $last_state = undef; # XXX

      print "continuation finished\n" if TRACE;
    },
    \@args,
  );

  register_object($save, "yieldCC-save") if LEAK;

  # save the current state, and jump back out to main
  print "jumping back out\n" if TRACE;
  $save->transfer($main, 0);

  return wantarray ? @retval : $retval[0];
}

sub sleep {
  my ($self, $delay) = @_;
  # $self == the session

  my $uniq = _get_uniq;

  $poe_kernel->state(__PACKAGE__."::sleep_${uniq}" => \&_before_sleep);
  $poe_kernel->state(__PACKAGE__."::sleep_${uniq}_after" => \&_after_sleep);
  $self->yieldCC(__PACKAGE__."::sleep_${uniq}", $delay);
}

sub _before_sleep {
  my ($cont, $args) = @_[ARG0, ARG1];
  $_[KERNEL]->delay($_[STATE]."_after", $$args[0], $cont, $_[STATE]);
}

sub _after_sleep {
  $_[ARG0]->();
  $_[KERNEL]->state($_[ARG1]);
  $_[KERNEL]->state($_[ARG1] . "_after");
}

use Scalar::Util qw/weaken/;
our @objects;
our %descriptions;
sub register_object {
  my $obj = shift;
  @objects = grep defined($_), @objects;
  push @objects, $obj;
  weaken $_ for @objects;
  my $description = shift;
  $descriptions{$obj} = $description;
  print "REGISTER $obj $description\n" if TRACE;
}
END {
  @objects = grep defined($_), @objects;
  if (@objects) {
    print STDERR scalar(@objects), " objects still exist :-/\n";
    print STDERR "$_ $descriptions{$_}\n" for sort @objects;
    #use Devel::Peek; Dump($_) for sort @objects;
  }
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
      demo_sleep => sub {
	print "I feel rather tired now\n";
	$_[SESSION]->sleep(60);
	print "That was a short nap!\n";
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

THIS MODULE IS EXPERIMENTAL.  And while I'm pretty sure I've squashed all the
memory leaks there may still be some.

=head1 METHODS

=over 2

=item sleep SECONDS

Takes a number of seconds to sleep for (possibly fraction in the same way
that POE::Kernel::delay can take fractional seconds) suspending the current
event and only returning after the time has expired.   POE events continue to
be processed while you're sleeping.

=back

=head1 SEE ALSO

L<POE>, L<POE::Session>, L<Coro::State>

=head1 AUTHOR

Benjamin Smith E<lt>bsmith@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Benjamin Smith

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
