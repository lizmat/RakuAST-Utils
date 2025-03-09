[![Actions Status](https://github.com/lizmat/RakuAST-Utils/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/RakuAST-Utils/actions) [![Actions Status](https://github.com/lizmat/RakuAST-Utils/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/RakuAST-Utils/actions) [![Actions Status](https://github.com/lizmat/RakuAST-Utils/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/RakuAST-Utils/actions)

NAME
====

RakuAST::Utils - provide basic RakuAST utilities

SYNOPSIS
========

```raku
use RakuAST::Utils;

say NameAST("Foo::Bar");

say TypeAST( Array[Int] );

sub foo(Int $a, Str $b) { }
say ParameterAST( &foo.signature.params[0] );

say SignatureAST( &foo.signature );
```

DESCRIPTION
===========

The `RakuAST::Utils` provides a number of subroutines that make the programmatical creation of code using RakuAST a lot easier.

SUBROUTINES
===========

NameAST
-------

```raku
say NameAST( "Foo" );
say NameAST( "Foo::Bar" );
```

    RakuAST::Name.from-identifier("Foo")
    RakuAST::Name.from-identifier-parts("Foo","Bar")

The `TypeAST` subroutine takes a package-like string and returns the RakUAST representation of that string.

TypeAST
-------

```raku
say TypeAST( Array[Int] );
```

    RakuAST::Type::Parameterized.new(
      base-type => RakuAST::Type::Simple.new(
        RakuAST::Name.from-identifier("Array")
      ),
      args      => RakuAST::ArgList.new(
        RakuAST::Type::Simple.new(
          RakuAST::Name.from-identifier("Int")
        )
      )
    )

The `TypeAST` subroutine takes a type object and returns the RakUAST representation of that type object.

ParameterAST
------------

```raku
sub foo(Int $a, Str $b --> Str:D) { }
say ParameterAST( &foo.signature.params[0] );
```

    RakuAST::Parameter.new(
      type   => RakuAST::Type::Simple.new(
        RakuAST::Name.from-identifier("Int")
      ),
      target => RakuAST::ParameterTarget::Var.new(
        name => "\$a"
      )
    )

The `ParameterAST` subroutine takes a [`Parameter`](https://docs.raku.org/type/Parameter) object and returns the RakUAST representation of that object.

SignatureAST
------------

```raku
sub foo(Int $a, Str $b --> Str:D) { }
say SignatureAST( &foo.signature );
```

    RakuAST::Signature.new(
      parameters => (
        RakuAST::Parameter.new(
          type   => RakuAST::Type::Simple.new(
            RakuAST::Name.from-identifier("Int")
          ),
          target => RakuAST::ParameterTarget::Var.new(
            name => "\$a"
          )
        ),
        RakuAST::Parameter.new(
          type   => RakuAST::Type::Simple.new(
            RakuAST::Name.from-identifier("Str")
          ),
          target => RakuAST::ParameterTarget::Var.new(
            name => "\$b"
          )
        ),
      ),
      returns    => RakuAST::Type::Simple.new(
        RakuAST::Name.from-identifier("Str:D")
      )
    )

The `SignatureAST` subroutine takes a [`Signature`](https://docs.raku.org/type/Signature) object and returns the RakUAST representation of that object.

ACKNOWLEDGEMENTS
================

The initial version of this distribution was taken from the work on [`.assuming`](https://github.com/rakudo/rakudo/issues/2599), which was sponsored by the [Raku Foundation](https://raku.foundation).

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/RakuAST-Utils . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2025 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

