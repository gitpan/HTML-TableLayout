# ====================================================================
# Copyright (C) 1997,1998 Stephen Farrell <stephen@farrell.org>
#
# All rights reserved.  This program is free software; you can
# redistribute it and/or modify it under the same terms as Perl
# itself.
#
# ====================================================================
# File: Component.pm
# Author: Stephen Farrell
# Created: August, 1997
# Locations: http://people.healthquiz.com/sfarrell/TableLayout/
# CVS $Id: Component.pm,v 1.14 1998/04/16 16:09:51 sfarrell Exp $
# ====================================================================


##
## This class is very virtual
##
package HTML::TableLayout::Component;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Component::ISA=qw(HTML::TableLayout::TL_BASE);
use strict;

##
## Default constructor
##
sub new {
  my ($class, %params) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS} = \ %params;
  return $self;
}

##
## tl_setContext(): Sets the context in the heirarchy when packing and
## displaying. This is done "late"
##
sub tl_setContext {
  my ($this, $container) = @_;
  
  my $window = $container->{TL_WINDOW};
  my $form = $container->{TL_FORM};
  
  
  ## ====================================================================
  ##
  ## DEBUGGING 
  ##
  
  unless ($container) { &$OOPSER("container is null") }
  unless ($window) { &$OOPSER("window is null [$container]") }
  
  ##
  ## it's ok for the form to be null, but if it is, we don't want to
  ## clobber an existing value for it.
  ##
  ## ====================================================================
  
  defined $container and $this->{TL_CONTAINER} = $container;
  defined $window and $this->{TL_WINDOW} = $window;
  defined $form and $this->{TL_FORM} = $form;
}

##
## tl_getContainer(),tl_getWindow(),tl_getForm(): Accessors for the
## above--notethat these might not be used much b/c we know the name
## of the data very well.
##
sub tl_getContainer { return shift->{TL_CONTAINER} }
sub tl_getWindow { return shift->{TL_WINDOW} }
sub tl_getForm { return shift->{TL_FORM} }


##
## tl_setup(): is called just before printing, and is meant to provide
## "late" packing and searching for requirements in containers (like
## looking for a Form).  Actually, it's called everywhere before
## anything prints, so if you want to play with values in your
## neighboring components, have fun.
##
## If you override this, you must call your super's version.  (like
## $this->SUPER::tl_setup()). ok ok I'm lying right now b/c as you can
## see, there is nothing here so obviously you don't HAVE to call it.
## but I might add something later.  Also, if your parent is a
## componentcontainer, then you MUST call it (or do equivalent and
## keep your fingers crossed for future versions).
##
sub tl_setup {  }


##
## tl_print(): uses i_print() and f_print() to display object.
##
sub tl_print {  }


##
## tl_breakAfter(): The component has a break "<BR>" after it.  This
## doesn't happen automatically--the component printing it needs to
## check if it is there and print it itself.
##

sub tl_breakAfter { return shift->{TL_BREAK_AFTER} }

# ---------------------------------------------------------------------

##
## This class is very virtual as well
##
package HTML::TableLayout::ComponentContainer;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::ComponentContainer::ISA=qw(HTML::TableLayout::Component);

sub new {
  my ($class, %params) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS} = \%params;
  
  ##
  ## Add TL_COMPONENTS--this will be used in all subclasses...
  ##
  
  $self->{TL_COMPONENTS} = [];
  return $self;
}

##
## insert(): add a component.  subclasses should always call this,
## like tl_setup()
##
sub insert { 
  my ($this, $obj) = @_;
  &$OOPSER("null insert") unless defined $obj;
  push @{ $this->{TL_COMPONENTS} }, $obj;
  return $this;
}

##
## insertLn(): add a component w/ <BR> afterwards.  Generally I've
## handled this as a wrapper method that calls insert with a second
## argument of "1".
##
sub insertLn { return shift->insert(shift,1) }


##
## tl_setup(): if you choose to override this method, then you must do
## what is done here, or call $this->SUPER::tl_setup().  Of course, if
## you replicate this method's functionality, you should be aware that
## in the future this function might change, and you might need to
## update your equivalent functionality in the future....  (yes, I'm
## scrounging for hints on OO design!)
##
sub tl_setup {
  my ($this) = @_;
  $this->SUPER::tl_setup(); 
  foreach (@{ $this->{TL_COMPONENTS} }) { &$OOPSER("null comp.") unless $_;
					  $_->tl_setContext($this);
					  $_->tl_setup() }
} 



##
## this makes a ComponentContainer an implementable object--and a very
## useful one at that.  YOu can just stick stuff in it and it'll print
## the various things with no added overhead.
##
sub tl_print {
  my ($this) = @_;
  foreach(@{ $this->{TL_COMPONENTS} }) { $_->tl_print() }
}

# ---------------------------------------------------------------------
## clearly this is not what I meant... FIXME!
package HTML::TableLayout::ComponentCell;
@HTML::TableLayout::ComponentCell::ISA=qw(HTML::TableLayout::Cell);

# ---------------------------------------------------------------------

package HTML::TableLayout::ComponentTable;
@HTML::TableLayout::ComponentTable::ISA=qw(HTML::TableLayout::Table);


# ---------------------------------------------------------------------

package HTML::TableLayout::Component::Text;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Component::Text::ISA=qw(HTML::TableLayout::Component);

my %MARKUP = (bold =>	"B",
	      italic => "I",
	      big =>	"BIG",
	      small =>	"SMALL");


sub new {
  my ($class, $text, %parameters) = @_;
  my $self = {};
  bless $self, $class;
  $self->{"text"} = $text;
  $self->{TL_PARAMS} = \%parameters;
  return $self;
}


sub tl_getParameters {
  my ($this) = @_;
  &$OOPSER() unless $this->{TL_WINDOW};
  my %parameters = ($this->{TL_WINDOW}->{PARAMETERS}->get($this),
		    %{ $this->{TL_PARAMS} });
  foreach("italic","bold", "big", "small") {
    if (exists $parameters{$_}) {
      delete $parameters{$_};
      push @{ $this->{markup} }, $MARKUP{$_};
    }
  }
  return (%parameters);
}

sub tl_print {
  my ($this,%ops) = @_;
  my $w = $this->{TL_WINDOW};
  my %p = $this->tl_getParameters();
  $w->i_print();
  my $m;
  foreach $m (@{ $this->{markup} }) {
    $w->f_print("><$m");
  }
  
  $w->f_print("><FONT".params(%p).">");
  if ($this->{tl_do_not_pad}) {
    $w->f_print($this->{"text"});
  }
  else {
    $w->f_print(" " . $this->{"text"} . " "); 
  }
  $w->f_print("</FONT");
  
  foreach $m (reverse @{ $this->{markup} }) {
    $w->f_print("></$m");
  }
}

##
## Yuck.  Padding of text is a messy issue after moving to the ><
## style tagging... the problem is that if we don't pad, the text is
## glued together unexpectedly.  if i do pad, then links look bad.
## This function is here so a link can tell it's text components not
## to pad.
##
sub tl_do_not_pad { shift->{tl_do_not_pad} = 1 }

# ---------------------------------------------------------------------

package HTML::TableLayout::Component::Image;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Component::Image::ISA=qw(HTML::TableLayout::Component);

sub new {
  my ($class, $url, %parameters) = @_;
  my $self = {};
  bless $self, $class;
  $self->{url} = $url;
  $self->{TL_PARAMS} = \%parameters;
  return $self;
}

sub tl_print {
  my ($this, %ops) = @_;
  my $w = $this->{TL_WINDOW};
  my $p = params($this->tl_getParameters()) || "";
  $w->i_print(qq{><IMG SRC="$this->{url}" $p});
}

# ---------------------------------------------------------------------

package HTML::TableLayout::Component::Link;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Component::Link::ISA
  =qw(HTML::TableLayout::ComponentContainer);

sub new {
  my ($class, $href, $anchor, %parameters) = @_;
  my $self = {};
  bless $self, $class;
  $self->{href} = $href;
  if (ref $anchor) {
    $self->{TL_COMPONENTS}->[0] = $anchor;
  }
  else {
    $self->{TL_COMPONENTS}->[0]
      = HTML::TableLayout::Component::Text->new($anchor);
  }
  if ($self->{TL_COMPONENTS}->[0]->_isa("HTML::TableLayout::Component::Text")) {
    ##
    ## see comment for tl_do_not_pad() method of Text
    ##
    $self->{TL_COMPONENTS}->[0]->tl_do_not_pad();
  }
  $self->{TL_PARAMS} = \%parameters;
  return $self;
}

sub passCGI {
  my ($this, $cgi, @pass) = @_;
  if (! (ref $cgi eq "HASH")) { &$OOPSER("malformed passcgi") }
  $this->{href} .= "?";
  my @p;
  (@pass) ? (@p = @pass) : (@p = keys %$cgi);
  ##
  ## FIXME do encoding!
  ##
  foreach (@p) {
    if (/=/) {
      $this->{href} .= $_ . "&";
    }
    else {
      $this->{href} .= $_ . "=" . $cgi->{$_} . "&";
    }
  }
  return $this;
}


sub tl_print {
  my ($this, %ops) = @_;
  
  my $w = $this->{TL_WINDOW};
  my $p = params($this->tl_getParameters()) || "";
  $w->i_print(qq{><A HREF="$this->{href}" $p});
  $this->{TL_COMPONENTS}->[0]->tl_print();
  $w->f_print("></A");
}

# ---------------------------------------------------------------------

package HTML::TableLayout::Component::Preformat;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Component::Preformat::ISA=
  qw(HTML::TableLayout::Component);

sub new {
  my ($class, $pre) = @_;
  my $self = {};
  bless $self, $class;
  $self->{"pre"} = $pre;
  return $self;
}

sub tl_print {
  my ($this) = @_;
  my $w = $this->{TL_WINDOW};
  $w->i_print("><PRE");
  $w->f_print($this->{"pre"}."");
  $w->i_print("></PRE");
}
# ---------------------------------------------------------------------

package HTML::TableLayout::Component::Comment;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Component::Comment::ISA=
  qw(HTML::TableLayout::Component);

sub new {
  my ($class, $comment) = @_;
  my $self = {};
  bless $self, $class;
  $self->{"comment"} = $comment;
  return $self;
}

sub tl_print {
  my ($this) = @_;
  ##
  ## This is a pretty ugly hack--note fake tag "<x>"
  ##
  $this->{TL_WINDOW}->i_print("><!-- " . $this->{"comment"} . " --><x");
}

# ---------------------------------------------------------------------

package HTML::TableLayout::Component::HorizontalRule;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Component::HorizontalRule::ISA=
  qw(HTML::TableLayout::Component);

sub tl_print {
  my ($this) = @_;
  $this->{TL_WINDOW}->i_print("><HR".params($this->tl_getParameters())."");
} 

# ---------------------------------------------------------------------

package HTML::TableLayout::Component::List;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Component::List::ISA=
  qw(HTML::TableLayout::ComponentContainer);

sub new {
  my ($class, $numbered, $delimited) = @_;
  my $self = {};
  bless $self, $class;
  $self->{numbered} = $numbered;
  $self->{delimited} = $delimited;
  $self->{TL_COMPONENTS} = [];
  $self->{TL_BREAKS} = [];
  return $self;
}

sub insert {
  my ($this, $component, $br) = @_;
  if (! ref $component) {
    $component = HTML::TableLayout::Component::Text->new($component);
  }

  push @{ $this->{TL_BREAKS} }, $br;

  $this->SUPER::insert($component);
}



sub tl_print {
  my ($this) = @_;
  
  my $w = $this->{TL_WINDOW};
  my $list_denoter;
  if ($this->{numbered}) {
    $list_denoter = "OL";
  }
  else {
    $list_denoter = "UL";
  }
  $w->i_print("><$list_denoter");
  my $i;
  foreach $i (0..$#{ $this->{TL_COMPONENTS} }) {
    my $c = $this->{TL_COMPONENTS}->[$i];

    if ($this->{delimited} and
	! $c->_isa("HTML::TableLayout::Component::List")) {
      $w->f_print("><LI");
    }

    $w->_indentIncrement();
    $c->tl_print();
    $w->_indentDecrement();

    ## do this if the component is a list??
    $this->{TL_BREAKS}->[$i] and $w->f_print("><BR");
  }
  $w->i_print("></$list_denoter");
}



1;
