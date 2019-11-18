/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* C:\Users/pardre1/Documents/vdw/pbs/Programs/aim3/flow_diagram.sas
*
* Generating numbers for the Flow Diagram for Identification of the Adults
* in PCORnet Bariatric Study
*********************************************/

%include "h:/SAS/Scripts/remoteactivate.sas" ;

options
  linesize  = 150
  pagesize  = 80
  msglevel  = i
  formchar  = '|-++++++++++=|-/|<>*'
  dsoptions = note2err
  nocenter
  noovp
  nosqlremerge
  extendobscounter = no
;

%let root = \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming ;

libname col "&root\Data\aim3_individual\collated" ;
libname int "&root\Data\aim3_individual\collated\digested" ;
libname sts "&root\Data\aim3_individual\collated\digested" ;
libname ana "&root\Data\aim3_individual\collated\digested\analytic" ;
libname ref "&root\Data\aim3_individual\collated\reference" ;

%include "&root\Programs\formats.sas" ;


/*

http://sankeymatic.com

KPSC           [22443] Had Bar Surg
UPMC            [6878] Had Bar Surg
Partners Health [6052] Had Bar Surg
Other Sites    [55989] Had Bar Surg
Had Bar Surg    [1943] Not IP/AV
Had Bar Surg     [583] Too Old
Had Bar Surg    [8790] Other Disqual
Had Bar Surg     [116] Fundoplasty
Had Bar Surg   [78773] Basic Elig
Basic Elig     [10573] No Bl BMI
Basic Elig      [1904] Not Obese
Basic Elig     [50628] Not Diabetic
Basic Elig     [15668] Diabetic
Diabetic        [2890] No Bl A1c
Diabetic        [2337] No post-surg A1c
Diabetic       [10019] Remission Eligible

*/

/*

  Entire PCORnet Patient Population (34 sites in 11 CDRNS) with valid date of birth
  Patients with any encounters from 1/1/2005 to 9/30/2015
  Any bariatric procedure codes identified in any encounters

    Exclusion criteria:
    1.  Non-inpatient or non-ambulatory encounters with bariatric code (N = )
    2.  Age ≥80 years or <20 years at bariatric procedure (n =  ≥80 y; <20 y)
    3.  Multiple conflicting bariatric procedure codes on same day (n = )
    4.  Prior revision bariatric procedure code in 1 year look-back (n =)
    5.  Gastrointestinal cancer diagnosis code in 1 year before bariatric procedure (n =)
    6.  Emergency room encounter on same day as bariatric procedure (n =)
    7.  Fundoplasty procedure in 1 year before bariatric procedure ( n =)

  Patients with valid bariatric procedure code during study period

  ALL ABOVE ANSWERABLE FROM ATTRITION

  Any BMI data in year before surgery
  Patients with BMI ≥35 kg/m2 in year before bariatric procedure
  Patients with evidence of Type 2 Diabetes* in year before bariatric procedure

*/

data attr_descs ;
  input
    @1   ord         $char2.
    @4   description $char123.
  ;
  infile datalines truncover ;
datalines ;
01 Number of unique patients found in DEMOG table
02 Number of unique patients found in DEMOG table excluding missing patid and birthdates
03 Number of unique patients found in ENCOUNTER table in 2005 to 30 September 2015
04 Number of unique patients with any bariatric code
05 Number of unique patients with bariatric code in an IP or AV setting
06 Number of unique patients with bariatric code in an IP or AV setting at age <80 years
07 Number of unique patients with a valid bariatric code in an IP or AV setting who meet all inclusion criteria
08 Number of unique patients with a valid bariatric code in an IP or AV setting who meet all inclusion criteria wo fundoplasty
09 INFO: Number of unique patients with exclusion multiple valid bariatric procedures
10 INFO: Number of unique patients with revision code before index date
11 INFO: Number of unique patients with GI cancer diagnosis during index encounter
12 INFO: Number of unique patients with ER encounter on same day as index encounter
;
run ;

%macro compare_attrition ;
  * attrition table counts 2 fewer eligible ppl than Ive got in sts.people. Where is the discrep? ;
  * NO IT DIDNT--I WAS MANUALLY SUBTRACTING 2 B/C LEFTOVER FROM AIM2 b/c C1helpar elided 2 ppl for privacy reasons. ;
  proc sql number ;
    create table attrition as
    select site, num as num_attr
    from col.attrition
    where description = 'Number of unique patients with a valid bariatric code in an IP or AV setting who meet all inclusion criteria wo fundoplasty'
    order by site
    ;
    create table ppl_counts as
    select site, count(*) as num_precs, count(distinct patid) as num_ppl
    from sts.people
    group by site
    ;

    select a.site format = $s.
          , a.num_attr format = comma9.0
          , p.num_precs format = comma9.0
          , p.num_ppl format = comma9.0
    from attrition as a LEFT JOIN
          ppl_counts as p
    on    a.site = p.site
    order by a.site
    ;

    select sum(num_attr) as num_attr format = comma9.0
          , sum(num_precs) as num_precs format = comma9.0
          , sum(num_ppl) as num_ppl format = comma9.0
    from attrition as a LEFT JOIN
          ppl_counts as p
    on    a.site = p.site
    ;

  quit ;

%mend compare_attrition ;


ods listing close ;

options orientation = landscape ;
ods graphics / height = 8in width = 10in ;

%let out_folder = \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\output\ ;

ods html path = "&out_folder" (URL=NONE)
         body   = "aim3_flow_diagram.html"
         (title = "Aim 3 Flow Diagram Numbers")
         style = magnify
         nogfootnote
          ;

  %compare_attrition ;

  proc sql ;
    create table sums as
    select description
        , sum(num    ) as num format = comma10.0
        , sum(numexcl) as numexcl format = comma10.0
    from col.attrition
    group by description
    ;
    create table orderly as
    select ord, s.*
    from sums as s LEFT JOIN
        attr_descs as a
    on    s.description = a.description
    ;

    select description, num, numexcl
    from orderly
    order by ord
    ;

  quit ;

  proc sql ;
    create table gnu as
    select p.site
          , p.patid
          , p.row02
          , p.row03
          , p.row25
          , p.row28
          , p.row31
          , p.ip_days as hosp_days
          , (p.ip_days ge 365) as too_many_hosp_days
          , case when p.ageindex lt 12 then '<12' else p.cohort end as cohort
          , (row25 or row28 or row31) as bmi_1_3_5
          , c.ae_claims label = "Do we have complete claims data for this person?"
    from  sts.people as p INNER JOIN
          col.supplement_claims_capture as c
    on    p.site = c.site AND
          p.patid = c.patid
    ;
quit ;

  proc sort data = gnu ;
    by cohort ;
  run ;


  title1 "Adult and Child (12+) Cohort Together--No Age Restriction" ;

  proc freq data = gnu ;
    tables row02 * row03 / missing format = comma9.0 ;
    * where cohort = 'Adult' ;
    attrib
      row02 label = "Any BMI in year prior to surgery?"
      row03 label = "BMI 35+ in year prior to surgery?"
    ;
    by cohort ;
  run ;

  proc freq data = gnu ;
    tables ae_claims * too_many_hosp_days / missing format = comma9.0 ;
    where row03 ;
    by cohort ;
  run ;

  proc means data = gnu maxdec = 1 n min p10 p25 p50 p75 p90 max ;
    class cohort ;
    var hosp_days ;
    where row03 ;
  run ;

  proc sql ;
    create table hosps as
    select e.site, e.patid, e.admit_date, e.discharge_date, e.enc_type, e.src, e.encounterid
          , intck('days', max(admit_date, -365), min(discharge_date, -1)) + 1 as ip_days
    from gnu as g INNER JOIN
        col.cohortencounter as e
    on  g.site = e.site AND
        g.patid = e.patid
    where g.too_many_hosp_days and e.enc_type = 'IP' and discharge_date > -365 and admit_date < -1
    ;
    select *
    from hosps
    order by admit_date
    ;

    select src, sum(ip_days) as tot_days
    from hosps
    group by src
    ;

  quit ;

ods _all_ close ;


