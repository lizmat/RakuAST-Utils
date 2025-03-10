use experimental :rakuast;
use nqp;

# Shortcut to literalizing a value
my sub literalize(Mu $value) {
    RakuAST::Literal.from-value($value)
}

# Shortcut to creating an "is" trait
my sub trait-is(str $name) {
    RakuAST::Trait::Is.new(
      name => RakuAST::Name.from-identifier($name)
    )
}

# Create a simple type, possibly consisting of more than one part
my sub make-simple-type(str $name) {
    RakuAST::Type::Simple.new(NameAST($name))
}


#-------------------------------------------------------------------------------
# Make a RakuAST::Name
my sub NameAST(str $name) is export {
    my str @parts = $name.split('::');
    @parts.elems == 1
      ?? RakuAST::Name.from-identifier(@parts.head)
      !! RakuAST::Name.from-identifier-parts(|@parts)
}

#-------------------------------------------------------------------------------
# Create a RakuAST version of a given type, with any parameterizations
# and coercions, recursively
my sub TypeAST(Mu:U $type) is export {
    my $HOW := $type.HOW;

    # Looks like a coercion type
    if nqp::istype($HOW,Metamodel::CoercionHOW) {
        RakuAST::Type::Coercion.new(
          base-type  => TypeAST($type.^target_type),
          constraint => TypeAST($type.^constraint_type)
        )
    }

    # Looks like a type smiley
    elsif nqp::istype($HOW,Metamodel::DefiniteHOW) {
        RakuAST::Type::Definedness.new(
          base-type => TypeAST($type.^base_type),
          definite  => $type.^definite.so
        )
    }

    # Looks like a parameterized type
    elsif nqp::can($HOW,"roles") && $type.^roles -> @roles {
        my $role := @roles.head;
        if nqp::istype($role.HOW,Metamodel::ParametricRoleGroupHOW) {
            make-simple-type($type.^name)
        }
        else {
            my @args is List = @roles.head.^role_arguments.map(&TypeAST);
            RakuAST::Type::Parameterized.new(
              base-type => TypeAST($type.^mro[1]),
              args      => RakuAST::ArgList.new(|@args)
            )
        }
    }

    # A simple type will suffice if there is no coercion or
    # parameterization
    else {
        make-simple-type($type.^name)
    }
}

#-------------------------------------------------------------------------------
# Create a RakuAST version of a Parameter object
my sub ParameterAST(Parameter:D $parameter, *%_) is export {
    BEGIN my $slurpytypes := nqp::hash(
      '*',   RakuAST::Parameter::Slurpy::Flattened,
      '**',  RakuAST::Parameter::Slurpy::Unflattened,
      '+',   RakuAST::Parameter::Slurpy::SingleArgument
    );

    my str $sigil = $parameter.sigil;
    my %args;

    my sub add-is-trait-if-set(str $name) {
        %args<traits>.push(trait-is($name))
          if !$parameter.capture && $parameter."$name"();
    }

    # Strip off any Positional[] and Associative[] for arrays
    # and hashes, because otherwise we would get them stacked
    # on top of each other.  But don't set the type if the
    # role was the only constraint, as that will be handled
    # later by the sigil
    my sub set-role-type(Mu \type, Mu \role) {
        unless nqp::eqaddr(type,role) {
            %args<type> = TypeAST(
              nqp::istype(type.HOW,Metamodel::CurriedRoleHOW)
                && nqp::eqaddr(type.^curried_role,role)
                ?? type.^role_arguments.head
                !! type
            );
        }
    }

    if $parameter.type_captures -> @captures {
        %args<type-captures> = RakuAST::Type::Capture.new(
            NameAST(@captures.join('::'))
        );
    }
    else {
        my $type := %_<type>:exists ?? %_<type> !! $parameter.type;

        $sigil eq '@'
          ?? set-role-type($type, Positional)
          !! $sigil eq '%'
            ?? set-role-type($type, Associative)
            !! (%args<type> = TypeAST($type));
    }

    # Some kind of capture as target
    if $sigil eq '|' {
        %args<target> = RakuAST::ParameterTarget::Term.new(
          RakuAST::Name.from-identifier(%_<name> // $parameter.name)
        );
        %args<slurpy> = RakuAST::Parameter::Slurpy::Capture;
    }

    # An ordinary target
    else {
        %args<target> = RakuAST::ParameterTarget::Var.new(
          name => %_<name> // ($parameter.name || $sigil)
        );
    }

    %args<slurpy> = nqp::atkey($slurpytypes,$parameter.prefix)
      if $parameter.slurpy;

    if $parameter.named_names -> @names {
        %args<names>    = @names;
        %args<optional> = False unless $parameter.optional;
    }
    else {
        %args<optional> = True if $parameter.optional;
    }

    add-is-trait-if-set($_) for <raw rw copy>;

    # If a default value was explicitely specified, we're handling
    # a name argument, which by definition has to become optional
    # if it has a default
    if %_<default>:exists {
        %args<default> = literalize(%_<default>);
        %args<optional>:delete;
    }

    # Check if the parameter has a default value, and make sure the
    # RakuAST version of it has that as well
    else {
        my $default := nqp::getattr($parameter,Parameter,'$!default_value');
        %args<default> = literalize($default)
          unless nqp::isnull($default);
    }

    if $parameter.constraint_list -> @constraints {
        my $head := @constraints.head;
        if @constraints.elems == 1
          && nqp::not_i(nqp::istype($head,Code)) {
            %args<value> = $head;  # literalize($head)) ??
            %args<target>:delete;
        }
        else {
            %args<where> = literalize($head);
        }
    }

    %args<sub-signature> = SignatureAST($_)
      with $parameter.sub_signature;

    RakuAST::Parameter.new(|%args)
}

#-------------------------------------------------------------------------------
# Create a RakuAST version of a Signature object
my sub SignatureAST(Signature:D $signature) is export {
    my %args;
    %args<parameters> := $signature.params.map(&ParameterAST).eager;

    my $returns := $signature.returns;
    if nqp::isconcrete($returns) {
        %args<returns> = literalize($returns);
    }
    elsif nqp::not_i(nqp::eqaddr($returns,Mu)) {
        %args<returns> = TypeAST($returns);
    }

    RakuAST::Signature.new(|%args)
}

# vim: expandtab shiftwidth=4
