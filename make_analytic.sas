/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* C:\Users/pardre1/Documents/vdw/pbs/Programs/aim3/make_analytic.sas
*
* Makes the analytic datasets for Aim 3
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

%let days_per_month = 30.4 ;

%let root = \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming ;

* libname raw    "&root\Data\aim3_individual\raw" ;
libname col    "&root\Data\aim3_individual\collated" ;
libname digested "&root\Data\aim3_individual\collated\digested" ;
libname analytic "&root\Data\aim3_individual\collated\digested\analytic_nochole" ;

%include "&root/programs/formats.sas" ;

%macro write_outcomes ;

  proc sql ;
    create table outcomes as
    select b.site
          , b.patid
          , p.cohort
          , p.AgeIndex
          , case when b.calc_bmi is null then 'orig' else 'calc' end as bmi_type
          , b.bmi as bmi_calc
          , (b.bmi - p.bl_bmi)/bl_bmi as bmi_calc_perchg format = percent6.1
          , b.bmi - p.bl_bmi as bmi_diff
          , (b.wt - p.bl_wt)/p.bl_wt as wt_calc_perchg format = percent6.1
          , b.wt - p.bl_wt as wt_diff
          , b.measure_date as time_c
          , b.censored
          , b.ht
          , b.wt
          , b.wt_is_calculated
          , b.ht_is_imputed
          , b.ht_impute_type
    from digested.censored_clean_bmis as b INNER JOIN
          digested.people as p
    on     b.site = p.site AND
          b.patid = p.patid INNER JOIN
          col.supplement_claims_capture as c
    on    b.site = p.site AND
          b.patid = c.patid
    where b.measure_date gt 0 and c.ae_claims = 1
    order by b.site, b.patid
    ;
  quit ;

  data
    analytic.outcomes_adult
    analytic.outcomes_child
  ;
    set outcomes ;

    * if _n_ = 1 then do ;
    *   declare hash excl(dataset: "sts.to_exclude") ;
    *   excl.definekey('site', 'patid') ;
    *   excl.definedone() ;
    * end ;

    * if excl.find() = 0 then delete ;

    label
      site            = "Data Mart contributing this record"
      patid           = "Patient identifier"
      bmi_calc        = "Body Mass Index"
      bmi_calc_perchg = "Percent change in BMI from baseline"
      time_c          = "Days from surgery"
    ;

    if cohort = 'Adult' then output analytic.outcomes_adult ;
    if cohort = 'Child' and 12 <= AgeIndex <= 19 then output analytic.outcomes_child ;

    drop cohort AgeIndex ;
  run ;
%mend write_outcomes ;

%macro write_covariates ;
  proc format ;
    /*
      Age < 13
      Age between 13 and 15
      Age between 16 and 17
      Age between 18 and 19
      Age between 20 and 44
      Age between 45 and 64
      Age between 65 and 80
    */
    value age_cat
      low-<13 = "<13"
      13 - 15 = "13-15"
      16 - 17 = "16-17"
      18 - 19 = "18-19"
      20 - 44 = "20-44"
      45 - 64 = "45-64"
      65 - 80 = "65-80"
    ;
    value bmi_cat
      low -< 35 = '<35'   /* '0' */
      35  -< 40 = '35-39' /* '1' */
      40  -< 50 = '40-49' /* '2' */
      50  -< 60 = '50-59' /* '3' */
      60 - high = '60+'   /* '4' */
    ;
  quit ;


  proc sql ;
    create table covariates as
    select p.cohort
          , p.row02
          , p.row03
          , p.site
          , p.patid
          , p.surg_type as px_group_c
          , p.AgeIndex as age_c
          , put(p.AgeIndex, age_cat.) as age_c_cat
          , p.sex as sex_c
          , p.hispanic
          , p.race
          , p.bl_bmi as bmi_bl
          , p.bl_ht as height_bl
          , p.bl_wt as weight_bl
          , put(p.bl_bmi, bmi_cat.) as bmi_bl_cat
          , p.bl_bmi_date as bmi_bl_days
          , p.max_orig_bmi as max_bmi
          , p.min_orig_bmi as min_bmi
          , p.surg_year as px_year
          , p.pcombined_score_num
          , max(p.num_tobaccouse, p.vital_smoker) as smoke_c
          , (p.surg_enc_type = 'AV') as surg_px_av
          , p.systolic as sbp_bl
          , p.diastolic as dbp_bl
          , p.sy_date as sbp_bl_days
          , p.dia_date as  dbp_bl_days
          , p.num_depression as depression_c
          , p.num_dyslipidemia as dyslipidemia_c
          , p.num_eatingdisorder as eatingdisorder_c
          , p.num_gerd as gerd_c
          , p.num_sleepapnea as sleepapnea_c
          , p.num_dvt as dvt_c
          , p.num_kidneydisease as kidneydisease_c
          , p.num_diabetes as diabetes_c
          , p.num_hypertension as hypertension_c
          , p.num_nafld as nafld_c
          , p.num_polycovaries as polycovaries_c
          , p.num_anxiety as anxiety_c
          , p.num_osteoarthritis as osteoarthritis_c
          , p.num_cancer as cancer_c
          , p.num_pe as pe_c
          , p.num_cerebvascd as cerebvascd_c
          , p.num_cvd as cvd_c
          , p.num_psychoses as psychoses_c
          , p.num_oth_misc as oth_misc_c
          , p.num_substuse as substuse_c
          , p.num_infertility as infertility_c
          , p.num_prader_willi as prader_willi_c
          , p.num_epiphysis as epiphysis_c
          , p.num_downs as downs_c
          , p.num_bardet_biedl as bardet_biedl_c
          , p.num_aspergers as aspergers_c
          , p.ip_days as hosp_days
          , p.row24 as bmi_post
          , p.row25 as bmi_1year
          , p.row28 as bmi_3year
          , p.row31 as bmi_5year
          , p.row26 as bmi_06moplus
          , p.row29 as bmi_30moplus
          , p.row32 as bmi_54moplus
          , p.row34 as avbp_post
          , p.row35 as avbp_1year
          , p.row37 as avbp_3year
          , p.row39 as avbp_5year
          , p.row36 as avbp_06moplus
          , p.row38 as avbp_30moplus
          , p.row40 as avbp_54plus
          , p.crow24 as bmi_post_c
          , p.crow25 as bmi_1year_c
          , p.crow28 as bmi_3year_c
          , p.crow31 as bmi_5year_c
          , p.crow26 as bmi_06moplus_c
          , p.crow29 as bmi_30moplus_c
          , p.crow32 as bmi_54moplus_c
          , p.ht_1year
          , p.ht_3year
          , p.ht_5year
          , p.ht_1year_c
          , p.ht_3year_c
          , p.ht_5year_c
          , p.reop_fup_time
          , p.reop_event
          , p.reop_status
          , p.reop_detail_status
          , p.reop_en_fup_time
          , p.reop_en_event
          , p.reop_en_status
          , p.reop_en_detail_status
          , p.mort1_fup_time
          , p.mort1_event
          , p.mort1_status
          , p.mort1_detail_status
          , p.mort2_fup_time
          , p.mort2_event
          , p.mort2_status
          , p.mort2_detail_status
          , p.rehosp_fup_time
          , p.rehosp_event
          , p.rehosp_status
          , p.rehosp_detail_status
          , p.ae_30_death
          , p.ae_30_peoi
          , p.ae_30_vt
          , p.ae_30_long_hosp
          , p.ae_30_any
          , p.cod_cat_septicemia
          , p.cod_cat_cad
          , p.cod_cat_indeterminate
          , p.cod_cat_cardiac_other
          , p.cod_cat_alc_subst
          , p.cod_cat_other_endocrine
          , p.cod_cat_nut_electro
          , p.cod_cat_malig
          , p.cod_cat_dm
          , p.cod_cat_gi
          , p.cod_cat_stroc_icbleed
          , p.cod_cat_self_harm
          , p.cod_cat_gi_liver
          , p.cod_cat_unintend_injpoi
          , p.cod_cat_infectious
          , p.cod_cat_other
          , p.cod_cat_chf
          , p.cod_cat_sleep_apnea
          , p.cod_cat_gi_vascular
          , p.cod_cat_trauma
          , p.cod_cat_flu_pneumo
          , p.cod_cat_respiratory
          , p.cod_cat_hyperten
          , p.cod_cat_renal
          , p.cod_cat_vascular_other
          , p.cod_cat_comp_med_surg
          , p.cod_cat_nut_deficient
          , p.cod_cat_gi_pancreas
          , p.cod_cat_pain_mal
          , p.cod_cat_hemat
          , p.cod_cat_pulm_embol
          , p.cod_cat_hemorrhage
          , p.cod_cat_shock
          , p.cod_cat_asphyx
          , p.cod_cat_neuro
          , p.cod_cat_stroke
          , p.cod_cat_depr_anx
          , p.cod_cat_gi_hernia
          , p.hernia_status
          , p.hernia_event
          , p.hernia_fup_time
          , p.hernia_detail_status
          , p.cn_rv_rs_status
          , p.cn_rv_rs_event
          , p.cn_rv_rs_fup_time
          , p.cn_rv_rs_detail_status
          , p.chol_ost_status
          , p.chol_ost_event
          , p.chol_ost_fup_time
          , p.chol_ost_detail_status
          , p.bare_reop_status
          , p.bare_reop_event
          , p.bare_reop_fup_time
          , p.bare_reop_detail_status
          , p.vasc_acc_status
          , p.vasc_acc_event
          , p.vasc_acc_fup_time
          , p.vasc_acc_detail_status
          , p.endo_status
          , p.endo_event
          , p.endo_fup_time
          , p.endo_detail_status
          , j.crev_status
          , j.crev_event
          , j.crev_fup_time
          , j.crev_detail_status
          , j.chern_status
          , j.chern_event
          , j.chern_fup_time
          , j.chern_detail_status
          , j.creop_status
          , j.creop_event
          , j.creop_fup_time
          , j.creop_detail_status
          , j.cops_status
          , j.cops_event
          , j.cops_fup_time
          , j.cops_detail_status
          , j.cents_status
          , j.cents_event
          , j.cents_fup_time
          , j.cents_detail_status
          , j.cothint_status
          , j.cothint_event
          , j.cothint_fup_time
          , j.cothint_detail_status
          , j.cendo_status
          , j.cendo_event
          , j.cendo_fup_time
          , j.cendo_detail_status
          , j.cinterv_status
          , j.cinterv_event
          , j.cinterv_fup_time
          , j.cinterv_detail_status
          , j.cop_int_noendo_status
          , j.cop_int_noendo_event
          , j.cop_int_noendo_fup_time
          , j.cop_int_noendo_detail_status
          , j.cop_int_endo_status
          , j.cop_int_endo_event
          , j.cop_int_endo_fup_time
          , j.cop_int_endo_detail_status
          , coalesce(j.last_observed_event, 0) as last_observed_event label = "Days from surgery to last observed event (tx or adverse)"
          , coalesce(j.last_event, 'no events') as last_event label = "Type of the event that ocurred on last_observed_event"
    from digested.people as p INNER JOIN
        col.supplement_claims_capture as c
    on    p.site = c.site AND
          p.patid = c.patid INNER JOIN
          digested.jama_resp_people as j
    on    p.site = j.site AND
          p.patid = j.patid
    where c.ae_claims eq 1   AND
          p.AgeIndex  ge 12  AND
          p.ip_days   le 365 AND
          p.row03     eq 1
    ;
  quit ;
  %let cvars = bmi_post_c bmi_1year_c bmi_3year_c bmi_5year_c bmi_06moplus_c bmi_30moplus_c bmi_54moplus_c ht_1year_c ht_3year_c ht_5year_c ;
  %let ncvars = bmi_post bmi_1year bmi_3year bmi_5year bmi_06moplus bmi_30moplus bmi_54moplus ht_1year ht_3year ht_5year ;

  %let rnm = %str(bmi_post_c = bmi_post
              bmi_1year_c = bmi_1year
              bmi_3year_c = bmi_3year
              bmi_5year_c = bmi_5year
              bmi_06moplus_c = bmi_06moplus
              bmi_30moplus_c = bmi_30moplus
              bmi_54moplus_c = bmi_54moplus
              ht_1year_c = ht_1year
              ht_3year_c = ht_3year
              ht_5year_c = ht_5year) ;

  data
    analytic.covariates_adult (drop = oth_misc_c prader_willi_c epiphysis_c downs_c bardet_biedl_c aspergers_c &cvars)
    analytic.covariates_child (drop = &cvars)
    analytic.censored_covariates_adult (drop = oth_misc_c prader_willi_c epiphysis_c downs_c bardet_biedl_c aspergers_c &ncvars
                                    rename = (&rnm))
    analytic.censored_covariates_child (drop = &ncvars rename = (&rnm))
  ;
    length site $ 7 patid $ 64 hispanic_c $ 7 ;
    set covariates ;

    race_pcor = race ;
    hispanic_c = hispanic ;
    if hispanic_c not in ('Y', 'N', 'OT') then hispanic_c = 'R/NI/UN' ;

    cdrn = put(site, $cdrn.) ;
    site_name = put(site, $site.) ;
    datamart = put(site, $dm.) ;

    if cohort = 'Adult' then do ;
      output analytic.covariates_adult ;
      output analytic.censored_covariates_adult ;
    end ;
    if cohort = 'Child' then do ;
      if 12 <= age_c <= 19 then do ;
        output analytic.covariates_child ;
        output analytic.censored_covariates_child ;
      end ;
    end ;
    drop cohort hispanic race ;
    label
      site                = "Data Mart contributing this record"
      patid               = "Patient identifier"
      px_group_c          = "Type of bariatric surgery"
      age_c               = "Age at surgery (continuous)"
      age_c_cat           = "Age at surgery (categorical)"
      sex_c               = "Sex"
      bmi_bl              = "Baseline Body Mass Index (continuous)"
      bmi_bl_cat          = "Baseline Body Mass Index (categorical)"
      weight_bl           = "Baseline weight"
      height_bl           = "Baseline height"
      max_bmi             = "Maximum BMI in year prior to surgery"
      min_bmi             = "Minimum BMI in year prior to surgery"
      px_year             = "Year of Surgery"
      pcombined_score_num = "Prior Combined comorbidity raw score (corrected for px/dx commingling)"
      smoke_c             = "Indication of tobacco use in year prior to surgery (either dx or vitals measure)"
      surg_px_av          = "Surgery was at an Ambulatory encounter"
      sbp_bl              = "Pre-surgery systolic BP measure closest to day of surgery"
      dbp_bl              = "Pre-surgery diastolic BP measure closest to day of surgery"
      depression_c        = "Depression dx in year prior to surgery"
      dyslipidemia_c      = "Dyslipidemia dx in year prior to surgery"
      eatingdisorder_c    = "Eating disorder dx in year prior to surgery"
      gerd_c              = "GERD dx in year prior to surgery"
      sleepapnea_c        = "Sleep apnea dx in year prior to surgery"
      dvt_c               = "DVT dx in year prior to surgery"
      kidneydisease_c     = "Kidney disease dx in year prior to surgery"
      diabetes_c          = "Diabetes dx in year prior to surgery"
      hypertension_c      = "Hypertension dx in year prior to surgery"
      nafld_c             = "NAFLD dx in year prior to surgery"
      polycovaries_c      = "Polycycstic ovaries dx in year prior to surgery"
      anxiety_c           = "Anxiety dx in year prior to surgery"
      osteoarthritis_c    = "Osteoarthritis dx in year prior to surgery"
      cancer_c            = "Cancer dx in year prior to surgery"
      pe_c                = "PE dx in year prior to surgery"
      cerebvascd_c        = "Cerebvascular disease dx in year prior to surgery"
      cvd_c               = "CVD dx in year prior to surgery"
      psychoses_c         = "Psychoses dx in year prior to surgery"
      oth_misc_c          = "Other/miscellaneous dx in year prior to surgery"
      substuse_c          = "Substance abuse dx in year prior to surgery"
      infertility_c       = "Infertility dx in year prior to surgery"
      prader_willi_c      = "Prader-Willi Syndrome dx in year prior to surgery"
      epiphysis_c         = "Epiphysis dx in year prior to surgery"
      downs_c             = "Down syndrome dx in year prior to surgery"
      bardet_biedl_c      = "Bardet-Biedl dx in year prior to surgery"
      aspergers_c         = "Asperger's syndrome dx in year prior to surgery"
      hosp_days           = "Total days in-hospital in the year prior to surgery"
      cdrn                = "CDRN submitting data"
      datamart            = "Particular datamart (within CDRN) submitting data, if known"
      site_name           = "Data-Contributing Site"
      hispanic_c          = "Hispanic ethnicity (separate from race)"
      race_pcor           = "Race (separate from Hispanic ethnicity)"
    ;
  run ;

  ods listing close ;
  ods html
    path = "%sysfunc(pathname(analytic))"
    (URL = NONE)
    body = "covariates_adult.html"
    (title= 'covariates_adult')
    stylesheet=(URL='http://datawranglr.com/assets/css/light_on_dark.css')
  ;
  title "Contents of covariates_adult" ;
  proc contents data = analytic.covariates_adult varnum ;
  * proc print data = analytic.covariates_adult(obs = 20) ;
  run ;

  ods html close ;
%mend write_covariates ;

%macro robs_last_mile ;
  * This is code Rob Wellman used to create the analytic file he actually used for his analysis. ;
  * from rw_distributed_cohort.sas ;
  * SOURCE DATA ;
  * Sort Roys covariate and outcome files by site and patid ;
  proc sort data = analytic.Censored_covariates_adult out = covs;
    by site patid ;
  proc sort data = analytic.outcomes_adult out = out;
    by site patid ;
  run;

  * COVARIATE DATA ;
  * Find the first year that each site performed SG for inclusion/exclusion ;
  proc sort data = covs ;
    by site px_year ;
  run;
  data site_firstsg  (keep = site sg_year) ;
    set covs (where = (px_group_c = "SG")) ;
    by site ;
    if first.site ;
    sg_year = px_year ;
  run;

  * Merge covariate data with year of first SG by site ;
  * Impose inclusion exclusion criteria ;
  data adultcovs ;
    merge covs site_firstsg ;
    by site ;
    * Inclusion/exclusion criteria ;
    if (row02 = 1) & (row03 = 1) & (bmi_bl ne .) & (age_c ne .) &
      (age_c ge 20) & (age_c lt 80) & (sex_c in ("F" "M")) & (px_year ge sg_year)
    then output;
  run;

  proc sort data = adultcovs ;
    by site patid  ;
  run;

  * OUTCOME DATA ;
  * Begin with Roys adult outcome data ;
  * Output uncensored records within time window: 0.5*365 to 1.5*365 ;
  data out_1year ;
    set analytic.Outcomes_adult ;

    days_diff_from_1yr = time_c - 365 ;
    days_diff_from_1yr_abs = abs(days_diff_from_1yr) ;

    * Output uncensored measurements that are within [183, 548] ;
    if (days_diff_from_1yr_abs le 183) & (censored = 0) then output ;
  run;
  * Sort and retain only the measurement closest to 365 ;
  proc sort data = out_1year;
    by site patid days_diff_from_1yr_abs ;
  run;
  data out_1year ;
    set out_1year ;
    by site patid ;
    if first.patid ;
  run;

  * ANALYTIC DATA ;
  * Merge covariates and outcomes, only keep records in both ;
  data analytic.adultout_1yr ;
    merge adultcovs (in = _in_covs) out_1year (in = _in_out) ;
    by site patid ;
    if _in_covs = 1 & _in_out = 1 then output ;
  run;
%mend robs_last_mile ;

%write_covariates ;
%write_outcomes ;
%robs_last_mile ;
