/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* C:\Users/pardre1/Documents/vdw/pbs/Programs/aim3/aim3_wrangle.sas
*
* Drives the code in aim3_wrangle_macros.sas.
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

options mprint ;

%let days_per_month = 30.4 ;

%let root = \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming ;

libname raw      "&root\Data\aim3_individual\raw" ;
libname col      "&root\Data\aim3_individual\collated" ;
libname digested "&root\Data\aim3_individual\collated\digested" ;
libname analytic "&root\Data\aim3_individual\collated\digested\analytic" ;
libname ref      "&root\data\aim3_individual\collated\reference" ;

%include "&root/programs/formats.sas" ;
%include "\\mltg4t\c$\users\pardre1\documents\vdw\pbs\programs\aim3\aim3_wrangle_macros.sas" ;
/*
%collate_events(outevents = digested.tx_events) ;
%get_tx_end(inevents = digested.tx_events, inppl = digested.people) ;
%get_aes(inppl = digested.people, outaes = digested.adverse_events, outppl = digested.people) ;

%get_fup_and_censor(inppl = digested.people
        , outppl = digested.people
        , inevents = digested.tx_events
        , inaes = digested.adverse_events
        , interms = %str('Conversion/Revision', 'Hernia', 'Reoperation', 'Reversal', 'Revision')
        , incens = %str('death', 'tx end')
        , var_prefix = reop
        , anal_name = %str(Reop/reint (no endo))) ;

%get_fup_and_censor(inppl = digested.people
        , outppl = digested.people
        , inevents = digested.tx_events
        , inaes = digested.adverse_events
        , interms = %str('Endoscopy', 'Conversion/Revision', 'Hernia', 'Reoperation', 'Reversal', 'Revision')
        , incens = %str('death', 'tx end')
        , var_prefix = reop_en
        , anal_name = %str(Reop/reint (WITH endo))) ;

%get_fup_and_censor(inppl = digested.people
        , outppl = digested.people
        , inevents = digested.tx_events
        , inaes = digested.adverse_events
        , interms = %str('death')
        , incens = %str('tx end')
        , var_prefix = mort1
        , anal_name = %str(Mortality 1)) ;

%get_fup_and_censor(inppl = digested.people
        , outppl = digested.people
        , inevents = digested.tx_events
        , inaes = digested.adverse_events
        , interms = %str('death')
        , incens = %str('eos')
        , var_prefix = mort2
        , anal_name = %str(Mortality 2)) ;

%get_fup_and_censor(inppl        = digested.people
                    , outppl     = digested.people
                    , inevents   = digested.tx_events
                    , inaes      = digested.adverse_events
                    , interms    = %str('hospitalization')
                    , incens     = %str('death', 'tx end')
                    , var_prefix = rehosp
                    , anal_name  = %str(Rehospitalization)) ;
* proc freq data = digested.people order = freq ;
*   tables reop_detail_status reop_en_detail_status mort1_detail_status mort2_detail_status rehosp_detail_status / missing format = comma9.0 ;
* run ;

%cod_categories(inppl = digested.people, outppl = digested.people) ;
*/

/*
  Hernia

  Conversion/Revision
  Reversal

  Cholecystectomy/ostomy

  Reoperation

  Vascular access

  Endoscopy



%get_fup_and_censor(inppl        = digested.people
                    , outppl     = digested.people
                    , inevents   = digested.tx_events
                    , inaes      = digested.adverse_events
                    , interms    = %str('Hernia')
                    , incens     = %str('death', 'tx end')
                    , var_prefix = hernia
                    , anal_name  = %str(Hernia)) ;


%get_fup_and_censor(inppl        = digested.people
                    , outppl     = digested.people
                    , inevents   = digested.tx_events
                    , inaes      = digested.adverse_events
                    , interms    = %str('Conversion/Revision', 'Reversal')
                    , incens     = %str('death', 'tx end')
                    , var_prefix = cn_rv_rs
                    , anal_name  = %str(Conversion/Revision or Reversal)) ;


%get_fup_and_censor(inppl        = digested.people
                    , outppl     = digested.people
                    , inevents   = digested.tx_events
                    , inaes      = digested.adverse_events
                    , interms    = %str('Cholecystectomy/ostomy')
                    , incens     = %str('death', 'tx end')
                    , var_prefix = chol_ost
                    , anal_name  = %str(Cholecystectomy/ostomy)) ;

%get_fup_and_censor(inppl        = digested.people
                    , outppl     = digested.people
                    , inevents   = digested.tx_events
                    , inaes      = digested.adverse_events
                    , interms    = %str('Reoperation')
                    , incens     = %str('death', 'tx end')
                    , var_prefix = bare_reop
                    , anal_name  = %str(Reoperation (reop px only--no reversal, revision, etc.))) ;


%get_fup_and_censor(inppl        = digested.people
                    , outppl     = digested.people
                    , inevents   = digested.tx_events
                    , inaes      = digested.adverse_events
                    , interms    = %str('Vascular access')
                    , incens     = %str('death', 'tx end')
                    , var_prefix = vasc_acc
                    , anal_name  = %str(Vascular access)) ;


%get_fup_and_censor(inppl        = digested.people
                    , outppl     = digested.people
                    , inevents   = digested.tx_events
                    , inaes      = digested.adverse_events
                    , interms    = %str('Endoscopy')
                    , incens     = %str('death', 'tx end')
                    , var_prefix = endo
                    , anal_name  = %str(Endoscopy)) ;
*/




%macro spot_check(patid = ) ;
  proc sql noprint ;
    create table digested.drop_me_events as
    select *
    from digested.tx_events
    where patid like "&patid.%"
    order by event_date
    ;

    create table digested.drop_me_aes as
    select *
    from digested.adverse_events
    where patid like "&patid.%"
    order by event_date
    ;

    reset noexec ;
    create table digested.drop_me_encs as
    select *
    from col.cohortencounter
    where patid like "&patid.%"
    order by admit_date
    ;

    create table digested.drop_me_dx as
    select *
    from col.cohortdx
    where patid like "&patid.%"
    order by admit_date
    ;

    create table digested.drop_me_px as
    select *
    from col.cohortpx
    where patid like "&patid.%"
    order by admit_date
    ;

    create table digested.drop_me_vits as
    select *
    from col.cohortvital
    where patid like "&patid.%"
    order by measure_date
    ;

  quit ;
%mend spot_check ;

* %spot_check(patid = 519C1A38055F21806C8448EE24A85065) ;
* %spot_check(patid = 7538C021D4E294F004F2C32DF5189DF9) ;
* %spot_check(patid = 793164E5DECEE806C629AE9E05BDF0AA) ;
* %spot_check(patid = 49329A87858AB603848A9C0FF40F6644) ;

