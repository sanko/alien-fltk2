#!perl
use strict;
use warnings;
use Alien::FLTK;
use ExtUtils::CBuilder;
use Config qw[%Config];
my $CC     = ExtUtils::CBuilder->new();
my $source = 'embed.cxx';
open(my $FH, '>', $source) || die '...';
syswrite($FH, <<'') || die '...'; close $FH;
#line 12 "0001_embed.pl"
#include <fltk/ask.h>
#include <perl.h>
#include <EXTERN.h>
static PerlInterpreter *my_perl;
int main( int argc, char **argv, char **env ) {
    STRLEN n_a;
    char *embedding[] = { "", "-e", "0" };
    PERL_SYS_INIT3( &argc, &argv, &env );
    my_perl = perl_alloc();
    perl_construct( my_perl );
    perl_parse( my_perl, NULL, 3, embedding, NULL );
    PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
    perl_run( my_perl );
    if ( ! sv_derived_from( PL_patchlevel, "version" ) )
        upg_version( PL_patchlevel, TRUE );
    SV * level = vstringify( PL_patchlevel );
#ifdef PERL_PATCHNUM
    SV *num = newSVpvs( PERL_PATCHNUM );
    if ( sv_len( num ) >= sv_len( level ) &&
         strnEQ( SvPV_nolen( num ), SvPV_nolen( level ), sv_len( level ) )
       ) {
        SvREFCNT_dec( level );
        level = num;
    }
    else {
        Perl_sv_catpvf( aTHX_ level, " (%" SVf ")", num );
        SvREFCNT_dec( num );
    }
#endif
    SV * opts_prog = newSVpv( "use Config;\n$_ = join ' ', sort qw("
#  ifdef DEBUGGING
                              " DEBUGGING"
#  endif
#  ifdef NO_MATHOMS
                              " NO_MATHOMS"
#  endif
#  ifdef PERL_DONT_CREATE_GVSV
                              " PERL_DONT_CREATE_GVSV"
#  endif
#  ifdef PERL_MALLOC_WRAP
                              " PERL_MALLOC_WRAP"
#  endif
#  ifdef PERL_MEM_LOG
                              " PERL_MEM_LOG"
#  endif
#  ifdef PERL_MEM_LOG_ENV
                              " PERL_MEM_LOG_ENV"
#  endif
#  ifdef PERL_MEM_LOG_ENV_FD
                              " PERL_MEM_LOG_ENV_FD"
#  endif
#  ifdef PERL_MEM_LOG_STDERR
                              " PERL_MEM_LOG_STDERR"
#  endif
#  ifdef PERL_MEM_LOG_TIMESTAMP
                              " PERL_MEM_LOG_TIMESTAMP"
#  endif
#  ifdef PERL_USE_DEVEL
                              " PERL_USE_DEVEL"
#  endif
#  ifdef PERL_USE_SAFE_PUTENV
                              " PERL_USE_SAFE_PUTENV"
#  endif
#  ifdef USE_SITECUSTOMIZE
                              " USE_SITECUSTOMIZE"
#  endif
#  ifdef USE_FAST_STDIO
                              " USE_FAST_STDIO"
#  endif
                              , 0 );
    /* Terminate the qw(, and then wrap at 76 columns.  */
    sv_catpvs( opts_prog, ");\ns/(?=.{53})(.{1,53}) /$1\\n                        /mg;\n$a = Config::myconfig( ) . <<END;\n\n" );
#ifdef VMS
    sv_catpvs( opts_prog, "Characteristics of this PERLSHR image:\n" );
#else
    sv_catpvs( opts_prog, "Characteristics of this binary (from libperl):\n" );
#endif
    sv_catpvs( opts_prog, "    Compile-time options: $_\n" );
#if defined(LOCAL_PATCH_COUNT)
    if ( LOCAL_PATCH_COUNT > 0 ) {
        int i;
        sv_catpvs( opts_prog, "    Locally applied patches:\n" );
        for ( i = 1; i <= LOCAL_PATCH_COUNT; i++ ) {
            if ( PL_localpatches[i] )
                Perl_sv_catpvf( aTHX_ opts_prog, "q%c\t%s\n%c\n",
                                0, PL_localpatches[i], 0 );
        }
    }
#endif
    Perl_sv_catpvf( aTHX_ opts_prog,
                    "    Built under %s\n", OSNAME );
    sv_catpvs( opts_prog,
#ifdef __DATE__
#  ifdef __TIME__
               "    Compiled at " __DATE__ " " __TIME__ "\n"
#  else
               "    Compiled on " __DATE__ "\n"
#  endif
#endif
               "END\n $x=\"\\n    \";\n"
               "@env = map { \"$_=\\\"$ENV{$_}\\\"\" }\n"
               "    sort grep {/^PERL/} keys %ENV;\n"
#ifdef __CYGWIN__
               "$a .= push @env, \"CYGWIN=\\\"$ENV{CYGWIN}\\\"\";\n"
#endif
               "$a .= \"    \\%ENV:\\n        \" . join( \"\\n        \", @env) . \"\\n\" if @env;\n"
               "$a .= \"    \\@INC:\\n        \" . join( \"\\n        \", @INC) . \"\\n\";\n" );
    eval_sv( opts_prog, TRUE );
    fltk::message_window_scrollable = true;
    fltk::message_window_label = form(
                                     "This is perl, %" SVf " built for %s", level, ARCHNAME
                                 );
    fltk::message( SvPV( get_sv( "a", FALSE ), n_a ) );
    SvREFCNT_dec( level );
    perl_destruct( my_perl );
    perl_free( my_perl );
    PERL_SYS_TERM();
}
/*
*
* Most of this is inspired (read: taken) by perl.c which, of course, is
* Copyright (C) 1993-2009 by Larry Wall, et al. and is distributed under the
* terms of either the GNU General Public License or the Artistic License, as
* specified in the README file from the perl distribution.
*
*/

my $obj = $CC->compile(source               => $source,
                       extra_compiler_flags => Alien::FLTK->cxxflags());
my $exe = $CC->link_executable(
                      objects            => $obj,
                      extra_linker_flags => [
                           Alien::FLTK->ldflags(),
                           $Config{'archlib'} . '/CORE/' . $Config{'libperl'},
                      ]
);
printf system('./' . $exe) ? 'Aww...' : 'Yay! %s bytes', -s $exe;
END { unlink grep defined, $source, $obj, $exe; }

=pod

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2009 by Sanko Robinson E<lt>sanko@cpan.orgE<gt>

This program is free software; you can redistribute it and/or modify it under
the terms of The Artistic License 2.0. See the F<LICENSE> file included with
this distribution or http://www.perlfoundation.org/artistic_license_2_0.  For
clarification, see http://www.perlfoundation.org/artistic_2_0_notes.

When separated from the distribution, all POD documentation is covered by the
Creative Commons Attribution-Share Alike 3.0 License. See
http://creativecommons.org/licenses/by-sa/3.0/us/legalcode.  For
clarification, see http://creativecommons.org/licenses/by-sa/3.0/us/.

=for git $Id$

=cut
