package Dist::Zilla::Plugin::OurPkgVersion;
use 5.008;
use strict;
use warnings;

# VERSION

use Moose;
with (
	'Dist::Zilla::Role::FileMunger',
	'Dist::Zilla::Role::FileFinderUser' => {
		default_finders => [ ':InstallModules', ':ExecFiles' ],
	},
	'Dist::Zilla::Role::PPI',
);

use Carp qw( confess );
use PPI;
use MooseX::Types::Perl qw( LaxVersionStr );
use namespace::autoclean;

sub munge_files {
	my $self = shift;

	$self->munge_file($_) for @{ $self->found_files };
	return;
}

sub munge_file {
	my ( $self, $file ) = @_;

	if ( $file->name =~ m/\.pod$/ixms ) {
		$self->log_debug( 'Skipping: "' . $file->name . '" is pod only');
		return;
	}

	my $version = $self->zilla->version;

	confess 'invalid characters in version'
		unless LaxVersionStr->check( $version );  ## no critic (Modules::RequireExplicitInclusion)

	my $doc = $self->ppi_document_for_file($file);

	return unless defined $doc;

	my $comments = $doc->find('PPI::Token::Comment');

	my $version_regex
		= q{
                  ^
                  (\s*)              # capture all whitespace before comment
                  (
                    \#\#?\s*VERSION  # capture # VERSION or ## VERSION
                    \b               # and ensure it ends on a word boundary
                    [                # conditionally
                      [:print:]      # all printable characters after VERSION
                      \s             # any whitespace including newlines - GH #5
                    ]*               # as many of the above as there are
                  )
                  $                  # until the EOL}
		;

	my $munged_version = 0;
	if ( ref($comments) eq 'ARRAY' ) {
		foreach ( @{ $comments } ) {
			if ( /$version_regex/xms ) {
				my ( $ws, $comment ) =  ( $1, $2 );
				$comment =~ s/(?=\bVERSION\b)/TRIAL /x if $self->zilla->is_trial;
				my $code
						= "$ws"
						. q{our $VERSION = '}
						. $version
						. qq{'; $comment}
						;
				$_->set_content("$code");
				$munged_version++;
			}
		}
	}

	if ( $munged_version ) {
		$self->save_ppi_document_to_file( $doc, $file);
		$self->log_debug([ 'adding $VERSION assignment to %s', $file->name ]);
	}
	else {
		$self->log( 'Skipping: "'
			. $file->name
			. '" has no "# VERSION" comment'
			);
	}
	return;
}
__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: No line insertion and does Package version with our

=head1 SYNOPSIS

in dist.ini

	[OurPkgVersion]

in your modules

	# VERSION

=head1 DESCRIPTION

This module was created as an alternative to
L<Dist::Zilla::Plugin::PkgVersion> and uses some code from that module. This
module is designed to use a the more readable format C<our $VERSION =
$version;> as well as not change then number of lines of code in your files,
which will keep your repository more in sync with your CPAN release. It also
allows you slightly more freedom in how you specify your version.

=head2 EXAMPLES

in dist.ini

	...
	version = 0.01;
	[OurPkgVersion]

in lib/My/Module.pm

	package My::Module;
	# VERSION
	...

output lib/My/Module.pm

	package My::Module;
	our $VERSION = '0.01'; # VERSION
	...

please note that whitespace before the comment is significant so

	package My::Module;
	BEGIN {
		# VERSION
	}
	...

becomes

	package My::Module;
	BEGIN {
		our $VERSION = '0.01'; # VERSION
	}
	...

while

	package My::Module;
	BEGIN {
	# VERSION
	}
	...

becomes

	package My::Module;
	BEGIN {
	our $VERSION = '0.01'; # VERSION
	}
	...

you can also add additional comments to your comment

	...
	# VERSION: generated by DZP::OurPkgVersion
	...

becomes

	...
	our $VERSION = '0.1.0'; # VERSION: generated by DZP::OurPkgVersion
	...

you can also use perltidy's default static side comments (##)

	...
	## VERSION
	...

becomes

	...
	our $VERSION = '0.1.0'; ## VERSION
	...

Also note, the package line is not in any way significant, it will insert the
C<our $VERSION> line anywhere in the file before C<# VERSION> as many times as
you've written C<# VERSION> regardless of whether or not inserting it there is
a good idea. OurPkgVersion will not insert a version unless you have C<#
VERSION> so it is a bit more work.

If you make a trial release, the comment will be altered to say so:

	# VERSION

becomes

	our $VERSION = '0.01'; # TRIAL VERSION

=head1 METHODS

=over

=item munge_files

Override the default provided by L<Dist::Zilla::Role::FileMunger> to limit
the number of files to search to only be modules and executables.

=item munge_file

tells which files to munge, see L<Dist::Zilla::Role::FileMunger>

=back

=cut
