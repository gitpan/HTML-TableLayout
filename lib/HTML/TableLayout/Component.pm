# ====================================================================
# Copyright (C) 1997 Stephen Farrell <stephen@farrell.org>
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
# CVS $Id: Component.pm,v 1.13 1997/12/12 20:24:52 sfarrell Exp $
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
## insert(): add a component.  NB: insert should always return obj
## reference
##
sub insert { &$NOTER("you didn't override insert()"); return shift }

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
  foreach (@{ $this->{TL_COMPONENTS} }) { &$OOPSER() unless $_;
					  $_->tl_setContext($this);
					  $_->tl_setup() }
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
  $w->f_print($this->{"text"});
  $w->f_print("</FONT");
  
  foreach $m (reverse @{ $this->{markup} }) {
    $w->f_print("></$m");
  }
}


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
  $self->{TL_PARAMS} = \%parameters;
  return $self;
}

sub passCGI {
  my ($this, $cgi, @pass) = @_;
  if (! (ref $cgi eq "HASH")) { &$OOPSER("malformed passcgi") }
  $this->{href} .= "?";
  my @p;
  (@pass) ? (@p = @pass) : (@p = keys %$cgi);
  ## FIXME do encoding!
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
  $this->{TL_WINDOW}->i_print("><!-- " . $this->{"comment"} . " --");
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
  return $self;
}

sub insert {
  my ($this, $component) = @_;
  if (! ref $component) {
    $component = HTML::TableLayout::Component::Text->new($component);
  }
  push @{ $this->{TL_COMPONENTS} }, $component;
  return $this;
}

sub insertLn { return shift->insert(@_) }



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
  my $c;
  foreach $c (@{ $this->{TL_COMPONENTS} }) {
    $this->{delimited} and $w->f_print("><LI");
    $c->tl_print();
  }
  $w->i_print("></$list_denoter");
}



1;
