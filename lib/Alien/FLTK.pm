package Alien::FLTK;
{
    use strict;
    use warnings;
    use File::Spec::Functions qw[catdir rel2abs];
    our $VERSION = 1.00000;
    use Alien::FLTK::ConfigData;
    sub revision { return Alien::FLTK::ConfigData->config('fltk_svn'); }

    sub include_path {
        my @include = map { -d $_ ? $_ : () } (
                            rel2abs(catdir(qw[blib arch Alien FLTK include])),
                            Alien::FLTK::ConfigData->config('include_path')
        );
        return $include[0];
    }

    sub library_path {
        my @libs = map { -d $_ ? $_ : () } (
                               rel2abs(catdir(qw[blib arch Alien FLTK libs])),
                               Alien::FLTK::ConfigData->config('library_path')
        );
        return $libs[0];
    }
    sub _TODO_libs      { Alien::FLTK::ConfigData->config('libs') }
    sub _TODO_use_gl    { Alien::FLTK::ConfigData->config('use_gl') }
    sub _TODO_use_forms { Alien::FLTK::ConfigData->config('use_forms') }
    sub _TODO_use_glut  { Alien::FLTK::ConfigData->config('use_glut') }
    sub _TODO_use_cairo { Alien::FLTK::ConfigData->config('use_cairo') }
    sub _TODO_use_x     { Alien::FLTK::ConfigData->config('use_x') }
    sub _TODO_cxx { Alien::FLTK::ConfigData->config('fltk2-config')->{'cxx'} }

    sub cflags {
        my ($class, $args) = @_;
        return Alien::FLTK::ConfigData->config('fltk2-config')->{'cflags'};
    }

    sub cxxflags {
        my ($class, $args) = @_;
        return Alien::FLTK::ConfigData->config('fltk2-config')->{'cxxflags'};
    }

    sub ldflags {
        my ($class, $args) = @_;
        my @flags;
        push @flags, qw[-lfltk2_gl -lglu32 -lopengl32]
            if $args->{'gl'} || $args->{'glut'};
        push @flags,
            qw[-lfltk2_images -lfltk2_png -lfltk2_z -lfltk2_images -lfltk2_jpeg]
            if $args->{'images'};
        push @flags, qw[-lfltk2_forms] if $args->{'forms'};
        push @flags,
            Alien::FLTK::ConfigData->config('fltk2-config')->{'ldflags'};
        return wantarray ? @flags : join ' ', @flags;
    }

    sub ldstaticflags {
        my ($class, $args) = @_;
        my @flags = $class->ldflags($args);
        require Config;
        my $dir = $class->library_path();
        my $_a  = $Config::Config{'_a'};
        map {
            s[-l(fltk2_?\w*)]['"'.catdir($dir . '/lib' . $1 . $_a) . '"']eg;
        } @flags;
        return wantarray ? @flags : join ' ', @flags;
    }

    sub _TODO_post {    # MacOS needs post
        return $^O eq 'MacOS'
            ? catdir(shift->include_path() . '/fltk/mac.r')
            : ();
    }
    1;
}

=pod

=head1 NAME

Alien::FLTK - Build and use the Fast Light Toolkit binaries

=head1 Description

This distribution builds and installs libraries for the (experimental)
C<2.0.x> branch of the FLTK GUI toolkit.

=head1 Synopsis

  use Alien::FLTK;
  use ExtUtils::CBuilder;
  my $CC     = ExtUtils::CBuilder->new();
  my $source = 'hello_world.cxx';
  open(my $FH, '>', $source) || die '...';
  syswrite($FH, <<'') || die '...'; close $FH;
    #include <fltk/Window.h>
    #include <fltk/Widget.h>
    #include <fltk/run.h>
    using namespace fltk;
    int main(int argc, char **argv) {
      Window *window = new Window(300, 180);
      window->begin();
      Widget *box = new Widget(20, 40, 260, 100, "Hello, World!");
      box->box(UP_BOX);
      box->labelfont(HELVETICA_BOLD_ITALIC);
      box->labelsize(36);
      box->labeltype(SHADOW_LABEL);
      window->end();
      window->show(argc, argv);
      return run();
    }

  my $obj = $CC->compile(source       => $source,
                         include_dirs => [Alien::FLTK->include_path()],
                         extra_compiler_flags => Alien::FLTK->cxxflags()
  );
  my $exe = $CC->link_executable(
        objects => [$obj],
        extra_linker_flags =>
            [Alien::FLTK->ldflags(), '-L"' . Alien::FLTK->library_path() . '"']
  );
  print system($exe) ? 'Aww...' : 'Yay!';
  END { unlink grep defined, $source, $obj, $exe; }

=head1 Methods

=head2 C<include_path>

    my $include_path = Alien::FLTK->include_path;

Returns the location of the headers installed during the build
process.

=head2 C<library_path>

    my $include_path = Alien::FLTK->library_path;

Returns the location of the private libraries we made and installed
during the build process.

=head2 C<cflags>

    my $cflags = Alien::FLTK->cflags;

Returns additional C compiler flags to be used.

=head2 C<cxxflags>

    my $cxxflags = Alien::FLTK->cxxflags;

Returns additional C++ compiler flags to be used.

=head2 C<revision>

    my $revision = Alien::wxWidgets->revision;

Returns the SVN revision number of the source
L<C<Alien::FLTK>|Alien::FLTK> was built with.

=head1 Bugs

Numerous, I'm sure.

TODO

=head1 Notes

=head2 Support Links

TODO

=head2 Dependencies

=over

=item L<C<File::Spec::Functions>|File::Spec::Functions>

=item L<C<Alien::FLTK::ConfigData>|Alien::FLTK::ConfigData> which is
created and installed by L<C<Module::Build>|Module::Build>

=back

=head2 Examples

TODO

=head2 Installation

TODO

=head1 See Also

L<Alien::FLTK::ConfigData|Alien::FLTK::ConfigData>

=head1 Acknowledgments

=over

=item The FLTK Team - http://www.fltk.org/

=back

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2009 by Sanko Robinson E<lt>sanko@cpan.orgE<gt>

This program is free software; you can redistribute it and/or modify
it under the terms of The Artistic License 2.0.  See the F<LICENSE>
file included with this distribution or
http://www.perlfoundation.org/artistic_license_2_0.  For
clarification, see http://www.perlfoundation.org/artistic_2_0_notes.

When separated from the distribution, all POD documentation is covered
by the Creative Commons Attribution-Share Alike 3.0 License.  See
http://creativecommons.org/licenses/by-sa/3.0/us/legalcode.  For
clarification, see http://creativecommons.org/licenses/by-sa/3.0/us/.

L<C<Alien::FLTK>|Alien::FLTK> is based in part on the work of the FLTK
project. See http://www.fltk.org/.

=for git $Id: FLTK.pm 9d6ef4c 2009-06-08 01:19:45Z sanko@cpan.org $

=cut
