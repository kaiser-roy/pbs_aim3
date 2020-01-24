/*********************************************
* Roy Pardee
* Group Health Research Institute
* (206) 287-2078
* pardee.r@ghc.org
*
* C:\Users/pardre1/Documents/vdw/pbs/Programs/aim3/supplemental_request.sas
*
* We sent out a follow-up request asking for lists of patids for people for whom data
* capture (for adverse events) is questionable.  This was pretty loosey-goosey
* stuff--we got a fair number of flat responses of 'nobody', frx.
* workplan was: pbs_ahr_wp006_nsd1_v02 BTW.
* https://querytool.pcornet.org/requests/details?ID=b26e005b-e2c3-45e2-9ca3-a87400b41683
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

* Stashed the responses in site-named folders in: ;
* \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\raw\supplemental_request ;

/*
  unc
  "\\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\raw\supplemental_request\C2 - University of North Carolina DataMart NEW\C2UNC_Claims_Ind.xlsx"
  xls
  upmc
  "\\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\raw\supplemental_request\C11 - University of Pittsburgh Medical Center DataMart NEW\pbs_ahr_wp006_v02 file for C11UPMC.xls"
  xls
  kpma
  text file "everybody has claims"
  geisinger
  \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\raw\supplemental_request\C11 - Geisinger DataMart NEW
  sas dset
  kpsc
  "\\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\raw\supplemental_request\C5 - Kaiser Permanente Southern California DataMart NEW\aim3_claims.sas7bdat"
  sas
  kpnw
  "\\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\raw\supplemental_request\C5 - Kaiser Permanente Northwest DataMart NEW\finder_file_ae_claims.sas7bdat"
  sas
  kpco
  "\\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\raw\supplemental_request\C5 - Kaiser Permanente Colorado DataMart NEW\c5kpco_ae_claims.sas7bdat"
  sas
  helpar
  "\\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\raw\supplemental_request\C5 - Health Partners Research Foundation DataMart NEW\hpi_finder_file.sas7bdat"
  sas
  ghc
  "\\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\raw\supplemental_request\C5 - Group Health Research Institute DataMart NEW\aim3_claims.sas7bdat"
  sas
  mfld
  "\\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual\raw\supplemental_request\C4 - Marshfield Clinic DataMart NEW\cohort_claim_status.sas7bdat"
  sas
*/

%let root = \\groups\data\CTRHS\PCORnet_Bariatric_Study\Programming\Data\aim3_individual ;
libname col "&root\collated" ;


%let unc_xl = %str(&root\raw\supplemental_request\C2 - University of North Carolina DataMart NEW\C2UNC_Claims_Ind.xlsx) ;
libname unc ODBC required = "Driver={Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)};dbq=&unc_xl" preserve_tab_names = yes ;

%let upmc_xl = %str(&root\raw\supplemental_request\C11 - University of Pittsburgh Medical Center DataMart NEW\pbs_ahr_wp006_v02 file for C11UPMC.xls) ;
libname upmc_xl ODBC required = "Driver={Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)};dbq=&upmc_xl" preserve_tab_names = yes ;


libname gies "&root\raw\supplemental_request\C11 - Geisinger DataMart NEW" ;
libname kpsc "&root\raw\supplemental_request\C5 - Kaiser Permanente Southern California DataMart NEW\" ;
* aim3_claims.sas7bdat ;
libname kpnw "&root\raw\supplemental_request\C5 - Kaiser Permanente Northwest DataMart NEW\" ;
* finder_file_ae_claims.sas7bdat ;
libname kpco "&root\raw\supplemental_request\C5 - Kaiser Permanente Colorado DataMart NEW\" ;
* c5kpco_ae_claims.sas7bdat ;
libname helpar "&root\raw\supplemental_request\C5 - Health Partners Research Foundation DataMart NEW\" ;
* hpi_finder_file.sas7bdat ;
libname ghc "&root\raw\supplemental_request\C5 - Group Health Research Institute DataMart NEW\" ;
* aim3_claims.sas7bdat ;
libname mfld "&root\raw\supplemental_request\C4 - Marshfield Clinic DataMart NEW\" ;
* cohort_claim_status.sas7bdat ;
libname kpma "&root\raw\" ;

proc sql ;
  create table col.supplement_claims_capture as
  select 'C11GS' as site, patid, ae_claims
  from gies.ghs_finder_file
  UNION ALL
  select 'C5KPSC' as site, patid, ae_claims
  from kpsc.aim3_claims
  UNION ALL
  select 'C5KPNW' as site, patid, ae_claims
  from kpnw.finder_file_ae_claims
  UNION ALL
  select 'C5KPCO' as site, patid, ae_claims
  from kpco.c5kpco_ae_claims
  UNION ALL
  select 'C5HP' as site, patid, ae_claims
  from helpar.hpi_finder_file
  UNION ALL
  select 'C5GH' as site, patid, ae_claims
  from ghc.aim3_claims
  UNION ALL
  select 'C4MCRF' as site, patid, ae_claims
  from mfld.cohort_claim_status_v2
  UNION ALL
  select 'C5KPMA' as site, patid, 1 as ae_claims
  from kpma.C5KPMA_cohortdemog
  UNION ALL
  select 'C11UPMC' as site, patid, ae_claims
  from upmc_xl.'sheet0$'n
  UNION ALL
  select 'C2UNC' as site, patid, ae_claims
  from unc.'sheet1$'n
  ;

quit ;

proc sort nodupkey data = col.supplement_claims_capture ;
  by site patid ;
run ;

proc sort nodupkey data = col.cohortdemog out = chd ;
  by site patid ;
run ;

data col.drop_me ;
  merge
    col.supplement_claims_capture (in = s)
    chd (in = c)
  ;
  in_supplement = s ;
  in_cohort = c ;
  by site patid ;
run ;

proc format ;
  value cap
    0 = "Not complete"
    1 = "Complete"
  ;
quit ;

proc freq data = col.supplement_claims_capture ;
  tables site * ae_claims / missing format = comma9.0 nocol nopct ;
  format ae_claims cap. ;
run ;

proc freq data = col.cohortdemog  ;
  tables site * sex / missing format = comma9.0 nocol nopct ;
run ;

proc freq data = col.drop_me order = freq ;
  tables in_supplement * in_cohort / missing format = comma9.0 ;
run ;
