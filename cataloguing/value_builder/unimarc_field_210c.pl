#!/usr/bin/perl


# Copyright 2000-2002 Katipo Communications
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use strict;
use warnings;

use C4::AuthoritiesMarc;
use C4::Auth;
use C4::Context;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Search;
use MARC::Record;
use C4::Koha;

###TODO To rewrite in order to use SearchAuthorities

sub plugin_javascript {
my ($dbh,$record,$tagslib,$field_number,$tabloop) = @_;
my $function_name= $field_number;
#---- build editors list.
#---- the editor list is built from the "EDITORS" thesaurus
#---- this thesaurus category must be filled as follow :
#---- 200$a for isbn
#---- 200$b for editor
#---- 200$c (repeated) for collections


my $res  = "
<script type=\"text/javascript\">
function Clic$function_name(subfield_managed) {
    defaultvalue=escape(document.getElementById(\"$field_number\").value);
    newin=window.open(\"../cataloguing/plugin_launcher.pl?plugin_name=unimarc_field_210c.pl&index=\"+subfield_managed,\"unimarc_225a\",'width=500,height=600,toolbar=false,scrollbars=yes');
}
</script>
";
return ($function_name,$res);
}

sub plugin {
my ($input) = @_;
    my $query=new CGI;
    my $op = $query->param('op');
    my $authtypecode = $query->param('authtypecode');
    my $index = $query->param('index');
    my $category = $query->param('category');
    my $resultstring = $query->param('result');
    my $dbh = C4::Context->dbh;

    my $startfrom=$query->param('startfrom');
    $startfrom=0 if(!defined $startfrom);
    my ($template, $loggedinuser, $cookie);
    my $resultsperpage;

    my $authtypes = getauthtypes;
    my @authtypesloop;
    foreach my $thisauthtype (keys %$authtypes) {
        my $selected;
        if ($thisauthtype eq $authtypecode) {
            $selected=1;
        }
        my %row =(value => $thisauthtype,
                    selected => $selected,
                    authtypetext => $authtypes->{$thisauthtype}{'authtypetext'},
                index => $index,
                );
        push @authtypesloop, \%row;
    }

    if ($op eq "do_search") {
        my @marclist = $query->param('marclist');
        my @and_or = $query->param('and_or');
        my @excluding = $query->param('excluding');
        my @operator = $query->param('operator');
        my @value = $query->param('value');
        my $orderby   = $query->param('orderby');

        $resultsperpage= $query->param('resultsperpage');
        $resultsperpage = 19 if(!defined $resultsperpage);

        # builds tag and subfield arrays
        my @tags;

        my ($results,$total) = SearchAuthorities( \@tags,\@and_or,
                                            \@excluding, \@operator, \@value,
                                            $startfrom*$resultsperpage, $resultsperpage,$authtypecode, $orderby);

	# Getting the $b if it exists
	for (@$results) {
	    my $authority = GetAuthority($_->{authid});
		if ($authority->field('200') and $authority->subfield('200','b')) {
		    $_->{to_report} = $authority->subfield('200','b');
	    }
 	}

        ($template, $loggedinuser, $cookie)
            = get_template_and_user({template_name => "cataloguing/value_builder/unimarc_field_210c.tt",
                    query => $query,
                    type => 'intranet',
                    authnotrequired => 0,
                    flagsrequired => {editcatalogue => '*'},
                    debug => 1,
                    });

        # multi page display gestion
        my $displaynext=0;
        my $displayprev=$startfrom;
        if(($total - (($startfrom+1)*($resultsperpage))) > 0 ) {
            $displaynext = 1;
        }

        my @numbers = ();

        if ($total>$resultsperpage) {
            for (my $i=1; $i<$total/$resultsperpage+1; $i++) {
                if ($i<16) {
                    my $highlight=0;
                    ($startfrom==($i-1)) && ($highlight=1);
                    push @numbers, { number => $i,
                        highlight => $highlight ,
                        startfrom => ($i-1)};
                }
            }
        }

        my $from = $startfrom*$resultsperpage+1;
        my $to;

        if($total < (($startfrom+1)*$resultsperpage)) {
            $to = $total;
        } else {
            $to = (($startfrom+1)*$resultsperpage);
        }
        my $link="../cataloguing/plugin_launcher.pl?plugin_name=unimarc_field_210c.pl&amp;authtypecode=EDITORS&amp;".join("&amp;",map {"value=".$_} @value)."&amp;op=do_search&amp;type=intranet&amp;index=$index";

        $template->param(result => $results) if $results;
        $template->param('index' => $query->param('index'));
        $template->param(startfrom=> $startfrom,
                                displaynext=> $displaynext,
                                displayprev=> $displayprev,
                                resultsperpage => $resultsperpage,
                                startfromnext => $startfrom+1,
                                startfromprev => $startfrom-1,
                                total=>$total,
                                from=>$from,
                                to=>$to,
                                numbers=>\@numbers,
                                authtypecode =>$authtypecode,
                                resultstring =>$value[0],
                                pagination_bar => pagination_bar(
                                    $link,
                                    getnbpages($total, $resultsperpage),
                                    $startfrom,
                                    'startfrom'
                                ),
                                );
    } else {
        ($template, $loggedinuser, $cookie)
            = get_template_and_user({template_name => "cataloguing/value_builder/unimarc_field_210c.tt",
                    query => $query,
                    type => 'intranet',
                    authnotrequired => 0,
                    flagsrequired => {editcatalogue => '*'},
                    debug => 1,
                    });

        $template->param(index => $index,
                        resultstring => $resultstring
                        );
    }

    $template->param(authtypesloop => \@authtypesloop);
    $template->param(category => $category);

    # Print the page
    output_html_with_http_headers $query, $cookie, $template->output;
}
