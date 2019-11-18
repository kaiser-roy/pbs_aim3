/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* C:\Users/pardre1/Documents/vdw/pbs/Programs/aim3/aim3_wrangle_macros.sas
*
* Contains macros to be run after the aim1_distributed program to produce
* vars that supplement the people dset for inclusion in final analysis
* dsets.
*********************************************/

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

proc format ;
  value $sg
    'Cholecystectomy/ostomy' = 'peoi'  /* percutaneous, endoscopic or operative intervention */
    'Conversion/Revision'    = 'peoi'  /* percutaneous, endoscopic or operative intervention */
    'Endoscopy'              = 'peoi'  /* percutaneous, endoscopic or operative intervention */
    'Hernia'                 = 'peoi'  /* percutaneous, endoscopic or operative intervention */
    'Reoperation'            = 'peoi'  /* percutaneous, endoscopic or operative intervention */
    'Reversal'               = 'peoi'  /* percutaneous, endoscopic or operative intervention */
    'Revision'               = 'peoi'  /* percutaneous, endoscopic or operative intervention */
    'Vascular access'        = 'peoi'  /* percutaneous, endoscopic or operative intervention */
    'DVT'                    = 'vt'    /* venous thromboembolism */
    'PE'                     = 'vt'    /* venous thromboembolism */
    'death'                  = 'death'
    'long_hosp'              = 'long_hosp'
  ;
quit ;

%macro collate_events(outevents = digested.tx_events) ;
  * Amasses treatment-relevant events. ;

  /*
    Treatment events include:
      weight,
      blood pressure,
      diagnosis, or
      procedure codes, or
      an encounter (of any type)
      end of study
  */

  %removedset(dset = &outevents) ;
  * medication orders ;
  proc sql noprint ;

    select max(length(patid)) as patid_length
    into :patid_length
    from col.cohortdemog
    ;

    create table vitals as
    select distinct site
          , patid length = &longest_patid
          , 'vital' as event_category length = &ec_len
          , case
              when (wt gt 0 and n(systolic, diastolic) > 0) then 'wt+bp'
              when wt gt 0 then 'wt'
              when (n(systolic, diastolic) > 0) then 'bp'
              else 'zah?'
            end as event_type length = &et_len
          , measure_date as event_date length = 4
          , . as discharge_date length = 4
          , coalesce(wt, systolic, diastolic) as result
    from col.cohortvital
    where measure_date gt 0 and (wt gt 0 OR n(systolic, diastolic) > 0)
    ;

    create table px as
    select distinct site
          , patid length = &longest_patid
          , 'px' as event_category length = &ec_len
          , 'px' as event_type length = &et_len
          , admit_date as event_date length = 4
          , . as discharge_date length = 4
          , . as result
    from  col.cohortpx
    where admit_date gt 0
    ;

    create table dx as
    select distinct site
          , patid length = &longest_patid
          , 'dx' as event_category length = &ec_len
          , 'dx' as event_type length = &et_len
          , admit_date as event_date length = 4
          , . as discharge_date length = 4
          , . as result
    from  col.cohortdx as d
    where admit_date gt 0
    ;

    create table enc as
    select distinct site
          , patid length = &longest_patid
          , 'enc' as event_category length = &ec_len
          , enc_type as event_type length = &et_len
          , admit_date as event_date length = 4
          , . as discharge_date length = 4
          , . as result
    from  col.cohortencounter as e
    where admit_date gt 0
    ;
    create table eos as
    select site
          , patid length = &longest_patid
          , 'eos' as event_category length = &ec_len
          , put(surg_year, 4.0) as event_type length = &et_len
          , &study_end - mdy(1, 1, surg_year) as event_date length = 4
          , . as discharge_date length = 4
          , . as result
    from digested.people
    ;
  quit ;

  proc append base = &outevents data = px ;
  run ;

  proc append base = &outevents data = dx ;
  run ;

  proc append base = &outevents data = vitals ;
  run ;

  proc append base = &outevents data = enc ;
  run ;

  proc append base = &outevents data = eos ;
  run ;

  options obs = max ;

  proc sort nodupkey data = &outevents ;
    by site patid event_date event_category ;
  run ;

  data &outevents ;
    length evid 5 event_date 4 ;
    set &outevents ;
    evid = _n_ ;
    label evid = "Arbitrary event ID" ;
    * drop event_type ;
  run ;

%mend collate_events ;

%macro get_index_hosps(inanal = digested.people, outset = s.selected_index_hosps) ;
  proc sql ;
    * Who does the ppl file say had an inpatient BS? ;
    create table ip_surg_havers as
    select a.site, a.patid, a.surg_type as px_group_c
    from &inanal as a
    where surg_enc_type ne 'AV'
    order by site, patid
    ;

    * What is the encounterid for the ppl who had inpatient BS? ;
    create table index_encs as
    select distinct i.site, i.patid, p.encounterid
    from  ip_surg_havers as i INNER JOIN
          col.cohortpxinclcodespxindex as p
    on    i.site = p.site AND
          i.patid = p.patid AND
          i.px_group_c = p.px_group
    ;

    * grab admit & discharge dates. ;
    create table candidate_hospitalizations as
    select i.*, e.admit_date, e.discharge_date, e.enc_type
    from  index_encs as i INNER JOIN
          col.cohortencounter as e
    on    i.encounterid = e.encounterid AND
          e.enc_type = 'IP' /* AND
          0 between e.admit_date and coalesce(e.discharge_date, 0) */
    order by i.site, i.patid, e.discharge_date desc
    ;
  quit ;

  data &outset ;
    length embraces_zero los ae 3 ;
    set candidate_hospitalizations ;
    if n(discharge_date) then los = (discharge_date - admit_date) + 1 ;
    embraces_zero = (admit_date <= 0 <= coalesce(discharge_date, 0)) ;
    ae = (los ge 30) ;
    by site patid ;
    if first.patid ;
  run ;

%mend get_index_hosps ;

%macro get_subsequent_hosps(inppl = stats.people, outset = stats.subsq_hosps) ;

  /*
    4. Rehospitalization is defined as any inpatient hospitalization following
       surgery that is not associated with a delivery, miscarriage, or
       abortion procedure code (using our previously defined list). Follow-up
       time is defined as the number of days after surgery until
       rehospitalization (if observed) or censoring.

    ref.preg_dx includes:
      D: Delivery
      M: Miscarriage
      S: Still Birth
      T: Termination

  */

  proc sort nodupkey data = ref.preg_px out = preg_px dupout = dropped_zeros ;
    by px px_codetype ;
  run ;

  proc sql ;
    update dropped_zeros
    set px = cats(px, '.0') ;
  quit ;

  proc append base = preg_px data = dropped_zeros ;
  run ;

  proc sql ;
    alter table preg_px add primary key (px, px_codetype)
    ;

    create table post_surg_hospitalizations as
    select e.*
    from col.cohortencounter as e
    where e.admit_date gt 0 and e.enc_type = 'IP'
    order by e.site, e.encounterid
    ;

    create table deleteable as
    select distinct site, patid, encounterid
    from col.cohortpx as p INNER JOIN
          preg_px as pp
    on    compress(p.px, '.') = pp.px AND
          p.px_type = put(pp.px_codetype, $pt.)
    UNION
    select distinct site, patid, encounterid
    from col.cohortdx as d INNER JOIN
          ref.preg_dx as pd
    on    compress(d.dx, '.') = pd.dx
    ;

    delete from post_surg_hospitalizations
    where encounterid in
    (select encounterid from deleteable)
    ;

    create table &outset as
    select *
    from post_surg_hospitalizations
    order by site, patid, admit_date
    ;
  quit ;

%mend get_subsequent_hosps ;

%macro get_aes(inppl = stats.people, outaes = stats.adverse_events, outppl = stats.people_ae) ;

  %let et_len = 25 ;
  %let ex_len = 8 ;
  %let sc_len = 2 ;

  %get_subsequent_hosps(inppl = &inppl, outset = subsq_hosps) ;

  proc sql ;
    create table deaths as
    select site
        , patid length = &longest_patid
        , 'death' as event_type length = &et_len
        , death_date as event_date
        , ' ' as extra length = &ex_len
        , 'dt' as source
    from col.cohortdeath
    where death_date > 0
    ;

    create table hosps as
    select site
          , patid length = &longest_patid
          , 'hospitalization' as event_type length = &et_len
          , put(discharge_date, 8.0) as extra length = &ex_len
          , admit_date as event_date
          , 'en' as source
    from  subsq_hosps
    ;

    create table ae_dx as
    select site
          , patid length = &longest_patid
          , a.subgroup as event_type length = &et_len
          , admit_date as event_date
          , d.dx as extra length = &ex_len
          , 'dx' as source
    from  col.cohortdx as d INNER JOIN
          ref.dvtcodes as a
    on    a.code_cat = 'DX' AND
          d.dx_type = a.code_type AND
          d.dx = compress(a.code, '.')
    where admit_date gt 0
    ;

    create table ae_px as
    select site
          , patid length = &longest_patid
          , a.subgroup as event_type length = &et_len
          , admit_date as event_date
          , d.px as extra length = &ex_len
          , 'px' as source
    from  col.cohortpx as d INNER JOIN
          ref.majoraecodes as a
    on    a.code_cat = 'PX' AND
          d.px_type = put(a.code_type, $pt.) AND
          d.px = compress(a.code, '.')
    where admit_date gt 0
    ;

  quit ;

  proc append base = adverse_events data = ae_dx ;
  proc append base = adverse_events data = ae_px ;
  proc append base = adverse_events data = deaths ;
  proc append base = adverse_events data = hosps ;

  proc sort nodupkey data = adverse_events out = &outaes ;
    by site patid event_type event_date ;
  run ;

  proc sql ;
    create table grist as
    select distinct site, patid, put(event_type, $sg.) as ae_category, event_date
    from &outaes
    where event_date IS NOT NULL
    ;

    create table counts as
    select site, patid, ae_category, min(event_date) as first_event, count(*) as num_events
    from grist
    group by 1, 2, 3
    order by 1, 2, 3
    ;
  quit ;

  proc transpose data = counts out = tposed_first (drop = _:) prefix = first_ ;
    var first_event ;
    id ae_category ;
    by site patid ;
  run ;

  proc transpose data = counts out = tposed_num (drop = _:) prefix = num_ ;
    var num_events ;
    id ae_category ;
    by site patid ;
  run ;

  data ae_stats ;
    merge
      tposed_first
      tposed_num
    ;
    by site patid ;

    ae_30_death     = (num_death > 0 and coalesce(first_death, 40) le 30) ;
    ae_30_peoi      = (num_peoi  > 0 and first_peoi  le 30) ;
    ae_30_vt        = (num_vt    > 1 and first_vt    le 30) ;

    label
      ae_30_death     = "Adverse Event in first 30 days: death"
      ae_30_peoi      = "Adverse Event in first 30 days: percutaneous, endoscopic or operative intervention"
      ae_30_vt        = "Adverse Event in first 30 days: venous thromboembolism"
      first_death     = "Date of earliest death record."
      first_peoi      = "Date of earliest percutaneous, endoscopic or operative intervention record."
      first_vt        = "Date of earliest venous thromboembolism record."
      num_death       = "Total number of death records."
      num_peoi        = "Total number of percutaneous, endoscopic or operative intervention records."
      num_vt          = "Total number of venous thromboembolism records."
    ;

    /*
      Q is not long hosps, q is whether incident surg hosp extends 30 days or more.
      index hospitalization--how often missing discharge on these?
    */

  %get_index_hosps(inanal = &inppl, outset = index_hosps) ;

  proc sql ;
    * I include these in the output ae dataset for completeness, though these arent really date-based. ;
    create table long_hospitalizations as
    select site
          , patid length = &longest_patid
          , 'long hosp' as event_type length = &et_len
          , admit_date as event_date
          , put(los, 3.0) as extra length = 8
          , 'en' as source
    from  index_hosps
    where ae = 1 /* automatically excludes the C4s, and any other person w/out discharge date. */
    order by site, patid
    ;

  quit ;

  proc append base = &outaes data = long_hospitalizations ;
  run ;

  %put INFO: SHOULD BE NO DUPES HERE! ;
  proc sort nodupkey data = &outaes ;
    by site patid event_date event_type  ;
  run ;

  %let vlist = ae_30_death
              ae_30_peoi
              ae_30_vt
              ae_30_long_hosp
              ae_30_any
              first_death
              first_peoi
              first_vt
              first_long_hosp
              first_hospitalization
              num_death
              num_peoi
              num_vt
              num_long_hosp
              num_hospitalization
        ;

  proc sort data = &inppl out = ppl ;
    by site patid ;
  run ;

  options dkricond = nowarn ;
  data &outppl ;
    merge
      ppl (drop = &vlist)
      ae_stats
      index_hosps (keep = site patid ae admit_date rename = (ae = num_long_hosp admit_date = first_long_hosp))
    ;
    by site patid ;
    ae_30_long_hosp = num_long_hosp ;
    array ae ae_30_: ;
    do i = 1 to dim(ae) ;
      if ae{i} = . then ae{i} = 0 ;
    end ;
    ae_30_any       = max(of ae_30_:) ;
    if site in ("C4MCRF", "C4UI", "C4UK", "C4UTSW", "C4UWM") then do ;
      ae_30_long_hosp = . ;
      first_long_hosp = . ;
      num_long_hosp = . ;
    end ;
    label
      ae_30_any       = "Adverse event of any type in first 30 days?"
      ae_30_long_hosp = "Adverse Event in first 30 days: index inpatient stay was > 30 days"
      first_long_hosp = "Admit date of index inpatient stay."
      num_long_hosp   = "Total number of > 30 day inpatient stay records."
    ;

  run ;
  options dkricond = warn ;
%mend get_aes ;

%macro get_tx_end(inevents = digested.tx_events, inppl = digested.people) ;
  /* Finds the end of tx and adds an event to the input dset for that tx */
  * Everything in this dset counts as a treatment event. ;
  proc sort nodupkey data = &inevents out = tx ;
    by site patid event_date ;
    where event_category not in ("&tx_end", 'eos') ;
  run ;

  data last_tx ;
    retain last_tx_date 0 already_output 0 ;
    set tx ;
    by site patid ;
    randy = uniform(&seed) ;
    event_type = event_category ;
    event_category = "&tx_end" ;
    if first.patid then do ;
      already_output = 0 ;
      last_tx_date = 0 ;
    end ;
    if (event_date - last_tx_date) > (18 * &days_per_month) and not already_output then do ;
      output ;
      already_output = 1 ;
    end ;
    last_tx_date = event_date ;
    if last.patid and not already_output then output ;
    keep evid site patid event_date event_category event_type discharge_date result randy ;
  run ;

  proc sql noprint ;
    create table noevents as
    select p.site
          , p.patid length = 32
          , "&tx_end" as event_category length = &ec_len
          , 'no events' as event_type length = &et_len
          , 0 as event_date length = 4
          , . as discharge_date length = 4
          , . as result
          , uniform(&seed) as randy
          , . as evid length = 5
    from  &inppl as p LEFT JOIN
          last_tx as l
    on    p.site = l.site AND
          p.patid = l.patid
    where l.site IS NULL
    ;
  quit ;

  proc append base = last_tx data = noevents ;
  run ;

  data &inevents ;
    set &inevents last_tx ;
  run ;

  proc sort noduprec data = &inevents ;
    by site patid event_date randy ;
  run ;

%mend get_tx_end ;

%macro get_fup_and_censor(inppl = , outppl = , inevents = , inaes =, var_prefix =, interms = %str(), incens = %str('death', "&tx_end"), anal_name = ) ;
  /*
    post-hoc docu for this macro
      parameters
        inevents = input dset of (generally tx) events.
        inaes = input dset of adverse events.
        var_prefix =
  */

  proc sql noprint;
    create table evs as
    select site, patid, event_category, event_date
    from &inevents
    where event_category in (&interms, &incens)
    UNION ALL
    select site, patid, event_type, event_date
    from &inaes
    where event_type in (&interms, &incens)
    ;
  quit ;

  proc sort nodupkey data = evs ;
    by site patid event_date event_category  ;
  run ;

  data first_terms ;
    length &var_prefix._status $ 8 &var_prefix._event 3 ;
    set evs ;
    by site patid ;
    if first.patid ;
    &var_prefix._fup_time = event_date ;
    &var_prefix._event = (event_category in (&interms)) ;
    if event_category in (&interms) then &var_prefix._status = "&var_prefix" ;
    else &var_prefix._status = "censored" ;
    &var_prefix._detail_status = event_category ;
    keep site patid &var_prefix.: ;
  run ;

  options dkricond = nowarn ;
  data &outppl ;
    merge
      &inppl (drop = &var_prefix._fup_time
                     &var_prefix._event
                     &var_prefix._status
                     &var_prefix._detail_status)
      first_terms
    ;
    by site patid ;
    label
      &var_prefix._fup_time      = "&anal_name analysis: follow-up time"
      &var_prefix._event         = "&anal_name analysis: flag indicating whether this person had an event at &var_prefix._fup_time (vs being censored)"
      &var_prefix._status        = "&anal_name analysis: gross-level status (event or censored)"
      &var_prefix._detail_status = "&anal_name analysis: particular event"
    ;
  run ;
%mend get_fup_and_censor ;

%macro cod_categories(inppl = , outppl = ) ;
  data clean_causes ;
    set col.cohortdeathcause ;
    death_cause = compress(death_cause, '.', 'kad') ;
    if prxmatch('/[A-Z]\d{3}/', death_cause) and site = 'C5HP' and death_cause_code = '10' then do ;
      death_cause = substr(death_cause, 1, 3) || '.' || substr(death_cause, 4) ;
    end ;
  run ;

  proc sql ;
    create table grist as
    select site, patid
          , death_cause
          , catx(': ', 'Cause of Death category', var_label) as var_label
          , varname
    from clean_causes as dc LEFT JOIN
         ref.cod_categories as cc
    on    dc.death_cause = cc.dx AND
          dc.death_cause_code = cc.dx_codetype
    ;

    create table categorized_cods as
    select site, patid
          , var_label
          , varname
          , count(*) as num_codes
    from grist
    group by site, patid, var_label, varname
    order by site, patid
    ;
  quit ;

  proc transpose data = categorized_cods out = norm_cod_cats  (drop = _:) prefix = cod_cat_ ;
    var num_codes ;
    id varname ;
    idlabel var_label ;
    by site patid ;
  run ;

  options dkricond = nowarn ;

  proc sort data = &inppl(drop = cod_cat_:) out = ppl ;
    by site patid ;
  run ;

  proc sort data = norm_cod_cats ;
    by site patid ;
  run ;

  data &outppl ;
    merge
      ppl
      norm_cod_cats
    ;
    by site patid ;
    array x cod_cat_: ;
    do i = 1 to dim(x) ;
      if x{i} = . then x{i} = 0 ;
      if x{i} > 1 then x{i} = 1 ;
    end ;
    * tot_cats = sum(of cod_cat_:) ;
    drop i ;
  run ;
%mend cod_categories ;


/*
  we need to make 2 passes through the events list
  one to detect the point of censoring
  and one to get the f/up time & status up to censoring.

  pass in
    a raw dset of all possibly relevant events
    a ppl dset
    a list of censoring event types
    a list of f_up event types

    draw out a new events list w/all event types of either kind.
    determine censoring date/reason
    remove censored events
    determine f/up date/status

*/

/*
  re-op/re-int
    one of conversion/revision, revision, reoperation, reversal, vascular access, cholecystectomy, and hernia
    but *not* endoscopy, though we throw that on in a sensitivity analysis.
    so f/up time is time of death, latest tx, or reop/reint, whichever is first.
    outcomes are reopint/tx end/death

    reop_censor_reason (death/tx-end)
    reop_censor_date
    reop_end_status (reop/noreop)
    reop_fup_time

    reop_en_end_status (with endoscopy)
    reop_en_fup_time (with endoscopy)


      var_suffix    = reop
        , inevents      = digested.all_events
        , outevents     = digested.&var_suffix._censored_events
        , inppl         = digested.people
        , outppl        = digested.people
        , tx_events     = %str(vital', 'px', 'dx', 'enc')
        , censor_events = %str('tx end', 'death')


  all-cause mortality
    death & cause of death.
    (for now just take highest-sorting COD code)
    censor by end-of-tx

    outcomes are dead/not dead
    f/up time is date of death or last tx, whichever is latest.

    mort_censor_reason (tx-end or null)
    mort_censor_date
    mort_fup_time
    mort_end_status

  rehosp
    f/up time is date of death, rehosp or last tx, whichever is latest.
    outcome is rehosp, death, tx end

  rehosp_censor_reason
  rehosp_censor_date
  rehosp_fup_time
  rehosp_end_status



*/
