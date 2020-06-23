clear
set more off
capture log close

log using "C:\Users\Joanna\OneDrive - King's College London\ELSA\UKDA-5050-stata\stata\log", replace

cd "C:\Users\Joanna\OneDrive - King's College London\ELSA\UKDA-5050-stata\stata"

global raw "raw"
global work "work"
global output "output"

set maxvar 10000

clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"

/*locf/b imputation for edqual*/
gsort -idauniq -wave 
foreach var of varlist edqual5 {
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
sort idauniq wave 
foreach var of varlist edqual5 {
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
tab edqual5, mi
gen edqual5_fp = edqual5 if first_productive==wave

/*for eol data community only*/
keep if eol_flag==1

/*wealth at first productive - using assigned deciles and quintiles (quints for descriptives, deciles for model)*/
tab totwq10_bu_s
tab totwq5_bu_s
gen totwq10_bu_s_fp = totwq10_bu_s if first_productive==wave
gen totwq5_bu_s_fp = totwq5_bu_s if first_productive==wave
gen nettotw_bu_s_fp = nettotw_bu_s if first_productive==wave

/*items for ACCESS factor, last productive*/
/*flip so higher=better*/
recode unmet_formal (0=1) (1=0), gen(unmetformal_flip)
recode transport_deprived (0=1) (1=0), gen(transport_deprivedflip)
foreach var of varlist unmetformal_flip gp_access dentist_access hospital_access optician_access transport_deprivedflip{
gen `var'_lp=`var' if last_productive==wave
}

/*items for SOMATIC factor, last productive*/
/*flip genhealth and group excellent with very good, and flip chronic and functlimi*/
recode srgeneralh (1 2=3) (3=2) (4=1) (5=0), gen(selfrhealth)
label define selfrhealth 0 poor 1 fair 2 good 3 "vgood or excellent"
label values selfrhealth selfrhealth
tab srgeneralh selfrhealth, mi 
recode chronic (1=0) (0=1)
recode functlimit (1=0) (0=1)
foreach var of varlist meangrip htfvc chairrise functlimit chronic selfrhealth {
gen `var'_lp=`var' if last_productive==wave
}

/*items for SOCIAL SUPPORT, last productive*/
foreach var of varlist scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 ///
scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2 {
gen `var'_lp=`var' if last_productive==wave
}

/*fill up and down these new vars*/
sort idauniq wave 
foreach var of varlist totwq10_bu_s_fp totwq5_bu_s_fp nettotw_bu_s_fp edqual5_fp {
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
gsort idauniq -wave 
foreach var of varlist ///
unmetformal_flip_lp gp_access_lp dentist_access_lp hospital_access_lp optician_access_lp transport_deprivedflip_lp ///
meangrip_lp htfvc_lp chairrise_lp functlimit_lp chronic_lp selfrhealth_lp ///
scchda2_lp scchdb2_lp scchdc2_lp scfama2_lp scfamb2_lp scfamc2_lp scfrda2_lp scfrdb2_lp scfrdc2_lp scchdd2_lp scchde2_lp scchdf2_lp scfamd2_lp scfame2_lp scfamf2_lp scfrdd2_lp scfrde2_lp scfrdf2_lp {
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}

/*drop those who have had a careornusing home addmission*/
drop if anytime_cornhome==1
/*also drop 'other' place of death*/
drop if placeofdeath==5
tab placeofdeath, mi
save "$work\all waves for descriptives.dta", replace

/*keep baseline data only*/
keep if first_productive==wave
save "$work\paper one table one.dta", replace

/*change the scale of fvc, grip and chair so its similar to the other items in somatic factor*/
replace meangrip_lp = meangrip_lp/10
replace chairrise_lp = chairrise_lp/10
replace htfvc_lp=round(htfvc_lp, 0.1)
replace meangrip_lp=round(meangrip_lp, 0.1)
replace chairrise_lp=round(chairrise_lp, 0.1)

/*recode sex so zero is men*/
label list sex
recode sex (1=0) (2=1)
label define sex2 0 men 1 women
label values sex sex2
tab sex

/*set missing to -999 and drop labels*/
foreach var of varlist idauniq hospital hospital_stays ///
ageatdeath sex totwq10_bu_s_fp edqual5_fp ///
unmetformal_flip_lp gp_access_lp dentist_access_lp hospital_access_lp optician_access_lp transport_deprivedflip_lp ///
meangrip_lp htfvc_lp chairrise_lp functlimit_lp chronic_lp selfrhealth_lp ///
scchda2_lp scchdb2_lp scchdc2_lp scfama2_lp scfamb2_lp scfamc2_lp scfrda2_lp scfrdb2_lp scfrdc2_lp scchdd2_lp scchde2_lp scchdf2_lp scfamd2_lp scfame2_lp scfamf2_lp scfrdd2_lp scfrde2_lp scfrdf2_lp {
replace `var'=-999 if `var'==.
gen `var'2 = `var'
}

order idauniq2 hospital2 hospital_stays2 ///
ageatdeath2 sex2 totwq10_bu_s_fp2 edqual5_fp2 ///
unmetformal_flip_lp2 gp_access_lp2 dentist_access_lp2 hospital_access_lp2 optician_access_lp2 transport_deprivedflip_lp2 ///
meangrip_lp2 htfvc_lp2 chairrise_lp2 functlimit_lp2 chronic_lp2 selfrhealth_lp2 ///
scchda2_lp2 scchdb2_lp2 scchdc2_lp2 scfama2_lp2 scfamb2_lp2 scfamc2_lp2 scfrda2_lp2 scfrdb2_lp2 scfrdc2_lp2 scchdd2_lp2 scchde2_lp2 scchdf2_lp2 scfamd2_lp2 scfame2_lp2 scfamf2_lp2 scfrdd2_lp2 scfrde2_lp2 scfrdf2_lp2

keep idauniq2 hospital2 hospital_stays2 ///
ageatdeath2 sex2 totwq10_bu_s_fp2 edqual5_fp2 ///
unmetformal_flip_lp2 gp_access_lp2 dentist_access_lp2 hospital_access_lp2 optician_access_lp2 transport_deprivedflip_lp2 ///
meangrip_lp2 htfvc_lp2 chairrise_lp2 functlimit_lp2 chronic_lp2 selfrhealth_lp2 ///
scchda2_lp2 scchdb2_lp2 scchdc2_lp2 scfama2_lp2 scfamb2_lp2 scfamc2_lp2 scfrda2_lp2 scfrdb2_lp2 scfrdc2_lp2 scchdd2_lp2 scchde2_lp2 scchdf2_lp2 scfamd2_lp2 scfame2_lp2 scfamf2_lp2 scfrdd2_lp2 scfrde2_lp2 scfrdf2_lp2

/*rename shorter for mplus*/
rename idauniq2 id
rename hospital2 pod
rename hospital_stays2 hosp
rename ageatdeath2 age
rename sex2 sex
rename totwq10_bu_s_fp2 wealth
rename edqual5_fp2 edqual
rename unmetformal_flip_lp2 unmetc 
rename gp_access_lp2 gp
rename dentist_access_lp2 dentist
rename hospital_access_lp2 secdry
rename optician_access_lp2 optici
rename transport_deprivedflip_lp2 transp
rename meangrip_lp2 grip
rename htfvc_lp2 fvc
rename chairrise_lp2 chair
rename functlimit_lp2 funct
rename chronic_lp2 chronic
rename selfrhealth_lp2 srhealth
rename scchda2_lp2 chpa
rename scchdb2_lp2 chpb
rename scchdc2_lp2 chpc
rename scfama2_lp2 fampa
rename scfamb2_lp2 fampb
rename scfamc2_lp2 fampc
rename scfrda2_lp2 fripa
rename scfrdb2_lp2 fripb
rename scfrdc2_lp2 fripc
rename scchdd2_lp2 chnd
rename scchde2_lp2 chne
rename scchdf2_lp2 chnf
rename scfamd2_lp2 famnd
rename scfame2_lp2 famne
rename scfamf2_lp2 famnf
rename scfrdd2_lp2 frind
rename scfrde2_lp2 frine
rename scfrdf2_lp2 frinf
save "$work\MPlus 737.dta", replace
outsheet using "$work\MPlus 737.csv", comma replace

/*run the measurement models in mplus and import the fscores data*/
/*somatic*/
clear
import delimited "$raw\outfileSOMATIC.dat", delimiter(" ", collapse)
rename v10 id
rename v8 somatic
keep id somatic
sort id
save "$raw\outfileSOMATIC.dta", replace
/*access*/
clear
import delimited "$raw\outfileACCESS.dat", delimiter(" ", collapse)
rename v10 id
rename v8 access
keep id access
sort id
save "$raw\outfileACCESS.dta", replace
/*social*/
clear
import delimited "$raw\outfileSOCIAL.dat", delimiter(" ", collapse)
rename v28 id
rename v26 social
keep id social
sort id
save "$raw\outfileSOCIAL.dta", replace


/*merge into the main dataset*/
clear 
use "$work\MPlus 737.dta"
sort id
merge 1:1 id using "$raw\outfileSOMATIC.dta"
replace somatic=-999 if somatic==.
drop _merge
sort id
merge 1:1 id using "$raw\outfileACCESS.dta"
replace access=-999 if access==.
drop _merge
sort id
merge 1:1 id using "$raw\outfileSOCIAL.dta"
replace social=-999 if social==.
drop _merge
/*outsheet for use in mplus*/
save "$work\737.dta", replace
outsheet using "$work\737.csv", comma replace


/*investigate the missingness on social*/
foreach var of varlist sex age somatic access social pod hosp wealth edqual{
replace `var'=. if `var'==-999
}
misstable summarize (sex age somatic access social pod hosp wealth edqual), gen(miss_)

logit miss_social sex age somatic pod hosp

/*********************************************************************************/
/*descriptives for elsa paper*/
/*compare whole deceased cohort with eol cohort*/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"" /*WILL NEED TO UPDATE THIS -FILE NO LONGER CREATED EARLIE ON*/
/*create overall sample quintiles and deciles of wealth*/
tab totwq10_bu_s
tab totwq5_bu_s
gen totwq10_bu_s_fp = totwq10_bu_s if first_productive==wave
gen totwq5_bu_s_fp = totwq5_bu_s if first_productive==wave
gen nettotw_bu_s_fp = nettotw_bu_s if first_productive==wave
/*fill up and down these new vars*/
sort idauniq wave 
foreach var of varlist totwq10_bu_s_fp totwq5_bu_s_fp nettotw_bu_s_fp{
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
/*keep baseline data only*/
keep if first_productive==wave
/*simple comparison descriptives*/
tab eol_flag, mi
tab eol_flag sex, row chi
tab eol_flag agecats80, row chi
ttest ageatdeath, by(eol_flag)
ttest frailtyscore_lp, by(eol_flag)
ttest nettotw_bu_s_fp, by(eol_flag)
tab eol_flag totwq5_bu_s, row chi
tab eol_flag edqual5, row chi
tab eol_flag nssec5rec, row chi
tab eol_flag livsppt3, row chi

/*describe structure of the data*/
clear
use "$work\all waves for descriptives.dta"
/*wave entered*/
preserve
keep if first_productive==wave
tab first_productive
restore
/*average num of waves*/
label list prodw4
gen prod1 = 1 if prodw1==1
gen prod2 = 1 if prodw2==1
gen prod3 = 1 if prodw3==1
gen prod4 = 1 if prodw4==1
gen prod5 = 1 if prodw5==1
egen prodwaves=rowtotal(prod1-prod5)
preserve
keep if first_productive==wave
tab prodwaves, mi
sum prodwaves, detail
restore
/*time between death and eol interview*/
gen time1 = SIFdateofeolinterview-SIFdateofdeath
gen time12 = time1/30
preserve
keep if first_productive==wave
replace time12=. if time12<0
sum time12, detail
tab time12, mi
restore
/*time between last interview and death*/
gen time2 = SIFdateofdeath-SIFdateofinterview if last_productive==wave
gen time22 = time2/30
preserve
keep if last_productive==wave
replace time22=. if time22<0
tab time22, mi
sum time22, detail
restore

/*table 1*/
clear
use "$work\paper one table one.dta"
/*age*/
sum ageatdeath
bys sex: sum ageatdeath
bys agecats80: sum ageatdeath
/*sex*/
tab sex, mi
tab sex agecats80, col mi
/*surviving spouse/partner*/
/*1=yes 0=no*/
tab surv_spouse, mi
tab surv_spouse sex, col mi
tab surv_spouse agecats80, col mi
/*cause of death*/
label list maincod
recode maincod (-2 -1=.)
tab maincod, mi
tab maincod sex, col mi
tab maincod agecats80, col mi
/*pod*/
tab placeofdeath, mi
tab placeofdeath sex, col mi
tab placeofdeath agecats80, col mi
/*hosp*/
tab hospital_stays, mi
tab hospital_stays sex, col mi
tab hospital_stays agecats80, col mi
/*wealth*/
tab totwq5_bu_s, mi
tab totwq5_bu_s sex, col mi
tab totwq5_bu_s agecats80, col mi
/*edqual*/
tab edqual5_fp, mi
tab edqual5_fp sex, col mi
tab edqual5_fp agecats80, col mi
/*end of table 1*/

/*supplementary table - latent var item descriptives*/
clear
use "$work\paper one table one.dta"
/*somatic*/
sum meangrip_lp
sum htfvc_lp
sum chairrise_lp
misstable sum (meangrip_lp htfvc_lp chairrise_lp)
tab functlimit_lp, mi
tab chronic_lp, mi
tab selfrhealth_lp, mi
/*access*/
tab gp_access_lp, mi
tab dentist_access_lp, mi 
tab hospital_access_lp, mi 
tab optician_access_lp, mi
tab transport_deprivedflip_lp, mi
tab unmetformal_flip_lp, mi 
/*social support*/
clear
use "$work\paper one table one.dta"
tabout scchda2_lp scchdb2_lp scchdc2_lp scfama2_lp scfamb2_lp scfamc2_lp scfrda2_lp scfrdb2_lp scfrdc2_lp scchdd2_lp scchde2_lp scchdf2_lp scfamd2_lp scfame2_lp scfamf2_lp scfrdd2_lp scfrde2_lp scfrdf2_lp ///
using suptable.csv, style(csv) mi replace oneway c(freq col)

/*center age for descriptive*/
clear
use "$work\paper one table one.dta"
summarize ageatdeath, meanonly
gen centered_age = ageatdeath - r(mean)
sum centered_age, detail

/*end of do file*/
/*************************************************************************************/


