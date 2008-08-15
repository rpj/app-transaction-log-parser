#!/usr/bin/perl

# The overall data structure: yes it's global, yes you can bite my shiny metal ass. This is perl, this is how we roll.
my $data = {}; 

sub generatePieChartForHash($$) {
	my $hName = shift;
	my $startCmp = shift || 0;
	my $retStr = "";

	if ($hName) {
		$retStr .= "<img src=\"http://chart.apis.google.com/chart?cht=p&chs=640x320&chd=t:";

		my $labels = "";
		my $cData = "";
		my $cCount = 0;
		my $othCount = 0, $othTotal = 0.0;

		foreach my $cn (keys(%{$data->{$hName}})) {
			my $val =  (($data->{$hName}->{$cn} / $data->{"total"}) * 100);

			if ($val >= 1.0) {
				$sv = sprintf("%0.1f", $val);
				$labels .= "$cn ($sv\%)|";
				$cData .= sprintf("%0.1f,", $val);
			}
			else {
				$othCount++;
				$othTotal += $val;
			}

			$cCount++;
		}

		if (!$othCount) {
			$cData =~ s/\,\s?$//ig;
			$labels =~ s/\|\s?$//ig;
		}
		else {
			my $val = sprintf("%0.1f", $othTotal);
			$cData .= $val;
			$labels .= "Other ($val\%)";
			$cCount++;
		}

		$retStr .= "$cData&chl=$labels";

		my $colors = "";
		my $lowLim = 100;
		my $upLim = 230;
		my $curCmp = $startCmp;
		my $lStep = ($upLim - $lowLim) / ($cCount / 2.5);
		my $dir = 1;
		my @rgb = ($lowLim, $lowLim, $lowLim);

		for ($i = 0; $i < $cCount; $i++) {
			my $nval = $rgb[$curCmp] + ($dir == 1 ? $lStep : - $lStep);

			if (($dir == 1 && $nval <= $upLim) || ($dir == 0 && $nval >= $lowLim)) {
				$rgb[$curCmp] = $nval;
				$colors .= sprintf("%02x%02x%02x,", $rgb[0], $rgb[1], $rgb[2]);
			} else {
				$dir = ($dir == 1 ? 0 : 1);
				$curCmp = (($curCmp + 1) % 3), unless ($dir);
				$i -= 1;
			}
		}

		$colors =~ s/\,\s?$//ig;
		$retStr .= "&chco=$colors";

		$retStr .= qq~" />~;
	}

	return $retStr;
}

# build the data structure
foreach my $file (@ARGV) {
	my $fn = "./$file";

	if (-e $fn) {
		open (F, "$fn") or die "$!\n\n";
		print STDERR "Processing \"$file\"\n";

		my $h = $data->{"files"}->{$fn} = {};
		
		my $lCount = 0;
		my $ui = -1, $sdi = -1, $edi = -1, $cci = -1, $cni = -1, $vi = -1, $ti = -1, $pti = -1;

		for (; $_ = <F>; $lCount++) {
			if (!$lCount) {
				my @ids = split(/\t/);
				my $iCount = 0;

				foreach my $id (@ids) {
					$ui = $iCount, if ($id =~ /Units/i);
					$sdi = $iCount, if ($id =~ /Begin\sDate/i);
					$edi = $iCount, if ($id =~ /End\sDate/i);
					$cci = $iCount, if ($id =~ /Customer\sCurrency/i);
					$cni = $iCount, if ($id =~ /Country\sCode/i);
					$vi = $iCount, if ($id =~ /Artist\s/i);
					$ti = $iCount, if ($id =~ /Title\s/i);
					$pti = $iCount, if ($id =~ /Product\sType\sIdentifier/i);

					$iCount++;
				}

				#$h->{"indexes"} = {"UI"=>$ui, "SDI"=>$sdi, "EDI"=>$edi, "CCI"=>$cci, "CNI"=>$cni, "VI"=>$vi, "TI"=>$ti, "PTI"=>$pti};
			}
			else {
				if ($ui > -1 && $sdi > -1 && $edi > -1 && $cci > -1 && $cni > -1 && $vi > -1 && $ti > -1) {
					my @fields = split(/\t/);

					my $units = $fields[$ui];
					my $startDate = $fields[$sdi];
					my $endDate = $fields[$edi];
					my $currency = $fields[$cci];
					my $country = $fields[$cni];
					my $vendor = $fields[$vi];
					my $title = $fields[$ti];
					my $ptiVal = $fields[$pti], if ($pti > -1);

					my $days = $endDate - $startDate;
					my $dur = "$startDate" . ($days > 0 ? "-$endDate" : "");
					my $key = "{$vendor}_{$title}_$dur";

					# totals for this duration key
#					$h->{$key}->{"total"} += $units;
#					$h->{$key}->{"curr_total"}->{$currency} += $units;
#					$h->{$key}->{"cn_total"}->{$country} += $units;
#					$h->{$key}->{"pti_total"}->{$ptiVal} += $units, if ($ptiVal);
				
					# vendor/title totals
#					$data->{"vendors"}->{$vendor}->{"total"} += $units;
					$data->{"vendors"}->{$vendor}->{"titles"}->{$title}->{"total"} += $units;
#					$data->{"vendors"}->{$vendor}->{"cn_total"}->{$country} += $units;
#					$data->{"vendors"}->{$vendor}->{"titles"}->{$title}->{"cn_total"}->{$country} += $units;
#					$data->{"vendors"}->{$vendor}->{"curr_total"}->{$currency} += $units;
#					$data->{"vendors"}->{$vendor}->{"titles"}->{$title}->{"curr_total"}->{$currency} += $units;

					$data->{"vendors"}->{$vendor}->{"titles"}->{$title}->{"pti_total"}->{$ptiVal} += $units, if ($ptiVal);

					# overall totals
					$data->{"total"} += $units;
					$data->{"curr_total"}->{$currency} += $units;
					$data->{"cn_total"}->{$country} += $units;
					$data->{"pti_total"}->{$ptiVal} += $units;
					$data->{"pti_per_cn"}->{$country}->{$ptiVal} += $units;

					# duration totals
					$data->{"timeSlices"}->{$dur}->{"total"} += $units;
					$data->{"timeSlices"}->{$dur}->{"numDays"} = $days;
					$data->{"timeSlices"}->{$dur}->{"pti_total"}->{$ptiVal} += $units, if ($ptiVal);
				}
			}
		}
	}
}

# do some post-proc on pti_per_cn
my $ppch = $data->{'pti_per_cn'};
foreach my $ppc (keys(%{$ppch})) {
	my $h = $ppch->{$ppc};
	$h->{'ratio'} = ($h->{7}) ? sprintf("%0.2f", ($h->{1} / $h->{7})) : "NaN";
	$ppch->{'byratio'}->{$h->{'ratio'}} = $ppc;
}

use POSIX qw(strftime);
my $tStr = strftime("%b-%e-%Y", localtime());
my $gtStr = strftime("%a %b %e, %Y", localtime());
$tStr =~ s/\s+//ig;

# I can't use "this be Perl" as an excuse for this atrocity. No more excuses, I'm just lazy: someday this might
# be templatized, but for now you're going to have to deal with my output style or hack the output here yourself
# (YOU HAVE BEEN WARNED).
open (HTML, "+>./$tStr.html") or die "HTML Gen: $!\n\n";

#{ require Data::Dumper; print HTML "<!--\n\n". Data::Dumper::Dumper($data) ."\n\n-->"; }

print HTML qq~<html><head><title>Transaction Logs, generated $gtStr</title>~;
print HTML qq~<style type="text/css"> h1, h2, h3, h4, h5 {display:inline;} h1 {color: #00cc11;}~;
print HTML qq~h2 {color:#0011cc;} h4 {font-variant:small-caps;} h5 {font-style:italic;}</style></head><body>~;

print HTML "<table border=0 cellpadding=0 cellspacing=20 width=100%>";
print HTML "<tr><td>";
print HTML qq~<h1>$data->{total}</h1> <h4>total downloads</h4><br/>~;
print HTML qq~<h2>$data->{pti_total}->{1}</h2> <h5>(~. sprintf("%0.2f", (($data->{pti_total}->{1}/$data->{total})*100)) . 
		"\%)</h5> <h4>new</h4>&nbsp;&nbsp;<h4>/</h4>&nbsp;&nbsp;";
print HTML qq~<h2>$data->{pti_total}->{7}</h2> <h5>(~. sprintf("%0.2f", (($data->{pti_total}->{7}/$data->{total})*100)) . "\%)</h5> <h3>updates</h3><br/><br/>";
print HTML qq~<br/><h5>Report generated on </h5><h4>$gtStr</h4>~;

print HTML "</td><td align=left>";
print HTML "<h3>Examined " . scalar(keys(%{$data->{"files"}})) . " file(s), ";
print HTML "Found </h3><h2>" . scalar(keys(%{$data->{"vendors"}})) . "</h2> <h3>vendor(s):</h3><ul>";

foreach my $vend (keys(%{$data->{"vendors"}})) {
	print HTML "<li><h4><u>$vend</u></h4><br><ul>";

	foreach my $ti (keys(%{$data->{"vendors"}->{$vend}->{"titles"}})) {
		print HTML "<li><u>$ti</u>: <h5>$data->{vendors}->{$vend}->{titles}->{$ti}->{total}</h5> downloads<br/>";
	}

	print HTML "</ul>";
}

print HTML "</ul>";
print HTML "</td></tr><tr><td colspan=2><hr width=100%></td></tr>";
print HTML "</td></tr>";
print HTML "<tr><td>";

#####
# daily download chart
my $numDays = 12;
print HTML "<h3>Total downloads, by day, for the past $numDays days:</h3><br/><br/>";
print HTML "<img src=\"http://chart.apis.google.com/chart?cht=bvs&chs=500x400";

$labels = "";
$cData = "";
$cCount = 0;
my $min = 2**32, $max = 0;

my @ddayArr = sort(keys(%{$data->{"timeSlices"}}));
my $dday = undef;
my $ddayStart = scalar(@ddayArr) - ($numDays + 1);
	
for (; $cCount <= $numDays; $cCount++, $dday = $ddayArr[$cCount + $ddayStart]) {
	if ($dday =~ /(\d{4})(\d{2})(\d{2})/) {
		my $year = $1, $month = $2, $day = $3;
		my $count = $data->{"timeSlices"}->{$dday}->{"total"};
		my $prcnt = sprintf("%0.1f%%", ($count / $data->{"total"}));

		$min = $count, if ($count < $min);
		$max = $count, if ($count > $max);

		$cData .= "$count,";
		$month =~ s/(^|\/)0//ig;
		$day =~ s/(^|\/)0//ig;
		$labels .= "$month/$day|";
	}
}

$cData =~ s/\,\s?$//ig;
$labels =~ s/\|\s?$//ig;
my $nums = $cData;
$nums =~ s/\,/\|/ig;

if ($min && $max) {
	$max += int($max / 20);
	print HTML "&chds=0,$max";
	print HTML "&chxt=y&chxl=0:|0|".int(($min + $max) / 2)."|$max";
}

my $chbh = int(500/ $cCount);
my $bw = int($chbh / 2);
my $colors = "";
my $lowLim = 70;
my $upLim = 230;
my $curCmp = 0;
my $lStep = ($upLim - $lowLim) / ($cCount / 2.5);
my $dir = 1;
my @rgb = ($upLim, $lowLim, $lowLim);
	
	my $c1 = "abcdef", $c2 = "fedcba";

for ($i = 0; $i < $cCount; $i++) {
	my $nval = $rgb[$curCmp] + ($dir == 1 ? $lStep : - $lStep);

	if (($dir == 1 && $nval <= $upLim) || ($dir == 0 && $nval >= $lowLim)) {
		$rgb[$curCmp] = $nval;
		my $c = sprintf("%02x%02x%02x", $rgb[0], $rgb[1], $rgb[2]);
		$colors .= "$c|";
		$c1 = $c, if ($i == 0);
		$c2 = $c, if ($i == ($cCount - 1));
	} else {
		$dir = ($dir == 1 ? 0 : 1);
		$curCmp = (($curCmp + 1) % 3), unless ($dir);
		$i -= 1;
	}
}

$colors =~ s/\|\s?$//ig;
print HTML "&chco=$colors";
print HTML "&chg=8.35,16.7,1,4";
print HTML "&chdl=$nums&chdlp=r";

print HTML "&chd=t:$cData&chl=$labels&chbh=$bw,".int($bw/2)."\" />";
print HTML "<br/><br/><br/>";
print HTML "</td><td>";
	
{	
#####
# new vs. update chart

$labels = "";
$cDataNew = "";
$cDataUpd = "";
$cCount = 0;
my $min = 2**32, $max = 0;

my @ddayArr = sort(keys(%{$data->{"timeSlices"}}));
my $dday = undef;
my $ddayStart = scalar(@ddayArr) - ($numDays + 1);

print HTML "<h3>New downloads vs. Updates, for the past $numDays days:</h3><br/><br/>";
print HTML "<img src=\"http://chart.apis.google.com/chart?cht=bvs&chs=500x400";

my $pts = "";
for (; $cCount <= $numDays; $cCount++, $dday = $ddayArr[$cCount + $ddayStart]) {
	if ($dday =~ /(\d{4})(\d{2})(\d{2})/) {
			my $year = $1, $month = $2, $day = $3;
			
			my $countNew = $data->{"timeSlices"}->{$dday}->{"pti_total"}->{1};
			my $countUpd = $data->{"timeSlices"}->{$dday}->{"pti_total"}->{7} + 0;
			
			my $prcntNew = sprintf("%0.1f%%", ($countNew / $data->{"total"}));
			my $prcntUpd = sprintf("%0.1f%%", ($countNew / $data->{"total"}));
			
			my $tot = $countNew + $countUpd;
			$min = $tot, if ($tot < $min);
			$max = $tot, if ($tot > $max);
			
			$cDataNew .= "$countNew,";
			$cDataUpd .= "$countUpd,";
			
			$pts .= "t${countNew},000000,0,".($cCount-1).",10|";
			
			$month =~ s/(^|\/)0//ig;
			$day =~ s/(^|\/)0//ig;
			$labels .= "$month/$day|";
	}
}

$cDataNew =~ s/\,\s?$//ig;
$cDataUpd =~ s/\,\s?$//ig;
$labels =~ s/\|\s?$//ig;
my $nums = $cData;
$nums =~ s/\,/\|/ig;

$pts =~ s/\|\s?$//ig;

print HTML "&chxt=y,x,t";

if ($min && $max) {
	$max += int($max / 20);
	print HTML "&chds=0,$max";
	print HTML "&chxl=0:|0|".int(($min + $max) / 2)."|$max";
}

$xcn = $cDataNew;
$xcu = $cDataUpd;
$xcn =~ s/\,/\|/ig;
$xcu =~ s/\,/\|/ig;
print HTML "|1:|$labels|2:|$xcu";
print HTML "&chm=$pts";

my $chbh = int(500/ $cCount);
my $bw = int($chbh / 2);
my $colors = "";
my $lowLim = 70;
my $upLim = 205;
my $curCmp = 0;
my $lStep = ($upLim - $lowLim) / ($cCount / 2.5);
my $dir = 1;
my @rgb = ($upLim, $lowLim - int(rand(10)), $lowLim + int(rand(10)));
	
	my $c1 = "abcdef", $c2 = "fedcba";

for ($i = 0; $i < $cCount; $i++) {
	my $nval = $rgb[$curCmp] + ($dir == 1 ? $lStep : - $lStep);

	if (($dir == 1 && $nval <= $upLim) || ($dir == 0 && $nval >= $lowLim)) {
		$rgb[$curCmp] = $nval;
		my $c = sprintf("%02x%02x%02x", $rgb[0], $rgb[1], $rgb[2]);
		$colors .= "$c|";
		$c1 = $c, if ($i == 0);
		$c2 = $c, if ($i == ($cCount - 1));
	} else {
		$dir = ($dir == 1 ? 0 : 1);
		$curCmp = (($curCmp + 1) % 3), unless ($dir);
		$i -= 1;
	}
}

print HTML "&chco=$c1,$c2";
print HTML "&chdl=New (numbers on top of bars)|Updates (numbers on top axis)";
print HTML "&chdlp=t";

print HTML "&chd=t:$cDataNew|$cDataUpd";
print HTML "&chbh=$bw,".int($bw/2);
print HTML "&chg=8.35,16.7,1,4";
print HTML "&chf=c,ls,0,ffffff,0.0835,efefef,0.0835";
print HTML "\" />";
print HTML "<br/><br/><br/>";
print HTML "</td></tr>";
}




print HTML "<tr><td colspan=2>";

=cut
#####
# ratio chart

my $numDays = 15;
print HTML "<h3>Ratio</h3><br/><br/>";
print HTML "<img src=\"http://chart.apis.google.com/chart?cht=bvs&chs=500x400";

$labels = "";
$cData = "";
$cCount = 0;
$nums = "";
my $min = 2**32, $max = 0;

my @ddayArr = sort {$b <=> $a} keys(%{$data->{"pti_per_cn"}->{"byratio"}});
my $dday = undef;
my $ddayStart = scalar(@ddayArr) - ($numDays + 1);
	
for (; $cCount <= $numDays; $cCount++, $dday = $ddayArr[$cCount + $ddayStart]) {
	if ($dday !~ /NaN/i && $dday > 0) {
		my $cn = $data->{"pti_per_cn"}->{'byratio'}->{$dday};

		$nums .= "$dday|";
		$dday = int($dday * 100);

		$min = $dday, if ($dday < $min);
		$max = $dday, if ($dday > $max);

		$cData .= "$dday,";
		$labels .= "$cn|";
	}
}

$cData =~ s/\,\s?$//ig;
$labels =~ s/\|\s?$//ig;
$nums =~ s/\|\s?$//ig;

#if ($min && $max) {
	$max += int($max / 20);
	print STDERR "MAX $max\n";
	print HTML "&chds=0,$max";
	print HTML "&chxt=y,x&chxl=0:|0|".((($min + $max) / 2) / 100)."|". ($max/100). "";
#}

print HTML "|1:|$labels";

my $chbh = int(500/ $cCount);
my $bw = int($chbh / 2);
my $colors = "";
my $lowLim = 70;
my $upLim = 230;
my $curCmp = 0;
my $lStep = ($upLim - $lowLim) / ($cCount / 2.5);
my $dir = 1;
my @rgb = ($upLim, $lowLim, $lowLim);
	
	my $c1 = "abcdef", $c2 = "fedcba";

for ($i = 0; $i < $cCount; $i++) {
	my $nval = $rgb[$curCmp] + ($dir == 1 ? $lStep : - $lStep);

	if (($dir == 1 && $nval <= $upLim) || ($dir == 0 && $nval >= $lowLim)) {
		$rgb[$curCmp] = $nval;
		my $c = sprintf("%02x%02x%02x", $rgb[0], $rgb[1], $rgb[2]);
		$colors .= "$c|";
		$c1 = $c, if ($i == 0);
		$c2 = $c, if ($i == ($cCount - 1));
	} else {
		$dir = ($dir == 1 ? 0 : 1);
		$curCmp = (($curCmp + 1) % 3), unless ($dir);
		$i -= 1;
	}
}

$colors =~ s/\|\s?$//ig;
print HTML "&chco=$colors";
print HTML "&chg=8.35,16.7,1,4";
print HTML "&chdl=$nums&chdlp=r";

print HTML "&chd=t:$cData&chbh=$bw,".int($bw/2)."\" />";
print HTML "<br/><br/><br/>";
print HTML "</td></tr>";
	


=cut




print HTML "<tr><td>";
#####
# country percentage chart
print HTML "<h3>Total download percentage by country:</h3><br/><br/>";
print HTML generatePieChartForHash("cn_total", 1);
print HTML "</td><td>";

#####
# currency percentage chart
print HTML "<h3>Total download percentage by local currency type:</h3><br/><br/>";
print HTML generatePieChartForHash("curr_total", 2);
print HTML "</td></tr></table>";
print HTML "<br/><hr width=100%><br/>";
print HTML "<center><span style='font-size: small;'><a href=\"http://github.com/rpj/app-transaction-log-parser/tree/master\">iTunes Transaction Parser</a>, &copy; 2008 <a href=\"http://rpj.me\">rpj</a></span></center>";

print HTML qq~</body></html>~;
