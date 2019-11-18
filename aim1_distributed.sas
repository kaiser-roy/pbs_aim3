/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* C:\Users/pardre1/Documents/vdw/pbs/Programs/aim1_distributed.sas
*
* Recreates the wrangling steps from the Aim 3 consolidated analysis, to
* set the stage for Darren Tohs distributed analysis.
* Modeled after:
*   aim1_individual_collate.sas
*   aim1_descriptives.sas
*   aim1_make_analytic.sas
*********************************************/
%include "h:/SAS/Scripts/remoteactivate.sas" ;

options
  linesize  = 150
  msglevel  = i
  formchar  = '|-++++++++++=|-/|<>*'
  dsoptions = note2err
  nocenter
  noovp
  nosqlremerge
  options extendobscounter = no ;
;

%let days_per_month = 30.4 ;

%let root = \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming ;

libname raw    "&root\Data\aim3_individual\raw" ;
libname col    "&root\Data\aim3_individual\collated" ;
libname digested "&root\Data\aim3_individual\collated\digested" ;
libname analytic "&root\Data\aim3_individual\collated\digested\analytic" ;
libname ref      "&root\data\aim3_individual\collated\reference" ;

%include "&root/programs/formats.sas" ;
%include "&root/programs/clean_bmi.sas" ;
%include "&root\Programs\PCORNET\distributed_aim1\infolder\macros\ms_processwildcards.sas" ;

%macro make_contents(lib = , dset = ) ;

  ods html
    path = "%sysfunc(pathname(&lib))"
    (URL = NONE)
    body = "&dset..html"
    (title= "&dset")
    stylesheet=(URL='http://datawranglr.com/assets/css/light_on_dark.css')
  ;
    title "Contents of &dset" ;
    proc contents data = &lib..&dset varnum ;
    proc print data = &lib..&dset(obs = 20) ;
    run ;

  ods html close ;
%mend make_contents ;

%macro process(inlib = , nom = , outlib =, sortvars = %str(site patid), with_ndcm = 0) ;
  %if &with_ndcm = 1 %then %do ;
    %stack_datasets(inlib = &inlib, nom = &nom    , outlib = work) ;
    %stack_datasets(inlib = &inlib, nom = ncdm&nom, outlib = work) ;
    data &outlib..&nom ;
      set
        &nom
        ncdm&nom (in = n)
      ;
      if n then src = 'NCDM' ;
      else src = 'CDM' ;
    run ;
  %end ;
  %else %do ;
    %stack_datasets(inlib = &inlib, nom = &nom, outlib = &outlib) ;
  %end ;

  data &outlib..&nom ;
    set &outlib..&nom ;
    site_name = put(site, $site.) ;
    %if %index(&sortvars, patid) > 0 %then %do ;
      patid = trim(strip(patid)) ; * <-- obviating some weirdness we had w/noseeums on the aim 1 data. ;
    %end ;
  run ;

  proc sort data = &outlib..&nom ;
    by &sortvars ;
  run ;
  %make_contents(lib = &outlib, dset = &nom) ;
%mend process ;

%macro regen ;
  %process(inlib = raw, nom = attrition                , outlib = col, sortvars = site) ;
  %process(inlib = raw, nom = cohortdeath              , outlib = col, with_ndcm = 1) ;
  %process(inlib = raw, nom = cohortdeathcause         , outlib = col, with_ndcm = 1) ;
  %process(inlib = raw, nom = cohortdemog              , outlib = col) ;
  %process(inlib = raw, nom = cohortdx                 , outlib = col, with_ndcm = 1) ;
  %process(inlib = raw, nom = cohortdxcci              , outlib = col) ;
  %process(inlib = raw, nom = cohortencounter          , outlib = col, with_ndcm = 1) ;
  %process(inlib = raw, nom = cohortenrollment         , outlib = col) ;
  %process(inlib = raw, nom = cohortharvest            , outlib = col, sortvars = site) ;
  %process(inlib = raw, nom = cohortpx                 , outlib = col, with_ndcm = 1) ;
  %process(inlib = raw, nom = signature                , outlib = col, sortvars = site) ;
  %process(inlib = raw, nom = cohortpxinclcodespxindex , outlib = col) ;
  %process(inlib = raw, nom = cohortvital              , outlib = col, sortvars = %str(site patid measure_date)) ;

  %clean_bmi(inppl = col.cohortdemog, invitals = col.cohortvital, outset = col.clean_bmis) ;
  %dedupe_bmi(inset = col.clean_bmis, outset = col.deduped_bmis) ;
%mend regen ;

%macro get_people(outset = digested.people, from_scratch = 0) ;

  proc sql noprint ;

    /*
      'Native'
      'Asian'
      'Black'
      'Pac Islander'
      'White'
      'Multiple'
      'Other'
      'Refuse/No info/Unknown'
    */

    create table r1 as
    select patid label = "Patient ID"
        , site label = "CDRN Site"
        , AgeIndex label = "Age at index surgery"
        , sex
        , hispanic label = "Hispanic ethnicity?"
        , put(race, $race.) as race
        , 1 as row01 length = 3 label = "01. Age 20-80 at surgery"
        , case
            when AgeIndex lt 20 then 'Child'
            when AgeIndex between 20 and 80 then 'Adult'
            else 'zah?'
          end as cohort
        , (sex = 'F')                                     as row41  label = "41. Are female"
        , (hispanic = 'Y')                                as row42a label = "42a. Are Hispanic"
        , (hispanic = 'N')                                as row42b label = "42b. Not Hispanic"
        , (hispanic not in ('Y','N'))                     as row42c label = "42c. Hispanic ethnicity not known"
        , (put(race, $race.) = 'White')                   as row43 label = "43. White"
        , (put(race, $race.) = 'Black')                   as row44 label = "44. Black/African American"
        , (put(race, $race.) = 'Asian')                   as row45 label = "45. Asian"
        , (put(race, $race.) = 'Native')                  as row45a label = "45a. Native American/Alaskan Native"
        , (put(race, $race.) = 'Pac Islander')            as row45b label = "45b. Hawaiian/Pacific Islander"
        , (put(race, $race.) = 'Multiple')                as row45c label = "45c. Multi-race"
        , (put(race, $race.) = 'Other')                   as row46  label = "46. Other race"
        , (put(race, $race.) = 'Refuse/No info/Unknown')  as row46a label = "46a. No info/refused/unknown race"
        , (hispanic = 'UN' and put(race, $race.) = 'Refuse/No info/Unknown') as row47 label = "47. Ethnicity & Race both missing"
        , (AgeIndex lt 13)        as row49c   label = "49. Age < 13"
        , (13 le AgeIndex le 15)  as row50c   label = "50. Age between 13 and 15"
        , (16 le AgeIndex le 17)  as row51c   label = "51. Age between 16 and 17"
        , (18 le AgeIndex le 19)  as row51c2  label = "51. Age between 18 and 19"
        , (20 le AgeIndex le 44)  as row49    label = "49. Age between 20 and 44"
        , (45 le AgeIndex le 64)  as row50    label = "50. Age between 45 and 64"
        , (65 le AgeIndex le 80)  as row51    label = "51. Age between 65 and 80"

    from col.cohortdemog
    ;

    create table year_bmis as
    select cv.patid, cv.site
          , max(bmi) as max_orig_bmi/* , min(measure_date) as bl_meas_date */
          , min(bmi) as min_orig_bmi/* , min(measure_date) as bl_meas_date */
    from col.deduped_bmis as cv INNER JOIN
          r1
    on    cv.site= r1.site AND
          cv.patid = r1.patid
    where bmi is not null AND
          measure_date between -364 and 0
    group by cv.patid, cv.site
    ;

    /*
      % BMI 35-39.9 (maximum in year beforre surgery)
      % BMI 40-49.9 (maximum in year before surgery)
      % BMI 50-59.9 (maximum in year before surgery)
      % BMI 60+ (maximum in year before surgery)
    */
    create table penultimate as
    select r.*
          , (not y.patid is null) as row02 length = 3 label = "02. Had BMI in year prior to surgery (based on bmi_calc for adults, provisional_bmi for kids)"
          , (max_orig_bmi ge 35)  as row03 length = 3 label = "03. Had BMI 35+ in year prior (based on bmi_calc for adults, provisional_bmi for kids)"
          , max_orig_bmi label = "58. Maximum BMI in year prior to surgery"
          , min_orig_bmi label = "Minimum BMI in year prior to surgery"
          , (35.0 lt max_orig_bmi lt 39.9) as row59 label = "59. Max BMI in year prior to surgery 35-39.9"
          , (39.9 lt max_orig_bmi lt 49.9) as row60 label = "60. Max BMI in year prior to surgery 40-49.9"
          , (49.9 lt max_orig_bmi lt 59.9) as row61 label = "61. Max BMI in year prior to surgery 50-59.9"
          , (max_orig_bmi > 59.9)          as row62 label = "62. Max BMI in year prior to surgery 60+"
    from r1 as r LEFT JOIN
        year_bmis as y
    on  r.patid = y.patid AND
        r.site = y.site
    order by patid, site
    ;

  quit ;

  %if &from_scratch = 1 %then %do ;
    data &outset ;
      set penultimate ;
    run ;
  %end ;
  %else %do ;

    options dkricond = nowarn ;

    data &outset ;
      merge
        &outset (drop = AgeIndex
                      cohort
                      hispanic
                      max_orig_bmi
                      min_orig_bmi
                      race
                      row01-row03
                      row41-row47
                      row49
                      row49c
                      row50
                      row50c
                      row51
                      row51c
                      row51c2
                      row59-row62
                      sex
                      row42a
                      row42b
                      row42c
                      row45a
                      row45b
                      row45c
                      row46
                      row46a
                      row49c
                      row50c
                      row51c
                      row51c2
                      )
        penultimate
      ;
      by patid site ;
    run ;

    options dkricond = warn ;
  %end ;
%mend get_people ;

%macro get_bs_enc(inset = digested.people, outset = digested.bar_surgs) ;
  * Gets the bariatric surgery encounters/determines surgery type. ;
  proc sql noprint ;
    create table grist as
    select e.site
          , e.patid
          , coalesce(p.px_date, p.admit_date) as surg_year label = "Year of Surgery"
          , p.px_group as surg_type label = "Type of Surgery"
          , e.enc_type as surg_enc_type label = "Surgery Encounter Type"
          , (e.admit_date <= 0 <= coalesce(e.discharge_date, 0)) as embraces_zero
    from  col.cohortencounter as e INNER JOIN
          col.cohortpxinclcodespxindex as p
    on    e.site = p.site AND
          e.encounterid = p.encounterid
    where p.px_group in ('RYGB', 'SG', 'AGB')
    order by e.site, e.patid
            , CALCULATED embraces_zero DESC
            , put(e.enc_type, $etrank.)
            , e.discharge_date DESC
            , p.px_group
    ;
  quit ;

  data &outset ;
    set grist ;
    by site patid surg_year ;

    row04 = (surg_enc_type = 'IP') ;
    row05 = (surg_enc_type = 'AV') ;

    row06 = (surg_enc_type not in ('IP', 'AV')) ;

    row07 = (surg_type = 'SG') ;
    row08 = (surg_type = 'RYGB') ;
    row09 = (surg_type = 'AGB') ;

    row10 = (row05 and row07) ;
    row11 = (row05 and row08) ;
    row12 = (row05 and row09) ;

    row13 = (surg_year = 2005) ;
    row14 = (surg_year = 2006) ;
    row15 = (surg_year = 2007) ;
    row16 = (surg_year = 2008) ;
    row17 = (surg_year = 2009) ;
    row18 = (surg_year = 2010) ;
    row19 = (surg_year = 2011) ;
    row20 = (surg_year = 2012) ;
    row21 = (surg_year = 2013) ;
    row22 = (surg_year = 2014) ;
    row23 = (surg_year = 2015) ;

    /*
      row 27: surgery yr 2014 or earlier (eligible for 1 yr time window) Study end date 9/30/2015
      row 30: surgery yr 2012 or earlier (eligible for 3 yr time window)
      row 33: surgery yr 2010 or earlier (eligible for 5 yr time window)

      row 24: any BMI post surgery

      row 25: any BMI 6-18 months post surgery
      row 26: any BMI >6 months post surgery
      row 28: any BMI 30-42 months post surgery
      row 29: any BMI >30 months post surgery
      row 31: any BMI 54-66 months post surgery
      row 32: any BMI >54 months post surgery

    */

    row27 = (surg_year le 2014) ;
    row30 = (surg_year le 2012) ;
    row33 = (surg_year le 2010) ;


    if first.surg_year then output ;
    label
      row04 = "04. Index surgery enc_type was IP"
      row05 = "05. Index surgery enc_type was AV"
      row06 = "06. Index surgery enc_type was Other (neither IP nor AV)"
      row07 = "07. Index surgery type was SG"
      row08 = "08. Index surgery type was RYGB"
      row09 = "09. Index surgery type was AGB"
      row10 = "10. Index surgery was SG at AV encounter"
      row11 = "11. Index surgery was RYGB at AV encounter"
      row12 = "12. Index surgery was AGB at AV encounter"
      row13 = "13. Index surgery happened in 2005"
      row14 = "14. Index surgery happened in 2006"
      row15 = "15. Index surgery happened in 2007"
      row16 = "16. Index surgery happened in 2008"
      row17 = "17. Index surgery happened in 2009"
      row18 = "18. Index surgery happened in 2010"
      row19 = "19. Index surgery happened in 2011"
      row20 = "20. Index surgery happened in 2012"
      row21 = "21. Index surgery happened in 2013"
      row22 = "22. Index surgery happened in 2014"
      row23 = "23. Index surgery happened in 2015"
      row27 = "27. Surgery year 2014 or earlier (elig for 1 year time window)"
      row30 = "30. Surgery year 2012 or earlier (elig for 3 year time window)"
      row33 = "33. Surgery year 2010 or earlier (elig for 5 year time window)"
    ;
  run ;

  %put INFO: FINDME: SHOULD BE NO DUPES HERE!!! ;
  proc sort nodupkey data = &outset ;
    by patid site ;
  run ;

  options dkricond = nowarn ;

  data &inset ;
    merge
      &inset (drop = row04-row33)
      &outset
    ;
    by patid site ;
  run ;

  options dkricond = warn ;
%mend get_bs_enc ;

%macro get_bmi_times(inset = digested.people, inbmis = col.deduped_bmis) ;
  proc sql ;
    create table grist as
    select a.site
          , a.patid
          , bmi
          , ht
          , wt
          , measure_date
          , (v.measure_date / &days_per_month) as measure_month label = "Measure date / &days_per_month"
    from  &inbmis as v INNER JOIN
          &inset as a
    on    v.site = a.site AND
          v.patid = a.patid
    where bmi IS NOT NULL
    order by site, patid
    ;

    create table bl_bmi_dates as
    select site, patid, max(measure_date) as bl_meas_date
    from grist
    where measure_date between -364 and 0
    group by site, patid
    ;

    /*
      % BMI <35 (closest to surgery) at baseline
      % BMI 35-39.9 (closest to surgery) at baseline
      % BMI 40-49.9 (closest to surgery) at baseline
      % BMI 50-59.9 (closest to surgery) at baseline
      % BMI 60+ (closest to surgery) at baseline

    */

    create table bl_bmis as
    select o.site, o.patid
          , o.bmi as bl_bmi
          , (o.bmi < 35)            as row53 label = "53. BMI <35 (closest to surgery) at baseline"
          , (35.0 lt o.bmi lt 39.9) as row54 label = "54. BMI 35-39.9 (closest to surgery) at baseline"
          , (39.9 lt o.bmi lt 49.9) as row55 label = "55. BMI 40-49.9 (closest to surgery) at baseline"
          , (49.9 lt o.bmi lt 59.9) as row56 label = "56. BMI 50-59.9 (closest to surgery) at baseline"
          , (o.bmi > 59.9)          as row57 label = "57. BMI 60+ (closest to surgery) at baseline"
          , o.measure_date as bl_bmi_date
          , o.ht as bl_ht
          , o.wt as bl_wt
    from  grist as o INNER JOIN
          bl_bmi_dates as d
    on    o.site = d.site AND
          o.patid = d.patid AND
          o.measure_date = d.bl_meas_date
    ;

    create table sumz as
    select site, patid
      , 1 as row24
      , max(case when measure_month between 6 and 18 then 1 else 0 end) as row25
      , max(case when measure_month > 6 then 1 else 0 end) as row26
      , max(case when measure_month between 30 and 42 then 1 else 0 end) as row28
      , max(case when measure_month > 30 then 1 else 0 end) as row29
      , max(case when measure_month between 54 and 66 then 1 else 0 end) as row31
      , max(case when measure_month > 54 then 1 else 0 end) as row32
    from grist
    where measure_date > 0
    group by site, patid
    ;
  quit ;

  proc sort nodupkey data = sumz ;
    by patid site ;
  run ;

  %put INFO: FINDME: SHOULD BE NO DUPES HERE!!! ;
  proc sort nodupkey data = bl_bmis ;
    by patid site ;
  run ;

  options dkricond = nowarn ;

  data &inset ;
    merge
      &inset (drop = row24 row25 row26 row28 row29 row31 row32 row53-row57 bl_bmi bl_bmi_date)
      sumz
      bl_bmis
    ;
    by patid site ;
    array m row24 row25 row26 row28 row29 row31 row32 row53-row57 ;
    do i = 1 to dim(m) ;
      if m{i} = . then m{i} = 0 ;
    end ;
    label
      row24 = "24. Had any BMI measure post-surgery"
      row25 = "25. Had a BMI measure between 6 and 18 months post-surgery"
      row26 = "26. Had a BMI measure more than 6 months post-surgery"
      row28 = "28. Had a BMI measure between 30 and 42 months post-surgery"
      row29 = "29. Had a BMI measure more than 30 months post-surgery"
      row31 = "31. Had a BMI measure between 54 and 66 months post-surgery"
      row32 = "32. Had a BMI measure more than 54 months post-surgery"
      bl_bmi = "52. Baseline BMI: pre-surgery measure nearest in time to surgery"
      bl_bmi_date = "Date of Baseline BMI"
      bl_wt = "Weight at baseline"
      bl_ht = "Height at baseline"
    ;
  run ;

  options dkricond = warn ;
%mend get_bmi_times ;

%macro get_contacts(inset = digested.people, outset = digested.contacts) ;

  /*
    any diagnosis, procedure, BP, or AV visit:
      row34 = post surgery (observed after surgery)
      row35 = 6-18 mos post surgery (observed in 1 yr window)
      row36 = >6 mos post surgery
      row37 = 30-42 mos post surgery (observed in 3 yr window)
      row38 = >30 mos post surgery
      row39 = 54-66 mos post surgery (observed in 5 yr window)
      row40 = >54 mos post surgery
  */

  proc sql ;
    create table &outset as
    select site, patid, (measure_date / &days_per_month) as contact_month, 'bp' as source
    from col.cohortvital
    where systolic or diastolic
    UNION ALL
    select site, patid, (admit_date / &days_per_month) as contact_month, 'av'
    from col.cohortencounter
    where enc_type = 'AV'
    ;

    create table sumz as
    select site, patid
      , 1 as row34
      , max(case when contact_month between 6 and 18 then 1 else 0 end) as row35
      , max(case when contact_month > 6 then 1 else 0 end) as row36
      , max(case when contact_month between 30 and 42 then 1 else 0 end) as row37
      , max(case when contact_month > 30 then 1 else 0 end) as row38
      , max(case when contact_month between 54 and 66 then 1 else 0 end) as row39
      , max(case when contact_month > 54 then 1 else 0 end) as row40
    from &outset
    group by site, patid
    ;
  quit ;

  proc sort data = sumz ;
    by patid site ;
  run ;

  options dkricond = nowarn ;

  data &inset ;
    merge
      &inset (drop = row34-row40)
      sumz
    ;
    by patid site ;
    array cn row34 - row40 ;
    do i = 1 to dim(cn) ;
      if cn{i} = . then cn{i} = 0 ;
    end ;
    drop i ;
    label
      row34 = "34. Had any AV encounter or BP measurement post-surgery"
      row35 = "35. Had a AV encounter or BP measurement between 6 and 18 months post-surgery"
      row36 = "36. Had a AV encounter or BP measurement more than 6 months post-surgery"
      row37 = "37. Had a AV encounter or BP measurement between 30 and 42 months post-surgery"
      row38 = "38. Had a AV encounter or BP measurement more than 30 months post-surgery"
      row39 = "39. Had a AV encounter or BP measurement between 54 and 66 months post-surgery"
      row40 = "40. Had a AV encounter or BP measurement more than 54 months post-surgery"
    ;
  run ;

  options dkricond = warn ;
%mend get_contacts ;

%macro dedupe_bps(inset = , outset = ) ;
  * fields are site, patid, measure_date, systolic, diastolic ;
  proc sql ;
    * just requiring count(*) > 1 we get 397,841 recs ;
    create table summaries as
    select site, patid, measure_date
      , count(*) as num_recs
      , min(systolic)  as min_systolic
      , max(systolic)  as max_systolic
      , avg(systolic)  as avg_systolic
      , min(diastolic) as min_diastolic
      , max(diastolic) as max_diastolic
      , avg(diastolic) as avg_diastolic
      , calculated max_systolic - calculated min_systolic as systolic_diff
      , calculated max_diastolic - calculated min_diastolic as diastolic_diff
    from &inset
    group by site, patid, measure_date
    having min(systolic)  ne max(systolic)  OR
           min(diastolic) ne max(diastolic)
    ;
  quit ;

  data &outset ;
    set &inset ;
    if _n_ = 1 then do ;
      declare hash dupes(dataset: 'summaries') ;
      dupes.definekey('site', 'patid', 'measure_date') ;
      dupes.definedata('avg_systolic', 'systolic_diff', 'avg_diastolic', 'diastolic_diff') ;
      dupes.definedone() ;
      call missing(avg_systolic, systolic_diff, avg_diastolic, diastolic_diff) ;
    end ;
    if dupes.find() = 0 then do ;
      if diastolic_diff > 10 or systolic_diff > 10 then delete ;
      else do;
        systolic  = round(avg_systolic , .1) ;
        diastolic = round(avg_diastolic, .1) ;
      end ;
    end ;
    drop avg_systolic systolic_diff avg_diastolic diastolic_diff ;
  run ;

  proc sort nodupkey data = &outset ;
    by site patid measure_date ;
  run ;
%mend dedupe_bps ;

%macro potpourri(inset = sts.people) ;
  /*
    % missing systolic blood pressure in year before surgery (includes day of surgery)
    mean systolic blood pressure (closest to surgery)
    % missing diastolic blood pressure in year before surgery (includes day of surgery)
    mean diastolic blood pressure (closest to surgery)
    mean Charlson-Elixhauser score in year before surgery
    mean number of IP hospital days in year before surgery
  */
  proc sql ;
    create table grist as
    select site, patid
          , intck('days', max(admit_date, -365), min(discharge_date, -1)) + 1 as ip_days
    from col.cohortencounter
    where enc_type = 'IP' AND discharge_date > -365 and admit_date < -1
    order by patid, site
    ;
    create table ip_days as
    select site, patid, sum(ip_days) as ip_days label = "68. Total IP days"
    from grist
    group by site, patid
    ;

    drop table grist ;

    create table bps as
    select site, patid, measure_date, systolic, diastolic
    from col.cohortvital
    where measure_date between -365 and 1 AND (systolic or diastolic)
    ;
  quit ;

  %dedupe_bps(inset = bps, outset = deduped_bps) ;

  proc sql noprint ;
    drop table bps ;
    create table diadates as
    select site, patid, max(measure_date) as dia_date
    from deduped_bps
    where diastolic
    group by site, patid
    ;

    create table diastolics as
    select b.site, b.patid, b.diastolic, dia_date
    from  deduped_bps as b INNER JOIN
          diadates as d
    on    b.site = d.site AND
          b.patid = d.patid AND
          b.measure_date = d.dia_date
    order by b.site, b.patid
    ;
    create table sydates as
    select site, patid, max(measure_date) as sy_date
    from deduped_bps
    where systolic
    group by site, patid
    ;

    create table systolics as
    select b.site, b.patid, b.systolic, sy_date
    from  deduped_bps as b INNER JOIN
          sydates as d
    on    b.site = d.site AND
          b.patid = d.patid AND
          b.measure_date = d.sy_date
    order by b.site, b.patid
    ;

    create table vital_smokers as
    select distinct site, patid, 1 as vital_smoker
    from col.cohortvital
    where measure_date between -365 and -1 AND
          put(smoking, $smofilt.) = "smoker"
    order by site, patid
    ;

    drop table deduped_bps ;
    drop table diadates ;
    drop table sydates ;
  quit ;

  proc sort data = ip_days ;
    by patid site ;
  run ;

  proc sort nodupkey data = diastolics ;
    by patid site ;
  run ;

  proc sort nodupkey data = systolics ;
    by patid site ;
  run ;

  proc sort nodupkey data = vital_smokers ;
    by patid site ;
  run ;

  proc sort data = col.cohortdxcci out = chron ;
    by patid site ;
  run ;

  options dkricond = nowarn ;

  data &inset ;
    merge
      &inset (drop = row63 row65 systolic diastolic sy_date dia_date
                      pcombined_score pcombined_score_num
                      ccielixgrp ip_days
                      num_PVD
                      num_Liver
                      score_inflation
                      vital_smoker)
      ip_days
      diastolics
      systolics
      chron
      vital_smokers
    ;
    by patid site ;
    row63 = (n(systolic) = 0) ;
    row65 = (n(diastolic) = 0) ;
    array m ip_days vital_smoker ;
    do i = 1 to dim(m) ;
      if m{i} = . then m{i} = 0 ;
    end ;
    drop i ;
    label
      row63               = "63. Missing systolic blood pressure in year before surgery"
      row65               = "65. Missing diastolic blood pressure in year before surgery"
      systolic            = "64. Pre-surgery systolic BP measure closest to day of surgery"
      diastolic           = "66. Pre-surgery diastolic BP measure closest to day of surgery"
      sy_date             = "Date of the measurment in var systolic"
      dia_date            = "Date of the measurment in var diastolic"
      pcombined_score     = 'Prior Combined comorbidity score'
      pcombined_score_num = '67. Prior Combined comorbidity raw score'
      ccielixgrp          = "? not sure what this is--from cohortdxcci ?"
      vital_smoker        = "Had a smoker-indicating vital sign measure in the year prior to surgery"
    ;
  run ;
%mend potpourri ;

%macro diseases(inset = digested.people, outset = digested.dx_counts) ;
  data obcodes ;
    set
      ref.obesitycodes
      ref.dvtcodes (rename = (code_cat = codecat
                             code_type = codetype))
      ref.pedspecialcodes (in = p)
    ;
    code = compress(code, '. ') ;
    if ^p then disease_category = lowcase(group) ;
    else disease_category = put(code, $peddx.) ;
  run ;

  %ms_processwildcards(InFile=obcodes, CodeVar=Code, CodeType=CodeType, OutFile=obesitycodes);

  proc sql ;
    create table &outset as
    select site, patid, disease_category, count(distinct admit_date) as num_dx
    from col.cohortdx as d INNER JOIN
          obesitycodes as o
    on    d.dx = o.code AND
          d.dx_type = o.CodeType
    where (admit_date between -365 and 0) OR
          (admit_date between -365 and -1 AND disease_category in ('cvd', 'cerebvascd')) /* AND site = 'C5GH'  */
    group by site, patid, disease_category
    ;

    * Making sure we have one of each disease event so we get full output from transpose below. ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'anxiety'        , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'aspergers'      , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'bardet_biedl'   , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'cancer'         , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'cerebvascd'     , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'cvd'            , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'depression'     , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'diabetes'       , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'downs'          , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'dvt'            , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'dyslipidemia'   , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'eatingdisorder' , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'epiphysis'      , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'gerd'           , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'hypertension'   , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'infertility'    , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'kidneydisease'  , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'nafld'          , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'osteoarthritis' , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'oth_misc'       , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'pe'             , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'polycovaries'   , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'prader_willi'   , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'psychoses'      , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'sleepapnea'     , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'substuse'       , 0) ;
    insert into &outset (site, patid, disease_category, num_dx) values ('NOSUCH', 'SANTA', 'tobaccouse'     , 0) ;

  quit ;

  proc transpose data = &outset out = tposed (drop = _:) prefix = num_ ;
    var num_dx ;
    id disease_category ;
    by site patid ;
  run ;

  data tposed ;
    set tposed ;
    if site ^= 'NOSUCH' ;
  run ;

  proc sort data = tposed ;
    by patid site ;
  run ;

  options dkricond = nowarn ;

  proc sort data = &inset out = ppl ;
    by patid site ;
  run ;

  data &inset ;
    merge
      ppl (drop =   num_diabetes
                    num_gerd
                    num_hypertension
                    num_sleepapnea
                    num_cancer
                    num_depression
                    num_nafld
                    num_osteoarthritis
                    num_cvd
                    num_dyslipidemia
                    num_cerebvascd
                    num_kidneydisease
                    num_tobaccouse
                    num_anxiety
                    num_eatingdisorder
                    num_infertility
                    num_psychoses
                    num_substuse
                    num_polycovaries
                    num_pe
                    num_dvt
                    num_downs
                    num_epiphysis
                    num_oth_misc
                    num_prader_willi
                    num_aspergers
                    num_bardet_biedl
                    )
      tposed
    ;
    by patid site ;

    array n num_: ;
    do i = 1 to dim(n) ;
      n{i} = (n{i} > 0) ;
    end ;
    drop i ;

    label
      num_diabetes       = "Diabetes dx at baseline"
      num_gerd           = "GERD dx at baseline"
      num_hypertension   = "Hypertension dx at baseline"
      num_sleepapnea     = "Sleepapnea dx at baseline"
      num_cancer         = "Cancer dx at baseline"
      num_depression     = "Depression dx at baseline"
      num_nafld          = "NAFLD dx at baseline"
      num_osteoarthritis = "Osteoarthritis dx at baseline"
      num_cvd            = "CVD dx at baseline"
      num_dyslipidemia   = "Dyslipidemia dx at baseline"
      num_cerebvascd     = "Cerebvascd dx at baseline"
      num_kidneydisease  = "Kidneydisease dx at baseline"
      num_tobaccouse     = "Tobaccouse dx at baseline"
      num_anxiety        = "Anxiety dx at baseline"
      num_eatingdisorder = "Eatingdisorder dx at baseline"
      num_infertility    = "Infertility dx at baseline"
      num_psychoses      = "Psychoses dx at baseline"
      num_substuse       = "Substuse dx at baseline"
      num_polycovaries   = "Polycovaries dx at baseline"
      num_pe             = "PE dx at baseline"
      num_dvt            = "DVT dx at baseline"
    ;
  run ;
%mend diseases ;

%macro censor_bmis(inppl    = digested.people
                  , inbmis  = col.deduped_bmis
                  , inpx    = col.cohortpx
                  , indx    = col.cohortdx
                  , outbmis = digested.censored_clean_bmis) ;
  * see $repo\Programs\censor_outcomes.sas for rationale/instructions for censoring. ;

  proc sql ;
    * find revisions. ;
    create table surg_events as
    select  p.site
          , p.patid
          , p.px_group
          , min(coalesce(p.px_date, p.admit_date)) as event_date
    from &inpx as p INNER JOIN
          &inppl as c
    on    p.site = c.site AND
          p.patid = c.patid
    where p.px_group in ('AGB', 'SG', 'RYGB'/* , 'PREGNANCY' */) AND
          p.px_group ne c.surg_type AND
          coalesce(p.px_date, p.admit_date) > 0
    group by p.site, p.patid, p.px_group
    order by p.site, p.patid, p.px_group
    ;

    * Could be > 1 rec/person on this ;
    create table preg_px_events as
    select distinct p.site
          , p.patid
          , 'preg_px' as px_group
          , coalesce(p.px_date, p.admit_date) as event_date
    from  &inpx as p INNER JOIN
          ref.preg_px as pp
    on    p.px = compress(pp.px, '. ') AND
          p.px_type = put(pp.px_codetype, $pt.)
    where coalesce(p.px_date, p.admit_date) > 0
    order by 1, 2, 3, 4
    ;

    create table preg_dx_events as
    select distinct d.site
            , d.patid
            , 'preg_dx' as px_group
            , d.admit_date as event_date
    from  &indx as d INNER JOIN
          ref.preg_dx as pd
    on    d.dx = compress(pd.dx, '. ')
    where d.admit_date > 0
    order by 1, 2, 3, 4
    ;

  quit ;

  %local infinite_date ;
  %let infinite_date = 99999999999 ;

  data censor_events ;
    set
      surg_events
      preg_px_events
      preg_dx_events
    ;

    if px_group in ('preg_px', 'preg_dx') then do ;
      censor_begin = max(0, (event_date - 270)) ;
      censor_end = event_date + 90 ;
    end ;
    else do ;
      censor_begin = event_date ;
      censor_end = &infinite_date ;
    end ;
  run ;

  proc sort nodupkey data = censor_events ;
    by site patid censor_begin censor_end ;
  run ;

  data usable_bmis ;
    set &inbmis ;
    rid = _n_ ;
    measure_month = (measure_date / &days_per_month) ;
  run ;

  proc sql ;
    create table censored_bmis as
    select distinct b.rid
    from  usable_bmis as b INNER JOIN
          censor_events as c
    on    b.site = c.site AND
          b.patid = c.patid AND
          b.measure_date between c.censor_begin and c.censor_end
    ;

    create table &outbmis(drop = rid) as
    select b.*, (not c.rid is null) as censored length = 3 label = "Was this measure taken post-different-surgery or during possible pregnancy?"
    from  usable_bmis as b LEFT JOIN
          censored_bmis as c
    on    b.rid = c.rid
    order by b.site, b.patid
    ;

    create table sumz as
    select site, patid
      , 1                                                                 as crow24
      , max(case when measure_month between 6 and 18 then 1 else 0 end)   as crow25
      , max(case when measure_month > 6 then 1 else 0 end)                as crow26
      , max(case when measure_month between 30 and 42 then 1 else 0 end)  as crow28
      , max(case when measure_month > 30 then 1 else 0 end)               as crow29
      , max(case when measure_month between 54 and 66 then 1 else 0 end)  as crow31
      , max(case when measure_month > 54 then 1 else 0 end)               as crow32
    from &outbmis
    where measure_date > 0 AND
          censored = 0
    group by patid, site
    order by patid, site
    ;
  quit ;

  options dkricond = nowarn ;

  data &inppl ;
    merge
      &inppl (drop = crow24 crow25 crow26 crow28 crow29 crow31 crow32)
      sumz
    ;
    by patid site ;
    array m crow24 crow25 crow26 crow28 crow29 crow31 crow32 ;
    do i = 1 to dim(m) ;
      if m{i} = . then m{i} = 0 ;
    end ;
    label
      crow24 = "CENSORED 24. Had any BMI measure post-surgery"
      crow25 = "CENSORED 25. Had a BMI measure between 6 and 18 months post-surgery"
      crow26 = "CENSORED 26. Had a BMI measure more than 6 months post-surgery"
      crow28 = "CENSORED 28. Had a BMI measure between 30 and 42 months post-surgery"
      crow29 = "CENSORED 29. Had a BMI measure more than 30 months post-surgery"
      crow31 = "CENSORED 31. Had a BMI measure between 54 and 66 months post-surgery"
      crow32 = "CENSORED 32. Had a BMI measure more than 54 months post-surgery"
    ;
  run ;

  options dkricond = warn ;
%mend censor_bmis ;

%macro get_heights(inbmis = digested.censored_clean_bmis, inppl = digested.people, extrawh = %str(and not censored)) ;
  * Yates wants height measures at the 1, 3 & 5 year marks (near as can be had) for the ;
  * child analysis.  Do for all, and do censored and uncensored versions. ;

  data sought_timepoints ;
    * 365, 1095 and 1825 days respectively ;
    day = 365 ;
    output ;
    day = 1095 ;
    output ;
    day = 1825 ;
    output ;
  run ;

  proc sql ; * outobs = 300 nowarn ;
    * How close can we get? ;
    create table closest_height_diffs as
    select b.site, b.patid, t.day, min(abs(b.measure_date - t.day)) as ht_date_difference
    from &inbmis as b CROSS JOIN
          sought_timepoints as t
    where ht is not null &extrawh
    group by b.site, b.patid, t.day
    ;
    create table candidate_heights as
    select b.site, b.patid, d.day, b.ht, b.wt, b.bmi, b.measure_date, ranuni(900) as randy
    from  &inbmis as b INNER JOIN
          closest_height_diffs as d
    on    b.site = d.site AND
          b.patid = d.patid AND
          abs(b.measure_date - d.day) = d.ht_date_difference
    order by b.site, b.patid, d.day, CALCULATED randy
    ;
  quit ;

  * Dedupe. ;
  data height_measures ;
    set candidate_heights ;
    by site patid day ;
    if first.day ;
  run ;

  proc transpose data = height_measures out = tposed (drop = _:) prefix = ht_ ;
    var ht ;
    id day ;
    by site patid ;
  run ;

  proc sort data = tposed ;
    by patid site ;
  run ;

  options dkricond = nowarn ;

  %if %length(&extrawh) > 0 %then %do ;
    %let suff = _c ;
  %end ;
  %else %do ;
    %let suff = ;
  %end ;

  data &inppl ;
    merge
      &inppl
      tposed
    ;
    by patid site ;
    ht_1year&suff = ht_365 ;
    ht_3year&suff = ht_1095 ;
    ht_5year&suff = ht_1825 ;
    drop ht_365 ht_1095 ht_1825 ;
  run ;
%mend get_heights ;

%macro report(inset = digested.people, cohort = Adult) ;

  ods listing close ;

  options orientation = landscape ;
  ods graphics / height = 8in width = 10in ;
  %let out_folder = \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\output ;

  ods html path = "&out_folder" (URL=NONE)
           body   = "aim3_descriptives_&cohort..html"
           (title = "PBS Aim 3 Descriptives--&cohort")
           style = magnify
           nogfootnote
            ;

    title1 "&Cohort Cohort" ;

    %let tabopts = format = comma9.0 order = formatted ;

    proc tabulate data =&inset &tabopts ;
      class site surg_type ;
      var row01-row03 ;
      tables (row01-row03)*sum="", (site surg_type) all = "Total All Sites" / misstext = '0' ;
      format site $site. ;
      where cohort = "&cohort" ;
    run ;

    title2 "Limited to Row-3 People Only" ;
    %let hivar = row40 ;
    proc tabulate data =&inset &tabopts ;
      class site surg_type ;
      var row04-&hivar ;
      tables (row04-&hivar)*sum="", (site surg_type) all = "Over All Sites" / misstext = '0' ;
      format site $site. ;
      where row03 AND cohort = "&cohort" ;
    run ;

    title3 "Percent Stats" ;
    %if &cohort = Adult %then %do ;
      %let vlist =  row41--row46a
                    row47
                    row49-row51
                    row53-row57
                    row59-row63
                    row65
                    num_diabetes
                    num_hypertension
                    num_dyslipidemia
                    num_sleepapnea
                    num_osteoarthritis
                    num_cvd
                    num_cerebvascd
                    num_nafld
                    num_gerd
                    num_depression
                    num_anxiety
                    num_eatingdisorder
                    num_substuse
                    num_tobaccouse
                    num_psychoses
                    num_kidneydisease
                    num_infertility
                    num_polycovaries
                    num_dvt
                    num_pe ;
    %end ;
    %else %do ;
      %let vlist = row41--row46a
                    row47
                    row49c--row51c2
                    row53-row57
                    row59-row63
                    row65
                    num_diabetes
                    num_hypertension
                    num_dyslipidemia
                    num_sleepapnea
                    num_osteoarthritis
                    num_cvd
                    num_cerebvascd
                    num_nafld
                    num_gerd
                    num_depression
                    num_anxiety
                    num_eatingdisorder
                    num_substuse
                    num_tobaccouse
                    num_psychoses
                    num_kidneydisease
                    num_infertility
                    num_polycovaries
                    num_dvt
                    num_pe
                    num_prader_willi
                    num_bardet_biedl
                    num_aspergers
                    num_downs
                    num_epiphysis
                    num_oth_misc
                    ;
    %end ;
    proc tabulate data =&inset &tabopts ;
      class site surg_type ;
      var &vlist ;
      tables (&vlist)*mean=""*f=percent6.0, (site surg_type) all = "Over All Sites" / misstext = '0' ;
      format site $site. ;
      where row03 AND cohort = "&cohort" ;
      attrib
        num_diabetes        label = '69. % Diabetes dx at baseline (in year before surgery)'
        num_hypertension    label = '70. % Hypertension dx at baseline'
        num_dyslipidemia    label = '71. % Dyslipidemia dx at baseline'
        num_sleepapnea      label = '72. % Sleep apnea dx at baseline'
        num_osteoarthritis  label = '73. % Osteoarthritis dx at baseline'
        num_cvd             label = '74. % Cardiovascular Disease dx (CVD) at baseline'
        num_cerebvascd      label = '75. % Cerebrovascular Disease dx at baseline'
        num_nafld           label = '76. % Non-alcoholic Fatty Liver Disease dx (NAFLD) at baseline'
        num_gerd            label = '77. % Gastroesophageal Reflux Disease dx (GERD) at baseline'
        num_depression      label = '78. % Depression dx at baseline'
        num_anxiety         label = '79. % Anxiety dx at baseline'
        num_eatingdisorder  label = '80. % Eating Disorder dx at baseline'
        num_substuse        label = '81. % Substance Use Disorder dx at baseline'
        num_tobaccouse      label = '82. % Smoker dx at baseline'
        num_psychoses       label = '83. % Psychotic Disorder dx (psychosis) at baseline'
        num_kidneydisease   label = '84. % Kidney Disease dx at baseline'
        num_infertility     label = '85. % Infertility dx at baseline'
        num_polycovaries    label = '86. % Polycystic Ovarian Syndrome dx at baseline'
        num_dvt             label = '87. % DVT dx at baseline'
        num_pe              label = '88. % PE dx at baseline'
        num_prader_willi    label = '89. % Prader-Willi dx at baseline'
        num_bardet_biedl    label = '90. % Bardet-Biedel dx at baseline'
        num_aspergers       label = '91. % Aspergers dx at baseline'
        num_downs           label = '92. % Downs Syndrome dx at baseline'
        num_epiphysis       label = '93. % Slipped Caplital Femoral Epiphysis dx at baseline'
        num_oth_misc        label = '94. % Other Misc genetic disorder at baseline (lump all other pediatric special forms)'
        ;
    run ;


    title3 "Mean Stats" ;
    proc tabulate data =&inset &tabopts ;
      class site surg_type ;
      var AgeIndex bl_bmi max_orig_bmi systolic diastolic pcombined_score_num ip_days ;
      tables (AgeIndex bl_bmi max_orig_bmi systolic diastolic pcombined_score_num ip_days)*mean="", (site surg_type) all = "Total All Sites" / misstext = '0' ;
      format site $site. ;
      where row03 AND cohort = "&cohort" ;
      attrib
        AgeIndex label = "48. Mean Age"
      ;
    run ;

  ods _all_ close ;
%mend report ;

options mprint ;

/*
%regen ;

 */
%get_people(outset = digested.people, from_scratch = 1) ;
%get_bs_enc(inset = digested.people, outset = digested.bar_surgs) ;
%get_bmi_times(inset = digested.people, inbmis = col.deduped_bmis) ;
%get_contacts(inset = digested.people, outset = digested.contacts) ;
%potpourri(inset = digested.people) ;
%diseases(inset = digested.people, outset = digested.dx_counts) ;
%censor_bmis ;
%get_heights(extrawh=) ;
%get_heights() ;
/*
*/
* %report(cohort = Adult) ;
* %report(cohort = Child) ;

/*
*/
