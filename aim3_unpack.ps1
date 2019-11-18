# Runs through the subdirs under the aim1 raw/downloaded folder
#   unzipping any zips it finds
#   renames files from r01_ to ::site abbreviation::_
#   copying sas dsets & log files to the raw folder

# $root = "\\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming"
$root = "C:\Users\pardre1\documents\vdw\pbs\"

. "$root\Programs\sites.ps1"

$ze = "\\ghcmaster\ghri\warehouse\Sas\utilities\7za.exe e"

$raw_folder = "\\groups\data\ctrhs\PCORNET_Bariatric_Study\Programming\Data\aim3_individual\raw"

function do_dir($dir, $site_abbrev) {
  get-childitem $dir.fullname *.zip | foreach-object {
    echo "Working on $dir.  Site abbreviation is $site_abbrev"
    $zipfile = $_.fullname
    $outdir = $dir.fullname
    $run_string = "$ze '$zipfile' -y -o'$outdir'"
    # echo $run_string
    invoke-expression $run_string
  }
  get-childitem $dir.fullname | where-object {$_.extension -match "sas7bdat|log"} | foreach-object {
    $new_name = $_.fullname -replace 'r01', $site_abbrev
    $new_name = $new_name   -replace 'b01', $site_abbrev
    $new_name = $new_name   -replace 'b03', $site_abbrev
    if ($new_name -eq $_.fullname) {
      echo "No rename necessary for $_"
    }
    else {
      if (test-path $new_name) {
        remove-item $new_name
      }
      rename-item $_.fullname $new_name
    }
    move-item $new_name $raw_folder -force
  }
}

dir "$raw_folder\downloaded" -ad | foreach-object {
  $site_abbrev = $sites[$_.name]

  if ($site_abbrev -eq $null) {echo "Problem!  No abbreviation listed for '$_'!"}
  else {
    $att_file = "$raw_folder\$site_abbrev" + "_attrition.sas7bdat"
    # echo "Checking for $att_file."
    if (test-path $att_file) {
      echo "Found existing attrition file for $site_abbrev--skipping."
    }
    else {
      echo "New data for '$site_abbrev'!"
      do_dir $_ $site_abbrev
    }
  }

}

# \\ghcmaster\ghri\warehouse\Sas\utilities\7za.exe e '\\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim1_individual\raw\downloaded\C4 - University of Wisconsin Madison DataMart\WISC_drnoc_pbs_ahr_wp002_nsd1_v01.zip' -y -o 'C4 - University of Wisconsin Madison DataMart C4MCW.fullname'


# \\ghcmaster\ghri\warehouse\Sas\utilities\7za.exe e '\\groups\data\ctrhs\PCORNET_Bariatric_Study\Programming\Data\wave1\raw\downloaded\C7CPED\pbs_ahr_wp001_nsd2_v01 (1).zip' -y -o'\\groups\data\ctrhs\PCORNET_Bariatric_Study\Programming\Data\wave1\raw\downloaded\C7CPED'
