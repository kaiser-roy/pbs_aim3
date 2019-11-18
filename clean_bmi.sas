/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* C:\Users/pardre1/Documents/vdw/pbs/Programs/clean_bmi.sas
*
* Code for conditioning BMI data from PCORnet.  The clean_bmi()
* macro enforces range limits on heights, weights and BMIs.
* It imputes heights from one record to another where necessary
* and possible, using different strategies for adults and
* adolescents.  This code replaces Rob Wellmans BMI_v2() macro
* (in pbs_ht_wt_check.sas).
*
* dedupe_bmi() does just what it says--reduces the set to one
* bmi measure per person per day.  For person/days with > 1
* measure, it checks whether the measures are all within 5 units.
* If they are, it replaces them all with an average.  If not
* it deletes them all.
*********************************************/

/*
  pass 1: set any OOR values of ht or wt to missing.
  pass 2: calculate BMIs
    If a record has both ht and wt measures, calculate BMI using those values.
    If ht but no wt, BMI = missing.
    If wt but no ht:
      If adult, we use the modal value of all height measures taken during the period of interest.
      If child, we use the height value nearest in time to the wt measure (before/after doesn’t matter, if > 1 qualifying ht, choose randomly).
  pass 3: delete any records with OOR BMIs.
  pass 4: de-dupe
    if > 1 BMI on a single day, then calculate bmi_diff = max(BMI) - min(BMI).
      if bmi_diff <  5 then BMI = avg(BMI).
      if bmi_diff >= 5 then delete all measures on that day.

For measures on the same day, if BMI <5 units apart, then take average. If BMI
>=5 units apart, ignore all wt/BMI measures for that day.

*/

* Q: how often do we have original_bmi values, without also having either ht or wt? ;

* options obs = 2000 ;

/*
call 2017-03-13
  all hts OOR--drop?
    yes drop

  wts + orig_bmi only
    back-calculate ht
      only for ppl for whom we have *no* valid ht measures
        only for kids?  kids are very precious, adults, less so.

      keep imputation the same

      how many adoles w/wts + origbmis, but no hts?
*/

%macro clean_bmi(inppl = sts.people, invitals = col.cohortvital, outset = col.clean_bmi_new) ;
  %local lowht highht lowwt highwt lowBMI highBMI ;

  %let lowht   = 48 ;
  %let highht  = 84 ;

  %let lowwt   = 50 ;
  %let highwt  = 700 ;

  %let lowBMI  = 15 ;
  %let highBMI = 90 ;

  proc sql noprint ;
    select max(length(patid)) as longest_patid into :longest_patid
    from &inppl
    ;

    * grab everything that could possibly contribute to bmi ;
    create table bmi_relevant as
    select distinct case
            when p.AgeIndex lt 20 then 'Child'
            when p.AgeIndex between 20 and 80 then 'Adult'
            else 'zah?'
          end as cohort
          , v.site, v.patid length = &longest_patid
          , v.measure_date, v.ht, v.wt, v.original_bmi
    from &inppl as p INNER JOIN
          &invitals as v
    on    p.site = v.site AND
          p.patid = v.patid
    where n(v.ht, v.wt, v.original_bmi) > 0
    ;
  quit ;

  * redact out-of-range heights and weights ;
  data
    br_adult_with
    br_adult_without
    br_kid_with
    br_kid_without
  ;
    set bmi_relevant ;

    * arbitrary record identifier--guaranteed unique. ;
    rid = _n_ ;

    * Redact any OOR values of original_bmi. ;
    if n(original_bmi) and NOT (&lowbmi < original_bmi < &highbmi) then original_bmi = . ;


    * We deemed this not to be worth it--it would only redeem 3 kids out of 900 or so. ;
    * Testing out back-calculating heights where we only have wt and original_bmi ;
    * if n(wt, original_bmi) = 2 and not n(ht) then do ;
    *   back_calc_ht = sqrt((wt * 0.45)/original_bmi)/0.025 ;
    * end ;

    if n(wt) and NOT (&lowwt < wt < &highwt) then wt = . ;
    if n(ht) and NOT (&lowht < ht < &highht) then ht = . ;

    if cohort = 'Adult' then do ;
      if ht then output br_adult_with ;
      else output br_adult_without ;
    end ;

    else do ;
      if ht then output br_kid_with ;
      else output br_kid_without ;
    end ;

  run ;

  * Kid imputation is the hardest.  For every measure w/a missing height, find
  * the nearest-in-time measure with a height. ;
  proc sql ;
    * How close can we get? ;
    create table closest_height_diffs as
    select o.rid, min(abs(w.measure_date - o.measure_date)) as ht_date_difference
    from  br_kid_without as o INNER JOIN
          br_kid_with as w
    on    o.site = w.site AND
          o.patid = w.patid
    group by o.rid
    ;

    * Get the closest measure(s) for each without-height record. ;
    create table kid_imputed as
    select o.*, d.ht_date_difference, w.ht as imputed_ht, ranuni(56) as randy
    from  br_kid_without as o INNER JOIN
          closest_height_diffs as d
    on    o.rid = d.rid  INNER JOIN
          br_kid_with as w
    on    o.site = w.site AND
          o.patid = w.patid AND
          abs(w.measure_date - o.measure_date) = ht_date_difference
    order by o.site, o.patid, o.rid, CALCULATED randy
    ;

    * Remove the succesfully-imputed height recs from kid without. ;
    delete from br_kid_without
    where rid in (select rid from kid_imputed)
    ;
  quit ;

  * Its possible there was > 1 closest-in-time measure.  De-dupe ;
  data kid_imputed ;
    set kid_imputed ;
    by site patid rid ;
    if first.rid ;
    impute_type = 'near' ;
    drop rid randy ;
  run ;

  * Adults are slightly easier--its one value per. Mode if there is one, median otherwise. ;
  proc summary data = br_adult_with nway ;
    class site patid ;
    var ht ;
    output out = adult_height_imputes N=n mode( ht ) = ht_mode median( ht ) = ht_median ;
  run ;

  data adult_height_imputes ;
    set adult_height_imputes ;
    if ht_mode then do ;
      imputed_ht = ht_mode ;
      impute_type = 'mode' ;
    end ;
    else do ;
      imputed_ht = ht_median ;
      impute_type = 'medi' ;
    end ;
    keep site patid n imputed_ht impute_type ;
  run ;

  proc sql ;
    * Note that the left join here means we keep recs for adults w/no height measures at all. ;
    * We want those b/c they may have usable values of original_bmi. ;
    create table adult_imputed as
    select w.*, imputed_ht, impute_type
    from br_adult_without as w LEFT JOIN
        adult_height_imputes as i
    on    w.site = i.site AND
          w.patid = i.patid
    ;

  quit ;

  data &outset ;
    length misspat $ 4 ;
    set
      br_adult_with
      adult_imputed
      br_kid_with
      kid_imputed
      br_kid_without /* this might have usable values of original_bmi, so we keep it. */
    ;
    misspat = "____" ;

    if wt and n(ht, imputed_ht) > 0 then calc_bmi = (wt * 0.45) / ((coalesce(ht, imputed_ht) * 0.025)**2) ;
    bmi = coalesce(calc_bmi, original_bmi) ;

    if n(ht) = 0 then do ;
      if n(imputed_ht) = 1 then do ;
        ht = imputed_ht ;
        ht_is_imputed = 1 ;
        ht_impute_type = impute_type ;
      end ;
    end ;
    else ht_is_imputed = 0 ;

    * If we dont have weight on this rec, back-calculate it. ;
    if n(wt) = 0 then do ;
      if n(bmi) = 1 and n(ht) = 1 then do ;
        wt_is_calculated = 1 ;
        wt = (bmi * ((ht * 0.025)**2)) / 0.45 ;
      end ;
    end ;
    else wt_is_calculated = 0 ;

    if n(ht)            then substr(misspat, 1, 1) = 'H' ;
    if n(wt)            then substr(misspat, 2, 1) = 'W' ;
    if n(calc_bmi)      then substr(misspat, 3, 1) = 'C' ;
    if n(original_bmi)  then substr(misspat, 4, 1) = 'O' ;

    if n(bmi) and (&lowBMI < bmi < &highBMI) then output ;
    drop rid imputed_ht impute_type ;
    label
      cohort             = "Which cohort is the person for this observation in?"
      site               = "Source Data mart"
      patid              = "Patient Identifier"
      misspat            = "Pattern of Nonmissing Data"
      measure_date       = "Date the observation was made"
      ht                 = "Height in inches (possibly imputed--see ht_is_imputed)"
      wt                 = "Weight in pounds (possibly back-calculated from bmi--see wt_is_calculated)"
      original_bmi       = "A BMI measure supplied by the data mart--opaque."
      calc_bmi           = "Calculated BMI, where possible from height and weight info"
      ht_is_imputed      = "0/1 Flag signifying whether the height value was imputed from another record"
      ht_impute_type     = "Type of height imputation--mode, median, or near for kids (or missing if not imputed)"
      ht_date_difference = "No. days between the height measure used for this obs, and measure_date"
      wt_is_calculated   = "0/1 Flag signifying whether weight was back-calculated from bmi"
      bmi                = "The calculated BMI if available, or if not the value of original_bmi"
    ;
  run ;

  proc sort data = &outset ;
    by site patid measure_date ;
  run ;


%mend clean_bmi ;

options mprint ;

%macro dedupe_bmi(inset = col.clean_bmi_new, outset = col.clean_bmi_deduped) ;

  proc sql ;
    * just requiring count(*) > 1 we get 397,841 recs ;
    create table summaries as
    select site, patid, measure_date
      , count(*) as num_recs
      , min(bmi) as min_bmi
      , max(bmi) as max_bmi
      , avg(bmi) as avg_bmi
      , calculated max_bmi - calculated min_bmi as bmi_diff
    from &inset
    group by site, patid, measure_date
    having min(bmi) ne max(bmi)
    ;
  quit ;

  data &outset ;
    set &inset ;
    if _n_ = 1 then do ;
      declare hash dupes(dataset: 'summaries') ;
      dupes.definekey('site', 'patid', 'measure_date') ;
      dupes.definedata('avg_bmi', 'bmi_diff') ;
      dupes.definedone() ;
      call missing(avg_bmi, bmi_diff) ;
    end ;
    if dupes.find() = 0 then do ;
      if bmi_diff > 5 then delete ;
      else bmi = avg_bmi ;
    end ;
    drop bmi_diff avg_bmi ;
  run ;

  proc sort nodupkey data = &outset ;
    by site patid measure_date ;
  run ;
%mend dedupe_bmi ;

* %clean_bmi ;
* %dedupe_bmi ;

* endsas ;

* options orientation = landscape ;
* ods graphics / height = 8in width = 10in ;

* * %let out_folder = /C/Users/pardre1/Documents/vdw/pbs/Programs/ ;
* %let out_folder = %sysfunc(pathname(s)) ;

* ods html path = "&out_folder" (URL=NONE)
*          body   = "clean_bmi_sketch.html"
*          (title = "clean_bmi_sketch output")
*          style = magnify
*          nogfootnote
*           ;

* ods rtf file = "&out_folder./clean_bmi_sketch.rtf" device = sasemf ;

* proc freq data = col.clean_bmi_new order = freq ;
*   tables misspat * cohort / missing format = comma9.0 ;
* run ;


* run ;

* ods _all_ close ;


