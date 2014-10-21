# ====================================================================
# Copyright (C) 1997 Stephen Farrell <stephen@farrell.org>
#
# All rights reserved.  This program is free software; you can
# redistribute it and/or modify it under the same terms as Perl
# itself.
#
# ====================================================================
# File: Form.pm
# Author: Stephen Farrell
# Created: August 1997
# Locations: http://people.healthquiz.com/sfarrell/TableLayout/
# CVS $Id: Form.pm,v 1.15 1997/12/12 20:24:53 sfarrell Exp $
# ====================================================================

## ===================================================================
## This is the Form class itself
## ===================================================================
##
## NB: only cells know how to print forms.  If you have your own
## spiffy componentcontainer that you want to contain a form, you have
## to be very careful (it's best to just stick it into a cell or
## table--which puts it in a cell for you).  If you decide you know
## what you're doing and want to not heed this advice, then know the
## following: You probably do NOT want to make the form be one of
## tl_components, and you must call _print_end().  And maybe some
## other stuff.  Heads up.
##
package HTML::TableLayout::Form;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Form::ISA=qw(HTML::TableLayout::ComponentContainer);
use strict;

sub new {
  my ($class, %params) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS} = \%params;
  $self->{TL_COMPONENTS} = [];
  return $self;
}

sub setMethod { shift->{TL_PARAMS}->{method} = pop }
sub getMethod { return shift->{TL_PARAMS}->{method} }
sub setAction { shift->{TL_PARAMS}->{action} = pop }
sub getAction { return shift->{TL_PARAMS}->{action} }


##
## I think this is the ideal for passCGI... if just a hashref is
## given, then it passes all those values as hidden.  If that is given
## plus a list afterwards, then it fills in the values just for the
## members of the list.  Additionally, if you put an "=" sign in those
## elements of the list, it replaces the value with the one you
## provided (this can also be accomplished by adding "hidden" fields
## to a cell that contains a form.
##

sub passCGI {
  my ($this, $hashref, @pass) = @_;
  
  ##
  ## We want a *copy* of this hashref because we don't want it
  ## changing under our feet
  ##
  
  if ($hashref) {
    my %copy = %$hashref;
    $this->{passcgi} = \ %copy;
  }
  scalar(@pass) and $this->{passlist} = \@pass;
  return $this;
}

##
## NB: We just get a reference, not a copy.  No guarantees that your
## original will not get trampled!  In my code, I take care to use
## exists to check if keys exist in the hash...
##
sub useData {
  my ($this, $data) = @_;
  $this->{default_data} = $data;
  return $this;
}


##
## NB: One must be careful when using this insert.  Normally it is
## AUTOMAGICALLY called when you insert an object into a cell or
## table.  HOWEVER, you CAN choose to insert hidden items directly
## into the form.  The deal is that form won't call tl_print() on the
## object, so if it doesn't need tl_print() to be called (such as
## hidden) then it's ok to insert only into the form.  I think you'll
## agree this actually makes a kind of sense....
##
sub insert {
  my ($this, $c) = @_;
  if ($c->_isa("HTML::TableLayout::FormComponent::Hidden")) {
    if ($this->{passlist}) {
      
      ##
      ## Note we don't check if it is already on the passlist
      ## this doesn't matter too much because it'll just show up
      ## twice and both times it'll have the same value--but it'll
      ## still cause problems!
      ##
      
      push @{ $this->{passlist} }, $c->tl_getName();
    }
    $this->{passcgi}->{$c->tl_getName()} =
      $c->tl_getValue() || $this->{default_data}->{$c->tl_getName()};
  }
  else {
    
    ##
    ## Note it is not deleted off the passlist--this is your own dang
    ## problem if you insert things AND add them to the passlist
    ##
    
    delete $this->{passcgi}->{$c->tl_getName()};
  }
  push @{ $this->{TL_COMPONENTS} }, $c;
}


sub tl_print {
  my ($this) = @_;
  my $w = $this->{TL_WINDOW};
  $w->i_print("><FORM".params($this->tl_getParameters())."");
}

sub _print_end {
  my ($this) = @_;
  my $w = $this->{TL_WINDOW};
  my @pass;
  if ($this->{passlist}) {
    @pass = @{ $this->{passlist} };
  }
  else {
    @pass = keys %{ $this->{passcgi} };
  }
  my $k;
  foreach $k (@pass) {
    my $v;
    if ($k =~ s/=(.*)//) {
      $v = $1;
    }
    else {
      $v = $this->{passcgi}->{$k};
    }
    $w->i_print("><INPUT TYPE=HIDDEN NAME=\"$k\" VALUE=\"$v\"");
  }
  $w->i_print("></FORM");
}


sub _getDefaultData { return shift->{default_data} }


##
## FIXME: this is NOT a full implementation of clone for this class!!!
##
sub clone {
  my ($this) = @_;
  my $class;
  my $clone = HTML::TableLayout::Form->new();
  my %passcgi_copy = %{ $this->{passcgi} };
  my %params_copy = %{ $this->{TL_PARAMS} };
  $clone->{passcgi} = \%passcgi_copy;
  $clone->{TL_PARAMS} = \%params_copy;
  return $clone;
}


##
## ====================================================================
## These are the form components
## ====================================================================
##
package HTML::TableLayout::FormComponent;
@HTML::TableLayout::FormComponent::ISA=qw(HTML::TableLayout::Component);
use HTML::TableLayout::Symbols;


sub tl_getName { return shift->{TL_PARAMS}->{name} }
sub tl_setName { shift->{TL_PARAMS}->{name} = pop }
sub tl_getValue { return shift->{TL_PARAMS}->{value} }
sub tl_setValue { shift->{TL_PARAMS}->{value} = pop }

sub tl_setDefaultValue {
  my ($this) = @_;
  return if $this->{TL_PARAMS}->{value};
  &$OOPSER("No form (BUG!) [$this]") unless $this->{TL_FORM};
  my $data_hash = $this->{TL_FORM}->_getDefaultData();
  return unless exists $data_hash->{$this->{TL_PARAMS}->{name}};
  my $v;
  if ($v = $data_hash->{$this->{TL_PARAMS}->{name}}) {
    $this->{TL_PARAMS}->{value} = $v;
  }
}


sub tl_setup {
  my ($this) = @_;
  $this->SUPER::tl_setup();
  $this->tl_setDefaultValue();
}


# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponent::Hidden;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::FormComponent::Hidden::ISA=
  qw(HTML::TableLayout::FormComponent);
sub new {
  my ($class, $name, $value, $visible) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS}->{name} = $name;
  $self->{TL_PARAMS}->{value} = $value;
  $self->{visible} = $visible;
  return $self;
}

##
## Everything about hidden is handled by the Form itself, using the
## "passcgi" mechanism.
##

sub tl_print {
  my ($this) = @_;
  if ($this->{visible}) {
    ##
    ## This is kind of funky, but a "visible" hidden entry displays the
    ## value as plain text.
    ##
    $this->{TL_WINDOW}->i_print($this->{TL_PARAMS}->{value});
  }
}

# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponent::Faux;
@HTML::TableLayout::FormComponent::Faux::ISA=
  qw(HTML::TableLayout::FormComponent);

##
## This behaves like a form component, but it just prints the text
## value; it does not do any other form-like things such as *passing
## it's value*.  Use a "visible" Hidden if you want to do this.
##
sub new {
  my ($class, $name, $value) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS}->{name} = $name;
  $self->{TL_PARAMS}->{value} = $value;
  return $self;
}

sub tl_print {
  my ($this) = @_;
  $this->{TL_WINDOW}->i_print($this->{TL_PARAMS}->{value});
}


# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponent::InputText;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::FormComponent::InputText::ISA=
  qw(HTML::TableLayout::FormComponent);

sub tl_print {
  my ($this) = @_;
  $this->{TL_WINDOW}
  ->i_print("><INPUT TYPE=TEXT".params(%{ $this->{TL_PARAMS} })."");
}

# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponent::Button;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::FormComponent::Button::ISA=
  qw(HTML::TableLayout::FormComponent);

sub tl_print {
  my ($this) = @_;
  $this->{TL_WINDOW}
  ->i_print("><INPUT TYPE=BUTTON".params(%{ $this->{TL_PARAMS} })."");
}

# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponent::Checkbox;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::FormComponent::Checkbox::ISA=
  qw(HTML::TableLayout::FormComponent);


sub tl_print {
  my ($this) = @_;
  $this->{TL_WINDOW}
  ->i_print("><INPUT TYPE=CHECKBOX".params(%{ $this->{TL_PARAMS} })."");
}


sub tl_setDefaultValue {
  my ($this) = @_;
  return if exists $this->{TL_PARAMS}->{checked};
  &$OOPSER("No form (BUG!) [$this]") unless $this->{TL_FORM};
  my $data_hash = $this->{TL_FORM}->_getDefaultData();
  return unless exists $data_hash->{$this->{TL_PARAMS}->{name}};
  if (exists $data_hash->{$this->{TL_PARAMS}->{name}}) {
    $this->{TL_PARAMS}->{checked} = undef;
  }
}


# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponent::Textarea;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::FormComponent::Textarea::ISA=
  qw(HTML::TableLayout::FormComponent);

sub new {
  my ($class, $value, %params) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS} = \%params;
  $self->{TL_PARAMS}->{value} = $value;
  return $self;
}

sub tl_print {
  my ($this) = @_;
  my $w =  $this->{TL_WINDOW};
  $w->i_print("><TEXTAREA".params(%{ $this->{TL_PARAMS} })."");
  $w->f_print($this->{TL_PARAMS}->{value});
  $w->i_print("></TEXTAREA");
}


# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponent::Password;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::FormComponent::Password::ISA=
  qw(HTML::TableLayout::FormComponent);

sub tl_print {
  my ($this) = @_;
  $this->{TL_WINDOW}
  ->i_print("><INPUT TYPE=PASSWORD".params(%{ $this->{TL_PARAMS} })."");
}


# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponent::Submit;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::FormComponent::Submit::ISA=
  qw(HTML::TableLayout::FormComponent);


## 99/100 times, you'll just be passing in the value here
sub new {
  my ($class, $value, %params) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS} = \%params;
  defined $value and $self->{TL_PARAMS}->{value} = $value;
  return $self;
}

##
## I override this b/c chances are, if the value changes, it'll not be
## what was expected.
##
sub tl_setDefaultValue { }
sub tl_print {
  my ($this) = @_;
  &$OOPSER($this->{TL_PARAMS}->{value}) unless $this->{TL_WINDOW};
  $this->{TL_WINDOW}
  ->i_print("><INPUT TYPE=SUBMIT".params(%{ $this->{TL_PARAMS} })."");
}

# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponentMulti;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::FormComponentMulti::ISA =
  qw(HTML::TableLayout::FormComponent);


sub new {
  my ($class, $ops, %params) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS} = \%params;
  $self->{TL_OPS} = $ops;
  return $self;
}

sub tl_setDefaultValue {
  my ($this) = @_;
  my $data_hash = $this->{TL_FORM}->_getDefaultData();
  return unless exists $data_hash->{$this->{TL_PARAMS}->{name}};
  $this->{TL_DEFAULT_VALUE} = $data_hash->{$this->{TL_PARAMS}->{name}};
}

# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponent::Radio;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::FormComponent::Radio::ISA=
  qw(HTML::TableLayout::FormComponentMulti);

sub tl_print {
  my ($this) = @_;
  my $r;
  my $w = $this->{TL_WINDOW};
  foreach $r (@{ $this->{TL_OPS} }) {
    my %params = %{ $this->{TL_PARAMS} };
    $params{value} = $r->[0];
    $w->i_print("><INPUT TYPE=RADIO".params(%params));
    if ($r->[0] eq $this->{TL_DEFAULT_VALUE}) {
      $w->f_print(" CHECKED");
    }
    $w->f_print(">$r->[1]");
  }
}

# ---------------------------------------------------------------------
package HTML::TableLayout::FormComponent::Choice;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::FormComponent::Choice::ISA=
  qw(HTML::TableLayout::FormComponentMulti);

sub tl_print {
  my ($this) = @_;
  my $w = $this->{TL_WINDOW};
  $w->i_print("><SELECT".params(%{ $this->{TL_PARAMS} }). "");
  $w->_indentIncrement();
  my $o;
  foreach $o (@{ $this->{TL_OPS} }) {
    if (! (ref $o eq "ARRAY")) { &$OOPSER("malformed options") }
    $w->i_print("><OPTION VALUE=\"$o->[0]\"");
    if ($o->[0] eq $this->{TL_DEFAULT_VALUE}) {
      $w->f_print(" SELECTED");
    }
    $w->f_print(">$o->[1]");
  }
  $w->_indentDecrement();
  $w->i_print("></SELECT");
}


1;
