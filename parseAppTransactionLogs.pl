#!/usr/bin/perl

# The overall data structure: yes it's global, yes you can bite my shiny metal ass. This is perl, this is how we roll.
my $data = {}; 

sub generatePieChartForHash($) {
	my $hName = shift;
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

		#my $colors = "";
		#my $step = 256 / $cCount;
		#for ($i = 0; $i < $cCount; $i++) {
		#	my $comp = $i % 3;
		#	my $hexcomp = sprintf("%02x", ($step*$i));
		#	my $ocomp = sprintf("%02x", ((255-$step)/($i+1)));
		#	print STDERR "hc: $hexcomp oc: $ocomp\n";
		#	$colors .= "$hexcomp$hexcomp$hexcomp,";
		#}
		#$colors =~ s/\,\s?$//ig;
		#print HTML "&chco=$colors";

		$retStr .= "$cData&chl=$labels\" />";
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
		my $ui = -1, $sdi = -1, $edi = -1, $cci = -1, $cni = -1, $vi = -1, $ti = -1;

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

					$iCount++;
				}

				$h->{"indexes"} = {"UI"=>$ui, "SDI"=>$sdi, "EDI"=>$edi, "CCI"=>$cci, "CNI"=>$cni, "VI"=>$vi, "TI"=>$ti};
			}
			else {
				if ($ui > -1 && $sdi > -1 && $edi > -1 && $cci > -1 && $cni > -1 && $vi > -1 && $ti > -1) {
					my @fields = split(/\t/);

					my $units = @fields[$ui];
					my $startDate = @fields[$sdi];
					my $endDate = @fields[$edi];
					my $currency = @fields[$cci];
					my $country = @fields[$cni];
					my $vendor = @fields[$vi];
					my $title = @fields[$ti];

					my $days = $endDate - $startDate;
					my $dur = "$startDate" . ($days > 0 ? "-$endDate" : "");
					my $key = "{$vendor}_{$title}_$dur";

					# totals for this duration key
					$h->{$key}->{"total"} += $units;
					$h->{$key}->{"curr_total"}->{$currency} += $units;
					$h->{$key}->{"cn_total"}->{$country} += $units;
				
					# vendor/title totals
					$data->{"vendors"}->{$vendor}->{"total"} += $units;
					$data->{"vendors"}->{$vendor}->{"titles"}->{$title}->{"total"} += $units;
					$data->{"vendors"}->{$vendor}->{"cn_total"}->{$country} += $units;
					$data->{"vendors"}->{$vendor}->{"titles"}->{$title}->{"cn_total"}->{$country} += $units;
					$data->{"vendors"}->{$vendor}->{"curr_total"}->{$currency} += $units;
					$data->{"vendors"}->{$vendor}->{"titles"}->{$title}->{"curr_total"}->{$currency} += $units;

					# overall totals
					$data->{"total"} += $units;
					$data->{"curr_total"}->{$currency} += $units;
					$data->{"cn_total"}->{$country} += $units;

					# duration totals
					$data->{"timeSlices"}->{$dur}->{"total"} += $units;
					$data->{"timeSlices"}->{$dur}->{"numDays"} = $days;
				}
			}
		}
	}
}

use POSIX qw(strftime);
my $tStr = strftime("%b-%e-%Y", localtime());
my $gtStr = strftime("%a %b %e, %Y", localtime());
$tStr =~ s/\s+//ig;

# I can't use "this be Perl" as an excuse for this atrocity. No more excuses, I'm just lazy: someday this might
# be templatized, but for now you're going to have to deal with my output style or hack the output here yourself
# (YOU HAVE BEEN WARNED).
open (HTML, "+>./$tStr.html") or die "HTML Gen: $!\n\n";
print HTML qq~<html><head><title>Transaction Logs, generated $gtStr</title>~;
print HTML qq~<style type="text/css"> h1, h2, h3, h4, h5 {display:inline;} h1 {color: #00cc11;}~;
print HTML qq~h2 {color:#0011cc;} h4 {font-variant:small-caps;} h5 {font-style:italic;}</style></head><body>~;

print HTML qq~<h1>$data->{total}</h1> <h2>total downloads</h2><br/><h3>Report generated on $gtStr</h3><br/><br/>~;

print HTML "<h3>Examined " . scalar(keys(%{$data->{"files"}})) . " file(s), ";
print HTML "Found <h2>" . scalar(keys(%{$data->{"vendors"}})) . "</h2> vendor(s):</h3><ul>";

foreach my $vend (keys(%{$data->{"vendors"}})) {
	print HTML "<li><h4><u>$vend</u></h4><br><h5>Titles:</h5><ul>";

	foreach my $ti (keys(%{$data->{"vendors"}->{$vend}->{"titles"}})) {
		print HTML "<li><u>$ti</u>: <h5>$data->{vendors}->{$vend}->{titles}->{$ti}->{total}</h5> downloads<br/>";
	}

	print HTML "</ul>";
}

print HTML "</ul>";
print HTML "<h2>Charts</h2><br/><br/>";

#####
# daily download chart
print HTML "<h3>Total downloads, by day:</h3><br/><br/>";
print HTML "<img src=\"http://chart.apis.google.com/chart?cht=bvs&chs=600x320";

$labels = "";
$cData = "";
$cCount = 0;
my $min = 2**32, $max = 0;
foreach my $dday (sort(keys(%{$data->{"timeSlices"}}))) {
	if ($data->{"timeSlices"}->{$dday}->{"numDays"} == 0 && $dday =~ /(\d{4})(\d{2})(\d{2})/) {
		my $year = $1, $month = $2, $day = $3;
		my $count = $data->{"timeSlices"}->{$dday}->{"total"};
		my $prcnt = sprintf("%0.1f%%", ($count / $data->{"total"}));

		$min = $count, if ($count < $min);
		$max = $count, if ($count > $max);

		$cData .= "$count,";
		$labels .= "$month/$day|";
	}
	$cCount++;
}

$cData =~ s/\,\s?$//ig;
$labels =~ s/\|\s?$//ig;
my $nums = $cData;
$nums =~ s/\,/\|/ig;

if ($min && $max) {
	$min -= int($min / 5);
	$max += int($max / 20);
	print HTML "&chds=$min,$max";
	print HTML "&chxt=y&chxl=0:|$min|".int(($min + $max) / 2)."|$max";
}

my $chbh = 480 / $cCount;
my $bw = $chbh / 2;

my $colors = "";
my $step = 256 / $cCount;
for ($i = 0; $i < $cCount; $i++) {
	my $comp = $i % 3;
	my $hexcomp = sprintf("%02x", ($step*$i));
	my $ocomp = sprintf("%02x", ((255-$step)/($i+1)));
	$colors .= "$ocomp$ocomp$hexcomp|";
}

$colors =~ s/\|\s?$//ig;
print HTML "&chco=$colors";
print HTML "&chdl=$nums&chdlp=r";

print HTML "&chd=t:$cData&chl=$labels&chbh=$bw,$bw\" />";
print HTML "<br/><br/><br/>";

#####
# country percentage chart
print HTML "<h3>Total download percentage by country:</h3><br/><br/>";
print HTML generatePieChartForHash("cn_total");

#####
# currency percentage chart
print HTML "<br/><br/><br/>";
print HTML "<h3>Total download percentage by local currency type:</h3><br/><br/>";
print HTML generatePieChartForHash("curr_total");

print HTML qq~</body></html>~;
