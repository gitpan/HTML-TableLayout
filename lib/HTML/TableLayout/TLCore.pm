# ====================================================================
# Copyright (C) 1997 Stephen Farrell <stephen@farrell.org>
#
# All rights reserved.  This program is free software; you can
# redistribute it and/or modify it under the same terms as Perl
# itself.
#
# ====================================================================
# File: TLCore.pm
# Author: Stephen Farrell
# Created: August 1997
# Locations: http://people.healthquiz.com/sfarrell/TableLayout/
# CVS $Id: TLCore.pm,v 1.20 1997/12/12 20:23:45 sfarrell Exp $
# ====================================================================
#
# [someone please shoot me if I'm using some OO terminology
# wrong... one of my plans is to hit some books before I make some of
# the upcoming changes, esp. wrt constructors]
#
# A note on method names: I've tried to categorize methods as one of
# the following:
#
#	1. public & obligatory--there are precious few of these.
#	   new() (which is called implicitely anyway) and insert()
#	   come to mind.  One might think of the base classes like
#	   Component and ComponentContainer as being virtual (or as
#	   being Interfaces in the Java sense)--this is the sense in
#	   which I mean "obligatory"--these are not prefixed.
#
#	2. protected & obligatory--these include tl_setContext() and
#	   pretty much anything previxed with "tl_".  These should be
#	   called only by "widgets" and internally.
#
#	3. public--these are additional methods like passCGI() which
#	   are expected to be used externally but are not part of the
#	   Component system--not prefixed.
#
#	4. protected--these are part of the specific implemention of
#	   the different objects.  CORE tablelayout classes are
#	   supposed to know about these methods; perhaps some
#	   components might need to use these, but they should
#	   *by no means* be used by the user when making
#	   layouts--these are prefixed by "_".
#
# Some classes are protected ("_Row", "_Anchor" e.g.)  These have
# unprefixed method names, but that's assumed ok b/c outside world
# shouldn't know the classes exist in the first place.
# ====================================================================
# A note on class heirarchy: You'll notice that there are many things
# in this file that are derived from "Component", but do not have
# "Component" in their name (like HTML::TableLayout::Component::Text
# does).  Thus we have a distinction between Components and things
# derived from components (icky, I know).  CORE classes have unusual
# behavior and are critical to the grand scheme of things--esp. wrt
# layout.  Some of these just happen to also benefit from deriving
# from Component or ComponentContainer.  Regular old components have
# no fancy behavior wrt layout.
# ====================================================================

## TODO:
## 1. When add something like a hidden form component into a table,
##    make sure it doesn't add an (extraneous) new cell for it.
## 2. Way to tell passcgi to NOT pass a certain key; similarly way to
##    blow-away a parameter.  By the same token; wrt default
##    parameters, it should be possible to inheret parameters from a
##    given labeled class, and then add some of your own, blow some
##    away, and so on.
## 5. obj2tag should also take a tag in case some people make objects
##    that are expensive to create
## 6. add clone() to the (full) API
## 7. make it so that Anchor and align collide in tl_getParameters()
##    so that you can't have both inadvertantly.
## 8. i have a feeling someone is going to tell me that my
##    constructors suck and need to be rewritten (doh! I spoke too
##    soon; someone already has!)
## 
##
## Done (since last release):
## Hu7uBo
##
package HTML::TableLayout::TLCore;
package HTML::TableLayout::TL_BASE;

use HTML::TableLayout::Symbols;
use strict;

##
## This _isa is here to support perls from before isa() was added to
## UNIVERSAL.pm.  It turns out that isa() is *much* faster than my
## _isa()--presumably the eval() is very slow.  I'd like to do away
## with this _isa() function, but would like to retain backwards
## compatibility.  Would be a job for a preprocessor in C--any way to
## achieve this in perl?
##
## NOTE 97/12/07 15:32:43 sfarrell --I'm aware of the preprocessor
## mode for perl and am considering adding functionality to the
## makefile to replace _isa() with isa() for perls that support
## it--comments??
sub _isa {
  my ($this, $classname) = @_;
  
  ##
  ## This is currently how I handle the native isa() in new perls...
  ##
  if ($] > 5.003) {
    return $this->isa($classname);
  }
  
  my $pkg = ref $this || $this;
  return $pkg if $classname eq undef;
  return 1 if $classname eq $pkg;
  my $pkg_syms = eval "\\%$pkg\::";
  return undef unless exists $pkg_syms->{ISA} and defined @{$pkg_syms->{ISA}};
  foreach (@{ $pkg_syms->{ISA} }) {
    $_->_isa($classname) and return 1;
  }
  return undef;
}

##
## tl_getParameters(): this is used internally to generate the
## parameters list.  It combines the parameters set as global with
## those entered with the constructor for this object.  Note that
## tl_getParameters needs to be called "late" (like in tl_setup(), but
## not in insert()).
##
## You'll find you need to override this when you have "fake"
## parameters you're injecting (look at
## HTML::TableLayout::Component::Text for an example)
##
sub tl_getParameters {
  my ($this) = @_;
  
  &$OOPSER("NO WINDOW") unless $this->{TL_WINDOW};
  
  my %gp = $this->{TL_WINDOW}->{PARAMETERS}->get($this);
  if ($this->{TL_PARAMS}) {
    my %h = (%gp, %{ $this->{TL_PARAMS} });
    return %h;
  }
  else {
    return %gp;
  }
}


##
## tl_getLocalParameters(): This gets you a reference, so you can
## delete, insert, hang yourself, etc.
##
sub tl_getLocalParameters { return shift->{TL_PARAMS} }


##
## tl_inheritParamsFrom(): This is here for widgets to be able to
## inherit default properties from whatever they wish.  For example,
## if you make a widget that derives from Cell, you might want to make
## it get the default parameters for cell as well.  Just call
## tl_inheritParamsFrom(cell()) "early" and that'll happen for you.
##
## Warning: this method might go away in a future release.
sub tl_inheritParamsFrom {
  my ($this, $obj) = @_;
  $this->{TL_PARAMS_ISA} = $obj;
}

## --------------------------------------------------------------------
##
## Parameters package--this handles the default parameters
##
package HTML::TableLayout::Parameters;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Parameters::ISA=qw(HTML::TableLayout::TL_BASE);


sub new {
  my ($class) = @_;
  my $self = {};
  bless $self, $class;
  $self->{DATA} = {};
  return $self;
}


##
## FAST & destructive
##
sub set {
  my ($this, $obj, %hash) = @_;
  $this->{DATA}->{$this->_obj2tag($obj)} = \%hash;
}

##
## SLOW & non-destructive
##
sub insert {
  my ($this, $obj, %hash) = @_;
  foreach (keys %hash) {
    $this->{DATA}->{$this->_obj2tag($obj)}->{$_} = $hash{$_};
  }
}

sub delete {
  my ($this, @keys) = @_;
  map { delete $this->{DATA}->{$_} } @keys;
}

sub get {
  my ($this, $obj) = @_;
  my $h = $this->{DATA}->{$this->_obj2tag($obj)};
  
  if ($h) {
    return %$h;
  }
  else {
    return ();
  }
}

##
## This is here b/c when you create new widgets yourself, they can
## take advantage of the default parameters system without having to
## add any code yourself to the widget to handle this specifically.
## In order to do this, the way it relates defaults with classes is by
## being given an instance of the class, and then it "recognizes" that
## class in the future.
##
sub _obj2tag {
  my ($this, $obj) = @_;
  
  ##
  ## when you make a widget, you might want to be able to inheret the
  ## params as if you were the same kind of hting.  You can call
  ## $this->tl_inheritParamsFrom(constructor) and you're set.
  ##
  my $name = $obj->{TL_PARAMS_ISA} || $obj;
  
  my $tag;
  ##
  ## _obj2tag() is called a lot, so this regexp is a bit expensive...
  ##
  ($tag = $name) =~ s/^([\w:]+)=.*/$1/;
  return $tag;
}



# ---------------------------------------------------------------------

package HTML::TableLayout::_Anchor;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::_Anchor::ISA=qw(HTML::TableLayout::TL_BASE);


sub new {
  my ($class, $anchor) = @_;
  my $self = {};
  bless $self, $class;
  $self->{anchor} = $anchor;
  return $self;
}

sub value {
  my ($this) = @_;
 SWITCH: {
    my $case = $this->{anchor} || return ();
    ($case eq "top") and return (valign=>"top");
    ($case eq "right") and return (align=>"right");
    ($case eq "bottom") and return (valign=>"bottom");
    ($case eq "left") and return (align=>"left");
    ($case eq "center") and return (align=>"center",valign=>"middle");
    ($case eq "north"
     or $case eq "n") and return (align=>"center",valign=>"top");
    ($case eq "east"
     or $case eq "e") and return (align=>"right",valign=>"center");
    ($case eq "south"
     or $case eq "s") and return (align=>"center",valign=>"bottom");
    ($case eq "west"
     or $case eq "w") and return (align=>"left",valign=>"center");
    ($case eq "ne") and return (align=>"right",valign=>"top");
    ($case eq "se") and return (align=>"right",valign=>"bottom");
    ($case eq "sw") and return (align=>"left",valign=>"bottom");
    ($case eq "nw") and return (align=>"left",valign=>"top");
    &$OOPSER("unknown anchor \"$case\"");
  }
}

# ---------------------------------------------------------------------


package HTML::TableLayout::Window;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Window::ISA=qw(HTML::TableLayout::ComponentContainer);


sub new {
  my ($class, $def_params, $title, %params) = @_;
  my $self = {};
  bless $self, $class;
  $self->{title} = $title;
  $self->{TL_PARAMS} = \%params;
  defined $params{cacheable} and $self->{CACHEABLE} = 1;
  if ($def_params) {
    $self->{PARAMETERS} = $def_params;
  }
  else {
    ##
    ## you can pass in null parameters and everything will behave
    ## properly, but just defaults
    ##
    $self->{PARAMETERS} = HTML::TableLayout::Parameters->new();
  }
  $self->{headers} = [];
  $self->{tables} = [];
  $self->{scripts} = [];
  $self->{TL_WINDOW} = $self;
  $self->{TL_CONTAINER} = $self;
  $self->{INDENT} = 0;
  $self->{CACHEABLE} = 0;
  return $self;
}


sub insert {
  my ($this, $component) = @_;
  
  ##
  ## Sanity checking on input (this is a bit broken, of course--is
  ## there an equivalent for "ref" that checks for object's classes?
  ##
  ref $component or &$OOPSER("$component must be an object");
  $component->_isa("HTML::TableLayout::Component") or
    &$OOPSER("$component must be a component");
  
  
  ##
  ## Pseudo (runtime) overloading...
  ##
  if ($component->_isa("HTML::TableLayout::Script")) {
    push @{ $this->{scripts} }, $component;
  }
  elsif ($component->_isa("HTML::TableLayout::WindowHeader")) {
    push @{ $this->{headers} }, $component;
  }
  elsif ($component->_isa("HTML::TableLayout::Table")) {
    push @{ $this->{tables} }, $component;
  }
  else {
    &$OOPSER("cannot insert a $component into a window");
  }
  
  
  push @{ $this->{TL_COMPONENTS} }, $component;
  
  
  $component->tl_setContext($this);
  return $this;
}


sub print {
  my ($this) = @_;
  
  ##
  ## Fire off the first traversal of the heirarchy where "setup" gets
  ## done.  This is where componentcontainers tell their components
  ## their context, and where things that need to know about or affect
  ## other things around them can do so.
  ##
  $this->tl_setup();
  
  
  $this->i_print("<HTML");
  $this->_indentIncrement();
  $this->i_print("><HEAD><TITLE>$this->{title}</TITLE></HEAD");
  
  foreach (@{ $this->{scripts} }) { $_->tl_print() }
  
  $this->i_print("><BODY".params($this->tl_getParameters())."");
  $this->_indentIncrement();
  
  foreach (@{ $this->{headers} }) { $_->tl_print() }
  
  foreach (@{ $this->{tables} }) { $_->tl_print() }
  $this->_indentDecrement();
  $this->i_print("></BODY");
  $this->_indentDecrement();
  $this->i_print("></HTML>");
  $this->i_print();
}

sub toString {
  my ($this) = @_;
  $this->{CACHEABLE} = 1;
  $this->print();
  return $this->{TEXT_CACHE};
}

##
## i_print() and f_print() are what components/widgets use to print
## themselves out.  When you use these, you're guaranteed to get at
## least two things for free: (1) proper indenting of code (as long as
## you do NOT use any newlines) (2) correct behavior depending on
## whether we call print() or toString() on the window.  I.E., you do
## not *need* to use these in your widgets, as long as you accept the
## aforementioned losses (and perhaps others in the future...
##

##
## i_print(): indent print (both i_print() and f_print() take care of
## whether to pack the result into a string or output it right away
## with print())
##
sub i_print {
  my ($this,$text) = @_;
  my $cacheable = $this->{CACHEABLE};
  my $i;
  my $indent = $this->{INDENT};
  
  
  ##
  ## This is the only place where newlines come from!
  ##
  $cacheable ? $this->{TEXT_CACHE} .= "\n" : print "\n";
  
  ##
  ## print the indent spaces so it looks pretty
  ##
  if ($cacheable) {
    $this->{TEXT_CACHE} .= "  " x $indent;
  }
  else {
    print "  " x $indent;
  }
  
  ##
  ## print the content
  ##
  if ($cacheable) {
    if ($text) {
      $this->{TEXT_CACHE} ||= "";
      $this->{TEXT_CACHE} .= $text;
    }
  }
  else {
    print $text;
  }
}

##
## f_print(): flush print
##
sub f_print {
  my ($this,$text) = @_;
  if ($this->{CACHEABLE}) {
    $this->{TEXT_CACHE} .= $text;
  }
  else {
    print $text;
  }
}


sub _indentIncrement { shift->{INDENT}++ }
sub _indentDecrement { shift->{INDENT}-- }
sub _getIndent { return shift->{INDENT} }



# ---------------------------------------------------------------------

package HTML::TableLayout::Table;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Table::ISA=qw(HTML::TableLayout::ComponentContainer);


sub new {
  my ($class, %params) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS} = \%params;
  $self->{TL_COMPONENTS} = [];
  $self->{rowindex} = 0;
  $self->{form_is_mine} = 0;
  return $self;
}

sub insert {
  my ($this, $c, $br) = @_;
  if (! ref $c) {
    my $temp = $c;
    $c = HTML::TableLayout::Cell->new();
    $c->insert($temp,$br);
  }
  push @{ $this->{TL_COMPONENTS} }, $c;
  return $this;
}


sub tl_setup {
  my ($this) = @_;
  
  ## =================================================================
  ## o Given a TL_COMPONENTS (a list of components), weed out special
  ##   cases (like Form), and handle header processing on cells
  ## =================================================================
  
  my $first_row = 1;
  my $i;
  foreach $i (0..$#{ $this->{TL_COMPONENTS} }) {
    
    
    ##
    ## We can use $c for the most part, unless we are instrumenting a
    ## change in what one of the components actually is.
    ##
    my $c = $this->{TL_COMPONENTS}->[$i];
    
    ##
    ## Handle pseudo-overloading...
    ##
    if ($c->_isa("HTML::TableLayout::Form")) {
      if ($this->{TL_FORM}) {
	&$OOPSER("already got a form");
      }
      $c->tl_setContext($this);
      $this->{form_is_mine} = 1;
      $this->{TL_FORM} = $c;
      
      next;			# do NOT insert into _Row
      
      ##
      ## If I wanted to make it so one could add the "form" whenever
      ## one wantd, then right here it would have to go back to the
      ## components already processed and tell them about this form.
      ## (i think!)
      ##
    }
    
    
    my $cell;
    if ($c->_isa("HTML::TableLayout::Cell")) {
      
      ##
      ## if the cell has a header, then we slam it into an embedded
      ## table.  this procedure is too complex, and this code should
      ## probably be encapsulated elsewhere, or made simpler.
      ##
      
      my $h;
      if ($h = $c->getHeader()) {
	$c->_forgetIHaveAHeader();
	
	##
	## lie to the header about its context so we can ask it for
	## it's orientation here.  But we mean well... so it's ok.
	## Plus it'll get the correct context in a bit.
	##
	$h->tl_setContext($this);
	
	my ($t, $o);
	$o = $h->orientation();
	
	
	##
	## Replace, in the components array, the original cell with a
	## new one that contains it (and its header) in a table.
	##
	$this->{TL_COMPONENTS}->[$i] = $cell
	  = HTML::TableLayout::Cell->new(Anchor=>$o);
	
	
	##
	## $cell needs to inherit params from $c, $c needs to be
	## cleaned of most (all?) parameters.
	##
	## FIXME--there is no way this is fully correct...
	##
	if (exists $c->{TL_PARAMS}->{colspan}) {
	  $cell->{TL_PARAMS}->{colspan} = $c->{TL_PARAMS}->{colspan};
	  delete $c->{TL_PARAMS}->{colspan};
	}
	
	if (exists $c->{TL_PARAMS}->{rowspan}) {
	  $cell->{TL_PARAMS}->{rowspan} = $c->{TL_PARAMS}->{rowspan};
	  delete  $c->{TL_PARAMS}->{rowspan};
	}
	
	$cell->insert($t=HTML::TableLayout::Table
		      ->new(width=>"100%",
			    height=>"100%",
			    columns=>($o eq "top" or
				      $o eq "bottom") ? 1 : 2));	
	if ($o eq "top" or $o eq "left") {
	  $t->insert($h);	# $h gets correct context here...
	  $t->insert($c);
	}
	else {
	  $t->insert($c);
	  $t->insert($h);	# ...or here.
	}
      }
      else {
	$this->{TL_COMPONENTS}->[$i] = $cell = $c;
      }
    }
    else {
      $this->{TL_COMPONENTS}->[$i] = $cell =
	HTML::TableLayout::Cell->new()->insert($c);
    }
    
    
    ##
    ## ...now we have a cell for sure.
    ##
    $cell->tl_setContext($this);
    
    ## =================================================================
    ## o Pack resulting Cells into Table
    ## =================================================================
    
    ##
    ## Take care of adding it to the row
    ##
    my $row;
    if ($first_row) {
      $first_row = 0;
      ##
      ## Bootstrap the first row
      ##
      $row = $this->{rows}->[0]
	= HTML::TableLayout::_Row->new($this,
				       $this->{TL_WINDOW},
				       $this->{TL_FORM});
      $row->insert($cell) or &$OOPSER("cannot add first cell; ouch.");
    }
    elsif (($row = $this->{rows}->[$this->{rowindex}])->insert($cell)) {
      ##
      ## Ok--successfully added cell to current row
      ##
    }
    else {
      ##
      ## Hmm... need to create a new row (ok)
      ##
      $this->_removeOldSpanningCells();
      
      my $n_ridx = ++$this->{rowindex};
      $row = $this->{rows}->[$n_ridx]
	= HTML::TableLayout::_Row->new($this,
				       $this->{TL_WINDOW},
				       $this->{TL_FORM});
      
      if (! $row->insert($cell)) {
	##
	## This is error condition (!)
	##
	my $cs = $cell->getColspan();
	my $cols = $this->getColumns();
	if ($cs > $cols) {
	  &$OOPSER("colspan [$cs] exceeds max number of columns [$cols]");
	}
	else {
	  &$OOPSER("?? cannot pack; colspan $cs and cols $cols");
	}
      }
    }
    $cell->tl_setup();
  }
}

sub tl_print {
  my ($this) = @_;
  my $w = $this->{TL_WINDOW};
  if ($this->{form_is_mine}) { $this->{TL_FORM}->tl_print() }
  my $p = params($this->tl_getParameters()) || "";
  $w->i_print("><TABLE $p");
  $w->_indentIncrement();
  foreach(@{ $this->{rows} }) { $_->tl_print() };
  $w->_indentDecrement();
  $w->i_print("></TABLE");
  if ($this->{form_is_mine}) { $this->{TL_FORM}->_print_end() }
}


sub getColumns { return shift->{TL_PARAMS}->{columns} || 1 }
sub setColumns { shift->{TL_PARAMS}->{columns} = pop }

##
## A "spanning cell" is a cell having a colspan > 1 and as such is
## pertinent while packing subsequent rows.  It needs to be handled
## explicitely since it affects how many cells will fit into later
## rows.  These functions are used to keep track of cells in this
## state, and do appropriate calculations and removing of old or stale
## "spanning cells".
##

sub _insertSpanningCell {
  my ($this, $cell) = @_;
  push @{ $this->{spanning_cells} },
  HTML::TableLayout::_SpanningCell->new($cell,
					$this->{TL_WINDOW},
					$this->{TL_FORM})
}

sub _colspanOfSpanningCells {
  my ($this) = @_;
  my $sum = 0;
  my $sc;
  foreach $sc (@{ $this->{spanning_cells} }) {
    $sum += $sc->getColspan();
  }
  return $sum;
}

sub _removeOldSpanningCells {
  my ($this) = @_;
  my @old = @{ $this->{spanning_cells} };
  my (@new, $sc);
  foreach $sc (@old) {
    if ($sc->decrement() > 0) {
      push @new, $sc;
    }
  }
  $this->{spanning_cells} = \ @new;
}



# ---------------------------------------------------------------------
package HTML::TableLayout::_Row;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::_Row::ISA=qw(HTML::TableLayout::ComponentContainer);

##
## Some things about rows:
##
## o Rows happen automagically, hence the _ (aka private)
##
## o note that there are no parameters for the row--everyting that can
##   be set in the row can also be set in the cell (<TD>), so that's
##   where it'll be set.
##
## o We don't have to worry about the timing of rows b/c they are not
##   created until the table is "setup", which is "late".  Hence we
##   can set up the context directly in the constructor.
##


sub new {
  my ($class, $container, $window, $form) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_CONTAINER} = $container; # sanity check: a "Table"
  $self->{TL_WINDOW} = $window;
  $self->{TL_FORM} = $form;
  $self->{columns} = $container->getColumns();
  $self->{TL_COMPONENTS} = [];
  return $self;
}


sub setRSOffset { shift->{rs_offset} = pop }
sub getRSOffset { return shift->{rs_offset} || 0 }


sub getVacantSlots {
  my ($this) = @_;
  my $spaces = $this->{columns};
  my $cs_effect = sum(map { $_->getColspan() } @{ $this->{TL_COMPONENTS} });
  my $rs_effect = $this->{TL_CONTAINER}->_colspanOfSpanningCells();
  my $rs_offset = $this->getRSOffset();
  my $filled = $cs_effect + $rs_effect - $rs_offset;
  return $spaces - $filled;
}

sub isFull { return shift->getVacantSlots() <= 0 }


##
## this insert() returns 1 if it is able to insert the cell, and 0 if
## it is not.  In most cases, returning 0 is normal--it's just time to
## create a new row.
##
sub insert {
  my ($this, $cell) = @_;
  
  
  return 0 if ($this->getVacantSlots() - $cell->getColspan() < 0);
  
  
  if ($cell->tl_getContainer() ne $this) {
    $cell->tl_setContext($this);
  }
  
  if ($cell->getRowspan() > 1) {
    $this->{TL_CONTAINER}->_insertSpanningCell($cell);
    $this->setRSOffset($this->getRSOffset()+$cell->getColspan());
  }
  
  push @{ $this->{TL_COMPONENTS} }, $cell;
  $cell->tl_setContext($this);
  
  return 1;
}




sub tl_print {
  my ($this) = @_;
  ##
  ## The following check is disabled, but it *might* be re-enabled in
  ## the future.  The impact would be that the table must be CORRECTLY
  ## filled or else this will layoutmanager will die().  Perhaps there
  ## will be a flag to set for this behavior.
  ##
  
  #if (! $this->isFull() ) { &$OOPSER("row is not full") }
  
  my $w = $this->{TL_WINDOW};
  
  $w->i_print("><TR");
  
  $w->_indentIncrement();
  foreach(@{ $this->{TL_COMPONENTS} }) { $_->tl_print() };
  $w->_indentDecrement();
  $w->i_print("></TR");
}
# ---------------------------------------------------------------------

package HTML::TableLayout::Cell;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Cell::ISA=qw(HTML::TableLayout::ComponentContainer);


sub new {
  my ($class,  %params) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS} = \%params;
  $self->{TL_COMPONENTS} = [];
  return $self;
}


sub tl_getParameters {
  my ($this) = @_;
  my %r = ($this->{TL_WINDOW}->{PARAMETERS}->get($this),
	   %{ $this->{TL_PARAMS} },
	   colspan=>$this->getColspan(),
	   rowspan=>$this->getRowspan(),
	   width=>$this->getWidth());
  
  return %r;
}

sub insert {
  my ($this, $c, $br) = @_;
  ##
  ## if $c is a header, need to treat specially
  ##
  if (ref $c and $c->_isa("HTML::TableLayout::CellHeader")) {
    if ($this->{"cell_header"}) {
      &$OOPSER("There can only be one header per cell | $this");
    }
    $this->{"cell_header"} = $c;
  }
  elsif (ref $c and $c->_isa("HTML::TableLayout::Cell")) {
    &$OOPSER("Cannot insert a cell into a cell!");
  }
  elsif (ref $c and $c->_isa("HTML::TableLayout::Form")) {
    $this->{TL_FORM} = $c;
    ##
    ## It is possible that this cell might be inserted somewhere that
    ## already has a form.  If so, TL_FORM will be overwritten.  We
    ## can check to make sure this doesn't happen (and know what
    ## happened) by storing the correct for in "form_is_mine" and
    ## comparing them during tl_setup().
    ##
    $this->{form_is_mine} = $c;	
  }
  ##
  ## something else
  ##
  else {
    push @{ $this->{TL_COMPONENTS} }, $c;
    push @{ $this->{BREAKS} }, $br;
  }
  return $this;
}



sub tl_setup {
  my ($this) = @_;
  
  
  ##
  ## If we have a form, this is the time to set its context
  ##
  if ($this->{form_is_mine}) {
    if ($this->{form_is_mine} ne $this->{TL_FORM}) {
      &$OOPSER("Nested forms detected!");
    }
    else {
      $this->{TL_FORM}->tl_setContext($this);
    }
  }
  
  
  map {
    
    ##
    ## If it is not a reference, then assume it is text to print
    ##
    if (! ref $_) {
      $_ = HTML::TableLayout::Component::Text->new($_);
      $_->tl_setContext($this);
    }
    
    ##
    ## Maybe it is a form input, in which case it needs to be inserted
    ## into the appropriate form.
    ##
    elsif ($_->_isa("HTML::TableLayout::FormComponent")) {
      my $f = $this->{TL_FORM};
      if ($f) {
	$f->insert($_);
	$_->tl_setContext($this);
      }
      else {
	&$OOPSER("No Form to insert this FormComponent [$_] into [$this]");
      }
    }
    
    ##
    ## for anything else, we do nothing special.
    ##
    else {
      $_->tl_setContext($this);
    }
    $_->tl_setup();
    
  }
  @{ $this->{TL_COMPONENTS} };
  
  
}


sub tl_print {
  my ($this) = @_;
  
  
  my $w = $this->{TL_WINDOW};
  
  ##
  ## if "form_is_mine" flag is set, then we know we contain a form,
  ## and that this form should be printed AND IT HAS NOT ALREADY BEEN
  ## PRINTED BY A CONTAINING OBJECT.
  ##
  
  $this->{form_is_mine} and $this->{TL_FORM}->tl_print();
  
  $w->i_print("><TD".params($this->tl_getParameters())."");
  $w->_indentIncrement();
  
  
  foreach (0..$#{ $this->{TL_COMPONENTS} }) {
    $this->{TL_COMPONENTS}->[$_]->tl_print();
    $this->{BREAKS}->[$_] and $w->i_print("><BR");
  }
  
  $w->_indentDecrement();
  $w->i_print("></TD");
  
  
  $this->{form_is_mine} and $this->{TL_FORM}->_print_end();
}

sub getWidth {
  my ($this) = @_;
  return $this->{TL_PARAMS}->{width} ||
    int(100 * ($this->getColspan() /
	       $this->{TL_CONTAINER}->{TL_CONTAINER}->getColumns())) . "%";
}


sub getColspan { return shift->{TL_PARAMS}->{colspan} || 1 }
sub getRowspan { return shift->{TL_PARAMS}->{rowspan} || 1 }


sub getForm { return shift->{TL_FORM} }
sub getHeader { return shift->{"cell_header"} }

sub setColspan { shift->{TL_PARAMS}->{colspan} = pop }
sub setRowspan { shift->{TL_PARAMS}->{rowspan} = pop }


sub _forgetIHaveAHeader { delete shift->{"cell_header"} }


# ---------------------------------------------------------------------

package HTML::TableLayout::_SpanningCell;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::_SpanningCell::ISA=qw(HTML::TableLayout::TL_BASE);


##
## Like rows, these happen "late" and so we can put the context info
## right in the constructor
##

sub new {
  my ($class, $container, $window, $form) = @_;
  my $self = {};
  bless $self, $class;
  $self->{size} = $container->getRowspan(); # sanity check: container is a Cell
  $self->{TL_CONTAINER} = $container;
  $self->{TL_WINDOW} = $window;
  $self->{TL_FORM} = $form;
  return $self;
}

sub decrement { return --shift->{size} }
sub increment { return ++shift->{size} }
sub getColspan { return shift->{TL_CONTAINER}->getColspan() }


# ---------------------------------------------------------------------

package HTML::TableLayout::CellHeader;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::CellHeader::ISA
  =qw(HTML::TableLayout::ComponentContainer HTML::TableLayout::Cell);

##
## The inheretence is kind of whack here.  Basically, this thing sits
## in a table and hence should be a cell.  HOWEVER, we don't want to
## use cell's tl_getParameters(), but rather the one from
## Component... funny thing is that cell is a component, so by using
## multiple inheretence here, we're a cell and twice a component.  but
## it seems to work so what the fuck^H^H^H^Hfooey.
##


sub new {
  my ($class, $h, %params) = @_;
  my $self = {};
  bless $self, $class;
  if (ref $h) {
    $self->{TL_COMPONENTS}->[0] = $h;
  }
  else {
    $self->{TL_COMPONENTS}->[0]
      = HTML::TableLayout::Component::Text->new($h);
  }
  $self->{TL_PARAMS} = \%params;
  return $self;
}



sub tl_print {
  my ($this) = @_;
  
  my $w = $this->{TL_WINDOW};
  my %params = $this->tl_getParameters();
  delete $params{Orientation};
  
  $w->i_print("><TH".params(%params)."");
  $w->_indentIncrement();
  $this->{TL_COMPONENTS}->[0]->tl_print();
  $w->_indentDecrement();
  $w->i_print("></TH");
}


##
## Note that "Orientation" is capitalized because it is a pseudo
## parameter and does not make it through to the HTML.
##
sub orientation {
  my ($this) = @_;
  my %p =  $this->tl_getParameters();
  return $p{Orientation} || "top";
}



# ---------------------------------------------------------------------

package HTML::TableLayout::WindowHeader;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::WindowHeader::ISA=
  qw(HTML::TableLayout::ComponentContainer);


sub new {
  my ($class, $H, $component, %params) = @_;
  my $self = {};
  bless $self, $class;
  if ($H and $H =~ /\D/) {
    &$OOPSER("WindowHeader usage: new(<h number>,<component>,<params>)")
  }
  $self->{H} = $H;
  $self->{TL_COMPONENTS}->[0] = $component;
  $self->{TL_PARAMS} = \%params;
  return $self;
}


sub tl_setup {
  my ($this) = @_;
  if (! ref $this->{TL_COMPONENTS}->[0]) {
    $this->{TL_COMPONENTS}->[0] =
      HTML::TableLayout::Component::Text->new($this->{TL_COMPONENTS}->[0]);
  }
  
  $this->SUPER::tl_setup();
}

sub tl_print {
  my ($this) = @_;
  
  my $w = $this->{TL_WINDOW};
  if ($this->{H}) {
    $w->i_print("><H".$this->{H}.params($this->tl_getParameters())."");
    $w->_indentIncrement();
    $this->{TL_COMPONENTS}->[0]->tl_print();
    $w->_indentDecrement();
    $w->f_print("></H$this->{H}");
  }
  else {
    $w->i_print();
    $this->{TL_COMPONENTS}->[0]->tl_print();
  }
}   

# ---------------------------------------------------------------------
package HTML::TableLayout::Script;
use HTML::TableLayout::Symbols;
@HTML::TableLayout::Script::ISA=qw(HTML::TableLayout::Component);


sub new {
  my ($class, $script, %params) = @_;
  my $self = {};
  bless $self, $class;
  $self->{TL_PARAMS} = \%params;
  $self->{"script"} = $script;
  return $self;
}

sub tl_print {
  my ($this) = @_;
  my $w = $this->{TL_WINDOW};
  my $p = params($this->tl_getParameters()) || "";
  $w->i_print("><SCRIPT $p>\n<!--\n");
  $w->f_print($this->{"script"});
  $w->f_print("\n//-->");
  $w->i_print("</SCRIPT");
}

1;
