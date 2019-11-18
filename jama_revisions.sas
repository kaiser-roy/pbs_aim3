/*********************************************
* Roy Pardee
* KP Washington Health Research Institute
* (206) 287-2078
* roy.e.pardee@kp.org
*
* C:\Users/pardre1/Documents/vdw/pbs/Programs/aim3/jama_revisions.sas
*
* Working on the revisions required by JAMA surgery. See Davids 2-aug-2019
* message, subject "JAMA Surgery Aim 3 response - updated document and next steps"
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

* For detailed database traffic: ;
* options sastrace=',,,d' sastraceloc=saslog no$stsuffix ;

%let root = \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming ;

libname raw      "&root\Data\aim3_individual\raw" ;
libname col      "&root\Data\aim3_individual\collated" ;
libname digested "&root\Data\aim3_individual\collated\digested" ;
libname analytic "&root\Data\aim3_individual\collated\digested\analytic" ;
libname ref      "&root\data\aim3_individual\collated\reference" ;

%include "&root/programs/formats.sas" ;
%include "\\mltg4t\c$\users\pardre1\documents\vdw\pbs\programs\aim3\aim3_wrangle_macros.sas" ;

%macro get_codelist ;
  %let xls_file = \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\collated\reference\CHOICE_final_revision_reoperation_codes_list_070819.xlsx ;
  libname xl ODBC required = "Driver={Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)};dbq=&xls_file" preserve_tab_names = yes ;

  options varlenchk = nowarn ;
  data ref.choice_px_cats ;
    length
      code $ 12
      code_type $ 20
      description $ 200
      final_category $ 20
      nonsense_flag
      colon_flag
      chole_flag
      ing_fem_hn_flag
      gastrectomy_flag
      paresophhiat_flag
      liverpanc_flag
      conversion_bariatric
      cancerflag
      lower_gi_flag 3
      px_type $ 2
    ;
    set xl.'final_keep_070319$'n ;
    select(code_type) ;
      when('ICD-10 Procedure') px_type = '10' ;
      when('ICD-9 Procedure')  px_type = '09' ;
      when('CPT')              px_type = 'CH' ;
      otherwise                px_type = '??' ;
    end ;

    format _all_ ;
    informat _all_ ;
  run ;





  /*
    • 44.66, 43283, 43324, 43338 are all codes that should be labeled are REOPERATIONS in the final_category(CHOICE Reop Code Categories)
    • S2085 codes (at the bottom of the table) should be labeled at REVISIONS in the final_category(CHOICE Reop Code Categories)
    • All of the other codes (Rows 5-24) should be ignored and should not receive a final_category
  */

  %let ph_desc = 'added/categorized post-hoc by david & anita 7-aug-2019' ;
  proc sql noprint ;
    insert into ref.choice_px_cats (code, px_type, description, final_category) values('4466', '09', &ph_desc, 'REOPERATION') ;
    insert into ref.choice_px_cats (code, px_type, description, final_category) values ('43283', 'CH', &ph_desc, 'REVISION') ;
    insert into ref.choice_px_cats (code, px_type, description, final_category) values ('43324', 'CH', &ph_desc, 'REVISION') ;
    insert into ref.choice_px_cats (code, px_type, description, final_category) values ('43338', 'CH', &ph_desc, 'REVISION') ;
  quit ;

  proc sort data = ref.choice_px_cats ;
    by code px_type ;
  run ;

  proc sql ;
    alter table ref.choice_px_cats add primary key (code, px_type) ;
  quit ;

  proc freq data = ref.choice_px_cats ;
    tables code_type * px_type / list missing format = comma9.0 ;
    tables final_category / missing format = comma9.0 ;
  run ;
%mend get_codelist ;

* %get_codelist ;
* endsas ;

proc sql ;
  * create table digested.px_with_final_category as
  select p.*, c.final_category
  from col.cohortpx as p LEFT JOIN
        ref.choice_px_cats as c
  on    p.px = c.code AND
        p.px_type = c.px_type
  ;
quit ;

%let days_per_month = 30.417 ;
%let seed           = 6546 ;

%let et_len = 20 ;
%let ec_len = 12 ;

%let tx_end = %str(tx end) ;

%let study_end = '01-oct-2015'd ;

%global longest_patid ;
proc sql noprint ;
  select max(length(patid)) into :longest_patid
  from col.cohortdemog
  ;
quit ;

%macro get_aes_new(outset = digested.choice_adverse_events) ;
  %let et_len = 25 ;
  %let ex_len = 8 ;
  %let sc_len = 2 ;

  proc sql ;

    create table ae_px as
    select site
          , patid length = &longest_patid
          , final_category as event_type length = &et_len
          , admit_date as event_date
          , px as extra length = &ex_len
          , 'px' as source
    from  digested.px_with_final_category
    where admit_date gt 0 and coalesce(final_category, 'BILIARY') ne 'BILIARY'
    ;

  quit ;

  proc sort nodupkey data = ae_px out = &outset ;
    by site patid event_type event_date ;
  run ;

%mend get_aes_new ;

%macro make_new_outcomes(outppl = digested.jama_resp_people) ;
  proc sql ;
    create table aes as
    select *
    from digested.adverse_events
    where source ne 'px'
    union all
    select *
    from digested.choice_adverse_events
    ;

    create table jama_resp_people as
    select site, patid, surg_type
    from digested.people
    ;
    create table all_events as
    select site, patid, event_date, event_type
    from digested.adverse_events
    where event_type ne 'long hosp'
    union
    select site, patid, event_date, event_category as event_type
    from digested.tx_events
    where event_category not in ('eos', 'tx end')
    order by site, patid
    ;

  quit ;

  data last_events ;
    set all_events ;
    by site patid ;
    if last.patid ;
    last_observed_event = event_date ;
    last_event = event_type ;
  run ;

  proc freq data = all_events order = freq ;
    tables event_type  / missing format = comma9.0 ;
  run ;

  proc freq data = last_events order = freq ;
    tables event_type  / missing format = comma9.0 ;
  run ;

  * i.  Revision or Conversion – this corresponds exactly to the REVISION
  * “final_category” of codes in the spreadsheet ;
  %get_fup_and_censor(inppl = jama_resp_people
          , outppl = &outppl
          , inevents = digested.tx_events
          , inaes = aes
          , interms = %str('REVISION')
          , incens = %str('death', 'tx end')
          , var_prefix = crev
          , anal_name = %str(i. CHOICE revision or conversion)) ;

  * ii. Abdominal Hernia – this corresponds to the HERNIA “final_category” of
  * codes in the spreadsheet ;
  %get_fup_and_censor(inppl = &outppl
          , outppl = &outppl
          , inevents = digested.tx_events
          , inaes = aes
          , interms = %str('HERNIA')
          , incens = %str('death', 'tx end')
          , var_prefix = chern
          , anal_name = %str(ii. CHOICE hernia)) ;

  * iii.  Other Operation – this corresponds to the REOPERATION “final_category” of codes in ;
  * the spreadsheet ;
  %get_fup_and_censor(inppl = &outppl
          , outppl = &outppl
          , inevents = digested.tx_events
          , inaes = aes
          , interms = %str('REOPERATION')
          , incens = %str('death', 'tx end')
          , var_prefix = creop
          , anal_name = %str(iii. CHOICE reoperation)) ;

  * iv. Operations – the is the first event of any REVISION, HERNIA, or
  * REOPERATION in the “final_category” of codes in the spreadsheet ;
  %get_fup_and_censor(inppl = &outppl
          , outppl = &outppl
          , inevents = digested.tx_events
          , inaes = aes
          , interms = %str('REVISION', 'HERNIA', 'REOPERATION')
          , incens = %str('death', 'tx end')
          , var_prefix = cops
          , anal_name = %str(iv. CHOICE operations)) ;

  * v. Enteral Access – this corresponds to the ENTERAL “final_category” of codes
  * in the spreadsheet ;
  %get_fup_and_censor(inppl = &outppl
          , outppl = &outppl
          , inevents = digested.tx_events
          , inaes = aes
          , interms = %str('ENTERAL')
          , incens = %str('death', 'tx end')
          , var_prefix = cents
          , anal_name = %str(v. CHOICE enteral access)) ;


  * vi. Other Interventions – this corresponds to the OTHER
  * INTER “final_category” of codes in the spreadsheet ;
  %get_fup_and_censor(inppl = &outppl
          , outppl = &outppl
          , inevents = digested.tx_events
          , inaes = aes
          , interms = %str('OTHER INTER')
          , incens = %str('death', 'tx end')
          , var_prefix = cothint
          , anal_name = %str(vi. CHOICE other interventions access)) ;

  * vii.  Endoscopy - this
  * corresponds to the ENDOSCOPY “final_category” of codes in the spreadsheet ;
  %get_fup_and_censor(inppl = &outppl
          , outppl = &outppl
          , inevents = digested.tx_events
          , inaes = aes
          , interms = %str('ENDOSCOPY')
          , incens = %str('death', 'tx end')
          , var_prefix = cendo
          , anal_name = %str(vii. CHOICE endoscopy)) ;

  * viii. Intervention – this is the first occurrence of any ENTERAL, OTHER
  * INTER, or ENDOSCOPY in the “final_category” of codes in the spreadsheet ;
  %get_fup_and_censor(inppl = &outppl
          , outppl = &outppl
          , inevents = digested.tx_events
          , inaes = aes
          , interms = %str('ENTERAL', 'OTHER INTER', 'ENDOSCOPY')
          , incens = %str('death', 'tx end')
          , var_prefix = cinterv
          , anal_name = %str(viii. CHOICE intervention)) ;

  * ix. Operation or Intervention (w/o Endoscopy) – this is our primary outcome
  * and is the first occurrence of any REVISION, HERNIA, REOPERATION, ENTERAL,
  * or OTHER INTER in the “final_category” of codes in the spreadsheet (excludes
  * ENDOSCOPY) ;
  %get_fup_and_censor(inppl = &outppl
          , outppl = &outppl
          , inevents = digested.tx_events
          , inaes = aes
          , interms = %str('REVISION', 'HERNIA', 'REOPERATION', 'ENTERAL', 'OTHER INTER')
          , incens = %str('death', 'tx end')
          , var_prefix = cop_int_noendo
          , anal_name = %str(ix. CHOICE operation/intervention--no endoscopy)) ;

  * x.  Operation or Intervention (with Endoscopy) – this is the
  * first occurrence of any REVISION, HERNIA, REOPERATION, ENTERAL, OTHER INTER,
  * or ENDOSCOPY in the “final_category” of codes in the spreadsheet (INcludes
  * ENDOSCOPY) ;
  %get_fup_and_censor(inppl = &outppl
          , outppl = &outppl
          , inevents = digested.tx_events
          , inaes = aes
          , interms = %str('REVISION', 'HERNIA', 'REOPERATION', 'ENTERAL', 'OTHER INTER', 'ENDOSCOPY')
          , incens = %str('death', 'tx end')
          , var_prefix = cop_int_endo
          , anal_name = %str(x. CHOICE operation/intervention--WITH endoscopy)) ;

  proc sql ;
    create table ppl as
    select o.*, last_observed_event, last_event
    from &outppl as o LEFT JOIN
        last_events as l
    on  o.site = l.site AND
        o.patid = l.patid
    order by o.site, o.patid
    ;

    create table &outppl as
    select *
    from ppl
    ;
  quit ;

%mend make_new_outcomes ;

* %get_aes_new ;
%make_new_outcomes ;
endsas ;

%macro depict(var_prefix) ;

  proc means data = digested.jama_resp_people maxdec = 2 ;
    class surg_type &var_prefix._detail_status ;
    var &var_prefix._fup_time ;
  run ;

  proc sgpanel data = digested.jama_resp_people ;
    panelby surg_type / columns = 1 ;
    hbox &var_prefix._fup_time / category = &var_prefix._detail_status ;
    colaxis grid ;
  run ;

%mend depict ;

options orientation = landscape ;
ods graphics / height = 8in width = 10in ;

%let out_folder = %sysfunc(pathname(digested)) ;

ods html5 path = "&out_folder" (URL=NONE)
         body   = "jama_revisions.html"
         (title = "jama_revisions output")
         style = magnify
         nogfootnote
         device = svg
          ;


  title1 "All Procedures pulled for PBS Aim 3" ;
  proc freq data = digested.px_with_final_category order = freq ;
    tables px_group * final_category / missing format = comma9.0 ;
    attrib
      px_group label = "Original Pull PX category"
      final_category label = "CHOICE Reop Code Categories"
    ;
  run ;
  %let td_goo = user              = "&nuid@LDAP"
                password          = "&cspassword"
                server            = "&td_prod"
                schema            = "sb_ghri"
                connection        = global
                mode              = teradata
  ;

  libname sb_ghri teradata &td_goo multi_datasrc_opt = in_clause ;

  proc sql number ;
    title1 "Interesting(?) and Incongruent Categories" ;
    create table curious as
    select px_type, px, px_group, final_category, count(*) as num_recs
    from digested.px_with_final_category
    where px_group in ('RYGB', 'FUNDOPLASTY', 'OTHERADVERSE') and final_category IS NULL
    group by px_type, px, px_group, final_category
    ;

    update curious set px = '46.75' where px = '4675' ;
    update curious set px = '46.82' where px = '4682' ;

    create table descriptions as
    select distinct vdw_code, vdw_cd_desc
    from sb_ghri.zrcm_px_px
    where vdw_code in (select px from curious)
    order by vdw_code, vdw_cd_desc ;

    create table gnu as
    select c.px_type, c.px, d.vdw_cd_desc label = "Description (if avail.)", c.px_group, c.final_category, c.num_recs format = comma9.0
    from curious as c LEFT JOIN
          descriptions as d
    on    c.px = d.vdw_code
    order by c.px_group, c.px_type, c.px, c.num_recs descending
    ;

    update gnu set vdw_cd_desc = 'LAPAROSCOPY, GASTRIC RESTRICTIVE PROCEDURE, WITH GASTRIC BYPASS FOR MORBID OBESITY' where px = 'S2085' ;

    select * from gnu ;

  quit ;
  title1 "PBS Aim 3 Survival Times/Outcomes for new CHOICE-based adverse events" ;

  %depict(var_prefix = crev) ;
  %depict(var_prefix = chern) ;
  %depict(var_prefix = creop) ;
  %depict(var_prefix = cops) ;
  %depict(var_prefix = cents) ;
  %depict(var_prefix = cothint) ;
  %depict(var_prefix = cendo) ;
  %depict(var_prefix = cinterv) ;
  %depict(var_prefix = cop_int_noendo) ;
  %depict(var_prefix = cop_int_endo) ;

ods _all_ close ;


