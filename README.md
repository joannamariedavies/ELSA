# ELSA
English Longitudinal Study of Ageing

Data preparation and analysis code in Stata

clear
set more off
capture log close

log using "C:\Users\Joanna\OneDrive - King's College London\ELSA\UKDA-5050-stata\stata\log", replace

cd "C:\Users\Joanna\OneDrive - King's College London\ELSA\UKDA-5050-stata\stata"

global raw "raw"
global work "work"
global output "output"

set maxvar 10000

/*append the end of life data*/
clear
use "$raw\elsa_eol_w2_archive_v1.dta"
append using "$raw\elsa_eol_w3_archive_v1.dta"
append using "$raw\elsa_eol_w4_archive_v1.dta"
append using "$raw\elsa_endoflife_w6archive.dta"
duplicates tag idauniq, gen(dupflag)
/*4 ids are dups, records are not identical*/
/*keep first record, int date closer to date of death*/
duplicates drop idauniq, force
sort idauniq
save "$work\eol w2 to w6 combined.dta", replace

/*merge eol to index data*/
clear 
use "$raw\index_file_wave_0-wave_5_v2.dta"
/*keep core members - only core members eligible for an eol questionnaire - NB: the index file contains info on everyone sampled from HSE plus others living in the household - core members are the representative sample (excluding partners) who responded when initially asked*/
keep if finstatw1==1 | finstatw2==1 | finstatw3==1 | finstatw4==1 | finstatw5==1 ///
| finstatw3==7 | finstatw4==7 | finstatw5==7 ///
| finstatw4==14 | finstatw5==14  
sort idauniq
merge 1:1 idauniq using "$work\eol w2 to w6 combined.dta"
/*NB: 12 records in eol data only are from non-core sample members - they are from people with partner status ///
i dont know why this would happen because i thought only core smaple members were eligible for eol modeule?? - need to check this*/
/*drop these 12 for now*/
/*further thoughts - i think it is justifiable to say we only looked at core members who had died - both for saying how many of the core sample have died and within that how many had an end of life sample*/
drop if _merge==2
save "$work\combined index and eol.dta", replace

/*keep only those with dod year or eol record - trying to identify the sample of all deceased core members ///
some of the end of life cohort dont have a dodyr becuase (i think) the mort data for wave 6 is not yet included*/
clear
use "$work\combined index and eol.dta"
keep if yrdeath!=-2 | _merge==3
tab yrdeath, miss
gen eol_flag=0
replace eol_flag=1 if _merge==3
label define eolflaglab 0 "no eol data" 1 "eol cohort"
label values eol_flag eolflaglab
drop _merge
tab yrdeath eol_flag, miss
save "$work\deceased cohort members only index and eol.dta", replace

/*recode some var taking best available information from each dataset*/
clear
use "$work\deceased cohort members only index and eol.dta"
/*NB the approach here is to take info from the Index file but where this information in incomplete look to the eol file */

/*GEN AGE AT DEATH*/
/*date of death year*/
label list yrdeath
gen yrdeath2=yrdeath
replace yrdeath2=. if yrdeath2==-2 
replace yrdeath2=EiDateY if yrdeath2==.
/*age at death*/
label list dobyear
gen dobyear2=dobyear
replace dobyear2=. if dobyear2==-8 | dobyear2==-7
/*NB dodyr for those who were 99 in 2013 are grouped BE AWARE OF THIS!!!*/
replace dobyear2=1914 if dobyear==-7
/*new age at death var*/
gen ageatdeath=yrdeath2-dobyear2

/*gen surviving spouse at time of death*/
/*NB we cant tell if they were living with spouse*/
label list SurvSp
recode SurvSp (-9 -8 = .) (-1 = 1) (2=0), gen(surv_spouse)
/*1=yes 0=no*/
tab SurvSp surv_spouse

/*depressed last year*/
tab EiMHFC, mi
label list EiMHFC
recode EiMHFC (-9 -8 -1 4 = .) (1 = 0) (2 3 = 1), gen(depresslastyear)
tab EiMHFC depresslastyear, mi

/*count of ADL/IADL, last 3 months*/
foreach var of varlist EiADLA-EiADLJ{
tab `var'
label list `var'
recode `var' (-9 -8 -1 3 =.) (2 = 0) (1 = 1), gen(`var'rec)
tab `var' `var'rec, mi
}
egen adl_iadlscore = rowtotal(EiADLArec EiADLBrec EiADLCrec EiADLDrec EiADLErec EiADLFrec EiADLGrec EiADLHrec EiADLIrec EiADLJrec)
replace adl_iadlscore=. if (EiADLArec==. & EiADLBrec==. & EiADLCrec==. & EiADLDrec==. & EiADLErec==. & EiADLFrec==. & ///
 EiADLGrec==. & EiADLHrec==. & EiADLIrec==. & EiADLJrec==.)

/*count cognitive difficulties - NEED TO COMPLETE THIS
foreach var of varlist EiCogA-EiCogO{
tab `var'
label list `var'
}
*/
 
/*how long was ill*/
label list EiLongW2
label list EiLong
recode EiLong (2=3) (3=4) (4=5) (5=6) (6=7) (7=8) (8=9), gen(howlongill)
label values howlongill EiLongW2
replace howlongill=EiLongW2 if howlongill==.
tab howlongill
tab howlongill EiLongW2
tab howlongill EiLong
/*recode*/
recode howlongill (1 2 3 4 = 1) (5=2) (6=3) (7=4) (8=5) (-9 -8 -1 9 =.), gen(howlongill2)
label define howlongill2 1 "sudden/less than 1 week" 2 "1-4 weeks" 3 "1-6 months" 4 "6-12 months" 5 "1 year+"
label values howlongill2 howlongill2
tab howlongill howlongill2, mi

/*main cause of death*/
label list maincod
label list DVEiCaus
gen maincod2=maincod
replace maincod2=. if maincod2==-2 | maincod2==-1
replace maincod2=DVEiCaus if maincod2==.
replace maincod2=maincod if maincod2==. 
label define maincod2lab 1 cancer 2 CVD 3 respiratory 4 other 5 "external causes" 96 "irrelevant response" -2 "ICD information not available" -1 "Alive or no permission given to check NHSCR records"
label values maincod2 maincod2lab
tab maincod2, miss
tab maincod2 maincod, miss

/*place of death*/
label list EiPlac
tab  EiPlac
gen placeofdeath=.
replace placeofdeath=1 if EiPlac==1 | EiPlac==3 | EiPlac==2
replace placeofdeath=2 if EiPlac==4
replace placeofdeath=3 if EiPlac==5
replace placeofdeath=4 if EiPlac==6 | EiPlac==7 | EiPlac==8
replace placeofdeath=5 if EiPlac==9 | EiPlac==95
label define podlab 1 home 2 hospital 3 hospice 4 "care home" 5 "other/elsewhere"
label values placeofdeath podlab
tab EiPlac placeofdeath, miss

/*gen binary hospital death outcome*/
tab placeofdeath, mi
describe placeofdeath
label list podlab
gen hospital=0
replace hospital=1 if placeofdeath==2
replace hospital=. if placeofdeath==.

/*gen binary hospital or care home v all other*/
gen hospital_carehome=0
replace hospital_carehome=1 if EiPlac==4 | EiPlac==6 | EiPlac==7 | EiPlac==8 | EiPlac==9
tab EiPlac hospital_carehome, mi

/*
/*re-label some of the 'transition' vars EiLive1-9 vars, the label cuts off the actual site but can work it out in combination with the other EIL* vars ///
that ask about 'how many times' and 'in total how long' in each setting - so relabelling based on this*/
tab EiLive4 EiLHospA, miss
label var EiLive4 "other places stayed 2 years before died: HOSPITAL"
tab EiLive5 EiLHpceA, miss
label var EiLive5 "other places stayed 2 years before died: HOSPICE"
tab EiLive6 EiLNursA, miss
label var EiLive6 "other places stayed 2 years before died: NURSING"
tab EiLive7 EiLResA, miss
label var EiLive7 "other places stayed 2 years before died: RESIDENTIAL"
/*NB - the above coding is a guess!! and i cant seem to guess for mixed residential or nursing, or the other sites - this is a temporary solution///
need to ask NatCen*/
*/

/*total number of transitions*/
tab EiPlcN, mi
tab EiLOthA, mi
foreach var of varlist EiPlcN EiLOthA EiLHospA EiLHpceA EiLNursA EiLResA EiLMixA EiLShelA EiLExtA1 EiLExtA2 EiLExtA3 EiLExtA4 EiLExtA5 {
tab `var'
label list `var'
}
foreach var of varlist EiPlcN EiLOthA EiLHospA EiLHpceA EiLNursA EiLResA EiLMixA EiLShelA EiLExtA1 EiLExtA2 EiLExtA3 EiLExtA4 EiLExtA5 {
recode `var' (-9/-1=.), gen (`var'_2)
tab `var' `var'_2
}
egen n_transit = rowtotal(EiPlcN_2-EiLExtA5_2)
label var n_transit "total number of transitions in the last 2 years of life"
tab n_transit , mi
/*gen flag to highlight cases with completely missing transit info ///
NB - no cases are completely missing for transit*/
gen mis_flag=1 if EiPlcN<-1 & EiLOthA<-1 & EiLHospA<-1 & EiLHpceA<-1 & EiLNursA<-1 ///
& EiLResA<-1 & EiLMixA<-1 & EiLShelA<-1 & EiLExtA1<-1 & EiLExtA2<-1 & EiLExtA3<-1 ///
& EiLExtA4<-1 & EiLExtA5<-1
tab n_transit mis_flag, mi
/*recode total transit into cats*/
gen total_transitcats=.
replace total_transitcats=0 if n_transit==0
replace total_transitcats=1 if n_transit==1
replace total_transitcats=2 if n_transit==2
replace total_transitcats=3 if n_transit>=3
label define transitlab2 1 "1" 2 "2" 3 "3 or more"
label values total_transitcats transitlab2
tab n_transit total_transitcats 

/*gen number of hospital admissions*/
tab EiLHospA , mi
tab EiPlcN, mi
gen n_hospital=EiLHospA 
replace n_hospital=EiPlcN if EiPlac==4
tab n_hospital, mi
label list EiLHospA
label list EiPlcN
replace n_hospital=0 if n_hospital==-1
replace n_hospital=. if n_hospital==-8 | n_hospital==-9
tab n_hospital, miss
/*recode hospital stays into cats*/
gen total_hospstays=.
replace total_hospstays=0 if n_hospital==0
replace total_hospstays=1 if n_hospital==1
replace total_hospstays=2 if n_hospital==2
replace total_hospstays=3 if n_hospital>=3
replace total_hospstays=. if n_hospital==.
label define hospitalstaylab2 1 "1" 2 "2" 3 "3 or more"
label values total_hospstays hospitalstaylab2
tab n_hospital total_hospstays, mi 
/*gen binary hospital stays*/
recode n_hospital (0/2=0) (3/100=1) (.=.), gen(hospital_stays)
tab n_hospital hospital_stays, mi
label define hospital_stays 0 "up to 2" 1 "3 or more"
label values hospital_stays hospital_stays

/*total time in hospital*/
tab EiLHospB
label list EiLHospB
label list EiPlcL
tab EiPlcL EiLHospB if EiPlac==4
gen time_inhospital=EiLHospB
replace time_inhospital=EiPlcL if EiLHospB==-1 & EiPlac==4
label values time_inhospital EiPlcL
tab time_inhospital
tab time_inhospital EiLHospB, miss
tab time_inhospital EiPlcL, miss
tab time_inhospital placeofdeath, mi
/*recode - grouped*/
recode time_inhospital (-1=0) (-9 -8 = .) (1=1) (2/3=2) (4/5 =3) (6/7 =4) (8 = 5), gen(time_inhospital2)
label define timeinhosplab 0 "no time" 1 "Less than 24 hours" 2 "One day or more but less than one month" ///
3 "One month or more but less than 6 months" 4 "6 months or more" 8 "Don't know"
label values time_inhospital2 timeinhosplab
tab time_inhospital time_inhospital2, mi
tab n_hospital time_inhospital2, mi
/*recode time in hospital into binary*/
recode time_inhospital (-1 1/2=0) (3/7=1) (-9 -8 8 =.), gen(timein_hospital_binary)
tab time_inhospital timein_hospital_binary, mi
label define timein_hospital_binary 0 "up to one week" 1 "more than 1 week"
label values timein_hospital_binary timein_hospital_binary
/*recode time in hospital into tertiary*/
recode time_inhospital (-1 1=1) (2 3 = 2) (4/7=3) (-9 -8 8 =.), gen(timein_hospital3)
tab time_inhospital timein_hospital3
label define timein_hospital3 1 "less than 24 hours" 2 "1 day to 4 weeks" 3 "one month or more"
label values timein_hospital3 timein_hospital3

/*time spent in nursing or care home*/
tab EiLNursB
tab EiLResB
tab EiLMixB
tab EiPlcL if placeofdeath==4
label list EiLNursB
label list EiLResB
label list EiLMixB
label list EiPlcL
tab EiLNursB EiLResB
tab EiLResB EiLMixB
tab EiLMixB EiLNursB
tab EiPlcL EiLNursB if placeofdeath==4
tab EiPlcL EiLResB if placeofdeath==4
tab EiPlcL EiLMixB if placeofdeath==4
/*gen a combined var*/
gen time_innorchom=EiLNursB
replace time_innorchom=EiLResB if time_innorchom<0 | EiLResB>time_innorchom
replace time_innorchom=EiLMixB if time_innorchom<0 | EiLMixB>time_innorchom
replace time_innorchom=EiPlcL if (placeofdeath==4 & time_innorchom<0) | (placeofdeath==4 & EiPlcL>time_innorchom)
label values time_innorchom EiLMixB 
tab time_innorchom
tab time_innorchom placeofdeath
/*gen any time in care or nursing home home*/
gen  anytime_cornhome = .
replace anytime_cornhome = 0 if  time_innorchom<0 & time_innorchom!=.
replace anytime_cornhome = 1 if  time_innorchom>0 & time_innorchom!=.
tab anytime_cornhome
/*compare against 'where did they stay var'*/
tab EiLive6 anytime_cornhome 
tab EiLive7 anytime_cornhome 
tab EiLive91 anytime_cornhome /*1 mentioned but no time assigned*/
/*gen one month or more*/
gen month_cornhome = .
replace month_cornhome = 0 if (time_innorchom<4 & time_innorchom>0) & time_innorchom!=.
replace month_cornhome = 1 if time_innorchom>=4 & time_innorchom!=.
tab time_innorchom month_cornhome
tab month_cornhome, mi
tab month_cornhome
 
/*recode at peace into bianry*/
tab EiMHFH, mi
label list EiMHFH
recode EiMHFH (1 2=0) (3 4=1) (5=.), gen (peayear)
tab EiMHFH peayear, mi
tab EiMHFI, mi
label list EiMHFI
recode EiMHFI (1 2=0) (3 4=1) (5=.), gen (peace3)
tab EiMHFI peace3, mi
label define peace3 0 "often or sometimes" 1 "rarely or never"
label values peace3 peace3

/*sudden death?*/
tab EiSudd /*was death unexcpected?*/
label list EiSudd
tab EiExPt /*was death expected or unexpected*/
label list EiExPt
tab EiExPt EiSudd, mi
/*recode both vars so the categories work the same way*/
recode EiSudd (1=2) (2=1) (-8=4), gen(EiSudd2)
recode EiExPt (95=3) (96 -8 =4), gen(EiExPt2)
label define expectedlab 1 Expected 2 Unexpected 3 Other 4 "Don't know"
label values EiExPt2 expectedlab
label values EiSudd2 expectedlab
tab EiExPt2 EiExPt, mi
tab EiSudd2 EiSudd, mi
tab EiExPt2 EiSudd2, mi
gen expected=EiExPt2
replace expected=EiSudd2 if EiExPt2==-1 & EiSudd2==2 | EiSudd2==1
label values expected expectedlab
tab expected, mi
tab expected EiExPt2, mi
tab expected EiSudd2, mi
tab howlongill2 expected

/*access to SPC ipu pod + transitions*/
gen HospiceIPU_accessed=0
replace HospiceIPU_accessed=1 if placeofdeath==3 | EiLHpceA_2!=.

/*gen age cats*/
recode ageatdeath (51/84 =1) (85/98 =2), gen(agecats)
label define agecatslab 1 "<85" 2 "85 and over"
label values agecats agecatslab 
tab ageatdeath agecats, mi

/*gen age cats 80 cut off*/
recode ageatdeath (50/79 = 1) (80/100 = 2), gen(agecats80)
label define agecats80 1 "below 80" 2 "80 and above"
label values agecats80 agecats80
tab ageatdeath agecats80, mi

/*gen cancer non-cancer*/
describe maincod2
recode maincod2 (1 =1) (2/5=2) (96 -2 -1=.) , gen (cancer_flag)
tab maincod2 cancer_flag, mi
label define cancerflaglab 1 "cancer" 2 "non-cancer"
label values cancer_flag cancerflaglab

/*gen year binary*/
gen year=1 if yrdeath2==2002 | yrdeath2==2003 | yrdeath2==2004 | yrdeath2==2005 | yrdeath2==2006 | yrdeath2==2007
replace year=2 if yrdeath2==2008 | yrdeath2==2009 | yrdeath2==2010 | yrdeath2==2011 | yrdeath2==2012
label define year_lab 1 "2002-2007" 2 "2008-2012"
label values year year_lab

/*partner at time of death*/
tab SurvSp EiRRel
label list SurvSp
gen surviving_spouse=0 
replace surviving_spouse=1 if SurvSp==-1 | SurvSp==1
tab surviving_spouse

/*who helped
describe EiWHlp1S-EiWHlp17S
describe EiWHlp1-EIWHLPF9 */

/*save all deceased cohort memebers file - gen a deceased flag for use when merging with other datasets*/
sort idauniq
gen deceased=1
save "$work\deceased cohort members only index and eol working prep file.dta", replace

/*save only end of life*/
keep if eol_flag==1
sort idauniq
save "$work\eol only working prep file.dta", replace


/*******************************STRUCTURE OF DATA*******************************************/
/*add some structural variables*/
clear
use "$work\deceased cohort members only index and eol working prep file.dta"
/*gen wave at which death first noted*/
gen wave_death_noted=.
replace wave_death_noted=1 if outindw1==79 | outindw1==99 
replace wave_death_noted=2 if outindw2==90 | outindw2==99 
replace wave_death_noted=3 if outindw3==95 | outindw3==99 
replace wave_death_noted=4 if outindw4==95 
replace wave_death_noted=5 if outindw5==95 

/*gen first and last productive*/
gen last_productive=.
replace last_productive=1 if prodw1==1
replace last_productive=2 if prodw2==1
replace last_productive=3 if prodw3==1
replace last_productive=4 if prodw4==1
replace last_productive=5 if prodw5==1
gen first_productive=.
replace first_productive=5 if prodw5==1
replace first_productive=4 if prodw4==1
replace first_productive=3 if prodw3==1
replace first_productive=2 if prodw2==1
replace first_productive=1 if prodw1==1

/*n of timepoints*/
gen n_timepoints=1+(last_productive-first_productive)
tab n_timepoints
bys eol_flag: sum n_timepoints, detail
ttest n_timepoints, by(eol_flag)

/*create summary structure output*/
tab first_productive eol_flag, mi
tab last_productive eol_flag, mi

/*diagram of deceased cohort members - which intake and which waves of data*/
bys eol_flag finstatw5: tab prodw1, miss
bys eol_flag finstatw5: tab prodw2, miss
bys eol_flag finstatw5: tab prodw3, miss
bys eol_flag finstatw5: tab prodw4, miss
bys eol_flag finstatw5: tab prodw5, miss

/*gen an approximate date of death - based on season and year of death*/
gen season_death=DVEiDateS
replace season_death=EiDateS if DVEiDateS==.
label values season_death DVEiDateS
label list EiDateS 
gen month_death_imp=""
replace month_death_imp="01/01" if season_death==1
replace month_death_imp="01/04" if season_death==2
replace month_death_imp="01/07" if season_death==3
replace month_death_imp="01/10" if season_death==4
gen yrdeath3=yrdeath2
tostring yrdeath3, force replace
gen dateofdeath=month_death + "/" + yrdeath3
gen SIFdateofdeath=date(dateofdeath, "DMY")

/*gen an approximate date of eol proxy interview - based on month and year of interview*/
gen IntDatYY2=IntDatYY
tostring IntDatYY2, force replace
tab IntDatMM
label list IntDatMM
gen IntDatMM2=IntDatMM
replace IntDatMM2=. if IntDatMM==-1
tab IntDatMM2, mi
tostring IntDatMM2, force replace
replace IntDatMM2="01" if IntDatMM2=="1"
replace IntDatMM2="02" if IntDatMM2=="2"
replace IntDatMM2="03" if IntDatMM2=="3"
replace IntDatMM2="04" if IntDatMM2=="4"
replace IntDatMM2="05" if IntDatMM2=="5"
replace IntDatMM2="06" if IntDatMM2=="6"
replace IntDatMM2="07" if IntDatMM2=="7"
replace IntDatMM2="08" if IntDatMM2=="8"
replace IntDatMM2="09" if IntDatMM2=="9"
gen dateofeolinterview= "01/" + IntDatMM2 + "/" + IntDatYY2
gen SIFdateofeolinterview=date(dateofeolinterview, "DMY")

/*NB - date of last interview vars dont seem to correspond with the last productive ///
wave info - so gen date of last interview from the core dataset instead*/

save "$work\deceased cohort members only index and eol working prep file.dta", replace

/****************************PREP THE OTHER DATASETS***************************/
/*financial derived data*/
/*var: net non-pension wealth*/
/*gen a wave var*/
clear
use "$raw\wave_1_financial_derived_variables.dta"
gen wave=1
save "$work\wave_1_financial_derived_variables.dta", replace
clear
use "$raw\wave_2_financial_derived_variables.dta"
gen wave=2
save "$work\wave_2_financial_derived_variables.dta", replace
clear
use "$raw\wave_3_financial_derived_variables.dta"
gen wave=3
save "$work\wave_3_financial_derived_variables.dta", replace
clear
use "$raw\wave_4_financial_derived_variables.dta"
gen wave=4
save "$work\wave_4_financial_derived_variables.dta", replace
clear
use "$raw\wave_5_financial_derived_variables.dta"
gen wave=5
save "$work\wave_5_financial_derived_variables.dta", replace

clear
use "$work\wave_1_financial_derived_variables.dta"
append using "$work\wave_2_financial_derived_variables.dta"
append using "$work\wave_3_financial_derived_variables.dta"
append using "$work\wave_4_financial_derived_variables.dta"
append using "$work\wave_5_financial_derived_variables.dta"
/*keep the total net wealth (including housing) and the imputation vars*/
/*suffix info
_bu - benefir unit
_s - summary var derived from other vars
_t - describes type of imputation that took place - 0=no imputation
_f - validation from imputation - for those individuals where imputation was not possible it tells you why the imputation didnt happen
_ni# - describe category and number of variables that were imputed, e.g. _ni4 tell us the number of 'missing positive' or 'missing completly' vars that were imputed */
keep idauniq wave idahhw1 perid coupid futype fuid bueq ///
nettotw_bu_s nettotw_bu_f nettotw_bu_t nettotw_bu_ni2 nettotw_bu_ni3 nettotw_bu_ni4 ///
totwq5_bu_s totwq10_bu_s totwq10_bu_f totwq5_bu_f yq5_bu_s tnhwq5_bu_s
/*wealth recode*/
label list nettotw_bu_s
replace nettotw_bu_s=. if nettotw_bu_s==-999 | nettotw_bu_s==-998 | nettotw_bu_s==-995
format nettotw_bu_s %12.0f
save "$work\wave 1 to 5 financial derived data net non pension wealth.dta", replace



/************************PREPARE THE CORE DATA*****************************/
/*WAVE 0*/
/*only needed for the general health var*/
clear
use "$raw\wave_0_common_variables_v2.dta"
tab genhelf, mi
label list genhelf 
tab genhelf2, mi
label list genhelf2 
gen W0_general_health=0
replace W0_general_health=1 if genhelf==4 | genhelf==5
replace W0_general_health=. if genhelf<0
tab genhelf W0_general_health, mi
tab W0_general_health, mi
/*gen wave num*/
gen wave=0
/*waist to hip ratio*/
gen waist_tohip=.
/*women*/
replace waist_tohip=1 if (whval>0 & whval<0.85) & sex==2
replace waist_tohip=0 if whval>=0.85 & sex==2
/*men*/
replace waist_tohip=1 if (whval>0 & whval<0.95) & sex==1
replace waist_tohip=0 if whval>=0.95 & sex==1
label define waist_tohip 1 "not raised" 0 "raised"
label values waist_tohip waist_tohip
bys sex waist_tohip: sum whval
/*keep only the vars i need*/
keep idauniq wave waist_tohip
save "$work\wave_0_common_variables_v2_prepped.dta", replace
/*************************************************************************/
/*WAVE 1*/
clear
use "$raw\wave_1_core_data_v3.dta"
/*interview date*/
tab iintdtm
tab iintdty
label list iintdtm
label list iintdty
tostring iintdtm, force replace
tostring iintdty, force replace
gen dateofinterview= "01/" + iintdtm + "/" + iintdty 
gen SIFdateofinterview=date(dateofinterview, "DMY")
/*gen wave num*/
gen wave=1
/*ethnicity*/
tab aethnicr
tab fqethnr
label list aethnicr
label list fqethnr
gen ethnicity=.
replace ethnicity=1 if fqethnr==1 | aethnicr==1
replace ethnicity=2 if fqethnr==2 | aethnicr==2
label define ethnicitylab 1 White 2 "Non-white"
label values ethnicity ethnicitylab
tab ethnicity, mi
tab fqethnr ethnicity, mi
tab aethnicr ethnicity, mi
/*NS-SEC*/
/*wave 1 only have long version of ns-sec - need to recode into 8 5 and 3 cats*/
tab anssec /*long from HSE*/
label list anssec
/*8 cat*/
gen nssec8=.
/*1 "Higher managerial and professiomnal occupations"*/
replace nssec8=1 if anssec==1
replace nssec8=1 if anssec==2
replace nssec8=1 if anssec>=3.1 & anssec<=3.4
/*2 "Lower managerial and professional occupations"*/
replace nssec8=2 if anssec>=4.1 & anssec<=4.4
replace nssec8=2 if anssec==5 
replace nssec8=2 if anssec==6
/*3 "Intermediate occupations"*/
replace nssec8=3 if anssec>=7.1 & anssec<=7.4
/*4 "Small employers and own account workers"*/
replace nssec8=4 if anssec==8.1 | anssec==8.2
replace nssec8=4 if anssec==9.1 | anssec==9.2
/*5 "Lower supervisory and technical occupations"*/
replace nssec8=5 if anssec==10
replace nssec8=5 if anssec==11.1 | anssec==11.2
/*6 "Semi-routine accupations"*/
replace nssec8=6 if anssec>=12.1 & anssec<=12.7
/*7 " Routine occupations"*/
replace nssec8=7 if anssec>=13.1 & anssec<=13.5
/*8 "Never worked and long term unemployment"*/
replace nssec8=8 if anssec==14
/*99 "Other"*/
replace nssec8=99 if anssec==15
replace nssec8=99 if anssec==16
replace nssec8=99 if anssec==17
/*label*/
label define nssec8lab 1 "Higher managerial and professiomnal occupations" 2 "Lower managerial and professional occupations" 3 "Intermediate occupations" ///
4 "Small employers and own account workers" 5 "Lower supervisory and technical occupations" 6 "Semi-routine accupations" 7 " Routine occupations"  ///
8 "Never worked and long term unemployment" 99 "Other"
label values nssec8 nssec8lab
tab anssec nssec8, miss
/*this seems to work - need to check the cross-tab again*/
/*BUT WHY NO CAT 8# 'never worked' - it is in the label for the original var but no cases asigned ///
another var 'have you ever done any paid work?' wpever - but the overlap is poor PLUS this ever worked var also exists in the other datasets //
and has poor overlap there too - so i dont think this var i used to impute never worked status. ///
NB: i need to check this with panos but for now just include with note in the descriptives*/
/*also keep note of these two other vars:
enssec - i think this is nssec but only if different from eqarlier hse record - so ///
could decide to use a combination of the anssec and enssec - again need to speak to panos about this///
asoccls - this is the old SEG cats i think so not useful really*/
/*5 cat*/
gen nssec5=.
/*1 "Managerial and professional occupations"*/
replace nssec5=1 if nssec8==1 | nssec8==2
/*2 "Intermediate occupations"*/
replace nssec5=2 if nssec8==3
/*3 "Small employers and own account workers"*/
replace nssec5=3 if nssec8==4
/*4 "Lower supervisory and technical occupations"*/
replace nssec5=4 if nssec8==5
/*5 "Semi-routine and routine occupations"*/
replace nssec5=5 if nssec8==6 | nssec8==7
/*99 "Other"*/
replace nssec5=99 if nssec8==99 | nssec8==8
/*label*/
label define nssec5lab -3 "Incomplete/No job info collected" -1 "Not applicable" 1 "Managerial and professional occupations" 2 "Intermediate occupations" ///
3 "Small employers and own account workers" 4 "Lower supervisory and technical occupations" 5 "Semi-routine and routine occupations" 99 "Other"
label values nssec5 nssec5lab
tab nssec8 nssec5, miss
/*3 cat*/
gen nssec3=.
/*1 "Managerial and professional occupations"*/
replace nssec3=1 if nssec5==1
/*2 "Intermediate occupations"*/
replace nssec3=2 if nssec5==2 | nssec5==3
/*3 "Routine and manual occupations"*/
replace nssec3=3 if nssec5==4 | nssec5==5
/*99 "Other"*/
replace nssec3=99 if nssec5==99
/*label*/
label define nssec3lab -3 "Incomplete/No job info collected" -1 "Not applicable" 1 "Managerial and professional occupations" 2 "Intermediate occupations" ///
3 "Routine and manual occupations" 99 "Other"
label values nssec3 nssec3lab
tab nssec5 nssec3, miss
/*************************/
/*HOUSING TENURE - coding from wave 4 and 6 reports*/
tab atenureb
label list atenureb
recode atenureb (2 3 =2) (4 5 =3) (6 =4) (-9 -8 -1 =.), gen(tenure2)
label define atenureb2 1 "Owner occupied" 2 "Buying with mortgage" 3 "Renting or rent free" 4 "Other" 
label values tenure2 atenureb2
tab atenureb tenure2, mi
/************************/
/*EDUCATION*/
tab edqual /*high qual*/
label list edqual
/*recode highest qual as in panos wealth paper*/ /*
recode edqual (1/3=1) (4/6=2) (7=3) (-9 -8 -1 =.), gen(edqual2)
label define edqual2lab 1 "A-level or higher" 2 "GCSE/O-level/other qualification" 3 "No qualification"
label values edqual2 edqual2lab
tab edqual edqual2, mi */
/*tab fqend*/ /*age finish compuls edu*/
/*tab aeducend*/ /*age finish use this one*/
/*years of ed*/
tab fqend
tab aeducend
tab fqend aeducend, mi
label list fqend 
label list aeducend
gen edu_yearsof=aeducend
replace edu_yearsof=fqend if aeducend==-9 | aeducend==-8 | aeducend==-1
tab aeducend edu_yearsof 
label values edu_yearsof aeducend
tab edu_yearsof, mi
/**************************/
/*PATERNAL OCCUPATIONAL CLASS AT 14*/
/*recode fathers occu as in panos wealth paper*/
tab difjob /*fathers occup*/
label list difjob
recode difjob (2 3 4 = 1) (5 6 = 2) (7 8 9 12 14 15 = 3) (10 11 13 1 = 4) (-9 -8 -1 =.), gen(difjob2)
label define difjob2lab 1 "Managerial and professional occupations/run own business" ///
2 "Intermediate occupations" 3 "Routine occupations/casual jobs/unemployed/disabled" ///
4 "Other (incl Armed Forces and Retired)"
label values difjob2 difjob2lab
tab difjob difjob2, mis
/*****************************/
/*SUBJECTIVE SOCIAL STATUS - 10 RUNG*/
tab sclddr /*sss*/
label list sclddr
recode sclddr (5 10 =10) (15 20=20) (25 30 =30) (35 40 =40) (45 50 =50) (55 60 =60) (65 70 =70) (75 80 =80) ///
(85 90 =90) (95 100 =100) (-9/-1 =.), gen(sclddr2)
tab sclddr sclddr2, mi
/*tab hodiff*/ /*In the last 12 months would you say you have had difficulties paying for your accommodation?*/
/*tab hodifft*/ /*In the last 12 months have you ever found yourself more than two months behind with your rent/mortgage?*/
/*******************************/
/*ITEMS FOR MATERIAL DEPRIVATION FACTOR*/
/*HOUSING PROBLEMS*/
/*lack of central heating*/
tab hocenh 
label list hocenh 
gen central_heat=0
replace central_heat=1 if hocenh==2
replace central_heat=. if hocenh<0
tab central_heat, mi
/*type of heating*/
/*foreach var of varlist hoohea1-hoohea3 hoohem1-hoohem3{
tab `var'
} */
foreach var of varlist hoprm01-hoprm10{
tab `var'
describe `var'
label list `var'
}
gen space=0
gen dark=0
gen damp=0
gen roof=0
gen condensation=0
gen electrics=0
gen rot=0
gen pests=0
gen cold=0
foreach var of varlist hoprm01-hoprm10{
replace space=1 if `var'==1
replace dark=1 if `var'==4
replace damp=1 if `var'==6
replace roof=1 if `var'==7
replace condensation=1 if `var'==8
replace electrics=1 if `var'==9
replace rot=1 if `var'==10
replace pests=1 if `var'==11
replace cold=1 if `var'==12
}
egen num_housing_probs=rowtotal(central_heat-cold)
replace num_housing_probs=. if hoprm01<0
tab num_housing_probs, mis
/*also these other 'merged vars' hoprm01-hoprm10 - include some extra cats ///
but not needed*/
/*gen binary housing*/
gen housing_prob=.
replace housing_prob=0 if num_housing_probs>=1 & num_housing_probs!=.
replace housing_prob=1 if num_housing_probs==0
label define housing_prob 0 problems 1 "no problems"
label values housing_prob housing_prob
tab num_housing_probs housing_prob, mi
/************************************/
/*DURABLES*/
foreach var of varlist hohav01-hohav11{
tab `var'
label list `var'
}
gen tv=0
gen video_rec=0
gen cd_player=0
gen freezer=0
gen wash_machin=0
gen tumble_dry=0
gen dishwash=0
gen microwave=0
gen computer=0
gen sat_tv=0
gen phone=0
foreach var of varlist hohav01-hohav11{
replace tv=1 if `var'==1
replace video_rec=1 if `var'==2
replace cd_player=1 if `var'==3
replace freezer=1 if `var'==4
replace wash_machin=1 if `var'==5
replace tumble_dry=1 if `var'==6
replace dishwash=1 if `var'==7
replace microwave=1 if `var'==8
replace computer=1 if `var'==9
replace sat_tv=1 if `var'==10
replace phone=1 if `var'==11
}
egen count_durables=rowtotal(tv video_rec cd_player freezer wash_machin tumble_dry ///
 dishwash microwave computer sat_tv phone)
/*condition the score*/
recode count_durables (0 1=0) (2/4=1) (5/8=2) (9/11=3), gen(num_durables)
replace num_durables=. if hohav01<0 
replace num_durables=3 if hohav01==95
replace num_durables=0 if hohav01==96
label define num_durables 0 "<2" 1 "2-4" 2 "5-8" 3 ">8"
label values num_durables num_durables
tab num_durables, mi
/*******************************************/
/*TRANSPORT*/
/*car, van or motorbike ownership*/
tab hoveh
label list hoveh
gen car_ownership=.
replace car_ownership=0 if hoveh==0
replace car_ownership=1 if hoveh>=1
label define car_ownership 0 "no car or van" 1 "at least 1 car, van or motorbike"
label values car_ownership car_ownership 
tab hoveh car_ownership, mi
tab car_ownership, mi
/**************/
/*tenure binary*/
recode atenureb (1 2 3=1) (4 5 6=0) (-9 -8 -1 =.), gen(tenure3)
label define tenure3 1 "owner" 0 "other"
label values tenure3 tenure3
tab atenureb tenure3, mi
/***************************/
/*private insurance*/
tab wpphi
label list wpphi
gen private_health=.
replace private_health=0 if wpphi==3
replace private_health=1 if wpphi==1 | wpphi==2
label define private_health 0 "no private insurance" 1 "private insurance"
label values private_health private_health
tab wpphi private_health, mi
/************************/
foreach var of varlist sptrm01-sptrm06{
tab `var'
label list `var'
}

tab spcar
label list spcar

gen dont_need_to=0
foreach var of varlist sptrm01-sptrm06{
replace dont_need_to=1 if `var'==5
}
replace dont_need_to=. if sptrm01<0
tab dont_need_to, mi

tab sptraa
label list sptraa
gen transport_deprived=0
replace transport_deprived=1 if spcar==2 & (sptraa==4 | sptraa==5 & dont_need_to!=1)
replace transport_deprived=. if spcar<0 & sptraa<0 
tab transport_deprived, mi
tab spcar transport_deprived, mi
tab sptraa transport_deprived, mi
/*************************************/
/*SOCIAL INTEGRATION - see Banks 2010, and Ding 2017*/
/*higher is optimal*/
/*living with spouse or partner*/ 
/*NB wording of questions is 'do you have a husband or wife with whom you live?*/
/*need to check posibly with Ding that this is the correct var to use - it doesnt use the broader term spouse but i cant see a question that does*/
recode scptr (-9 -1 =.) (2 = 0), gen(livsppt)
label var livsppt "living with spouse or partner"
/*do you have children family friends*/
foreach var of varlist scchd scfam scfrd{
tab `var'
label list `var'
}
/*contact with children, family, friends (including: face to face, phone, email or write)*/
/*NB for each group taking the highest from face to face, phone or email - this is not the only way to do this - you could for example take the average across the 3 types of contact ///
/// just be aware that this is essentially an arbritrary decision that could be questioned*/
foreach var of varlist scchdg scchdh scchdi scfamg scfmh scfami scfrdg scfrdh scfrdi {
tab `var'
label list `var'
recode `var' (-9 -1 = .) (1 2 = 3) (3 = 2) (4 = 1) (5 6 = 0), gen(`var'2)
}
replace scchdg2=0 if scchd==2
replace scchdh2=0 if scchd==2
replace scchdi2=0 if scchd==2
egen chicontact = rowmax(scchdg2 scchdh2 scchdi2)
label var chicontact "contact with children"
replace scfamg2=0 if scfam==2
replace scfmh2=0 if scfam==2
replace scfami2=0 if scfam==2
egen famcontact = rowmax(scfamg2 scfmh2 scfami2)
label var famcontact "contact with family"
replace scfrdg2=0 if scfrd==2
replace scfrdh2=0 if scfrd==2
replace scfrdi2=0 if scfrd==2
egen friecontact = rowmax(scfrdg2 scfrdh2 scfrdi2)
label var friecontact "contact with friends"
/*low membership of organisations*/
/*NB im including 'any other group' Ding does not include but i cant see a good reason for not including*/
foreach var of varlist scorg1 scorga2 scorg4 scorg5 scorg6 scorg7 scorg8{
tab `var'
label list `var'
recode `var' (-9 -1 = . ), gen (`var'2)
}
egen totalorgs = rowtotal (scorg12-scorg82)
replace totalorgs=. if (scorg12==. & scorga22==. & scorg42==. & scorg52==. & scorg62==. & scorg72==. & scorg82==.)
tab totalorgs, mi
recode totalorgs (1 2 = 1) (3 4 = 2) (5 6 7 = 3), gen(memorg)
label var memorg "membership of organisations"
tab memorg, mi
/*member of religious group*/
tab scorg3
label list scorg3
recode scorg3 (-9 -1 = .), gen (memreg)
label var memreg "membership of religious group"
tab memreg, mi
/*total social integration score - generate this after appending all files and imputing data for each component*/
/****************************************/
/*SOCIAL SUPPORT - see Banks 2010, and Dings 2017*/
/*do you have partner, children, family, friends?*/
foreach var of varlist scptr scchd scfam scfrd{
tab `var'
label list `var'
}
/*positive relationships with children, family and friends*/
foreach var of varlist scptra scptrb scptrc scchda scchdb scchdc scfama scfamb scfamc scfrda scfrdb scfrdc {
tab `var'
label list `var'
recode `var' (-9 -1 = .) (1 = 3) (3 = 1) (4 = 0), gen(`var'2)
tab `var' `var'2, mi
}
/*negative relationships with children, family and friends*/
foreach var of varlist scptrd scptre scptrf scchdd scchde scchdf scfamd scfame scfamf scfrdd scfrde scfrdf {
tab `var'
label list `var'
recode `var' (-9 -1 = .) (1 = 0) (2 = 1) (3 = 2) (4 = 3), gen(`var'2)
tab `var' `var'2, mi
}

replace scptra2=0 if scptr==2
replace scptrb2=0 if scptr==2 
replace scptrc2=0 if scptr==2 
replace scptrd2=0 if scptr==2 
replace scptre2=0 if scptr==2 
replace scptrf2=0 if scptr==2

replace scchda2=0 if scchd==2
replace scchdb2=0 if scchd==2
replace scchdc2=0 if scchd==2
replace scchdd2=0 if scchd==2
replace scchde2=0 if scchd==2
replace scchdf2=0 if scchd==2

replace scfama2=0 if scfam==2
replace scfamb2=0 if scfam==2
replace scfamc2=0 if scfam==2
replace scfamd2=0 if scfam==2
replace scfame2=0 if scfam==2
replace scfamf2=0 if scfam==2

replace scfrda2=0 if scfrd==2
replace scfrdb2=0 if scfrd==2
replace scfrdc2=0 if scfrd==2
replace scfrdd2=0 if scfrd==2
replace scfrde2=0 if scfrd==2
replace scfrdf2=0 if scfrd==2
/*total social support score - generate this after appending all files and imputing data for each component*/
/*

/*QUALITY OF RELATIONSIPS*/
/*do you have partner, children, family, friends?*/
foreach var of varlist scptr scchd scfam scfrd{
tab `var'
label list `var'
}
/*contact and quality of relationship with spouse/partner*/
foreach var of varlist scptra-scptrg{
tab `var'
label list `var'
}
foreach var of varlist scptra scptrb scptrc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scptrd scptre scptrf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_partner=rowtotal(scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2)
replace quality_partner=. if scptra2==. & scptrb2==. & scptrc2==. & scptrd2==. & ///
 scptre2==. & scptrf2==. 
tab quality_partner, mi
tab quality_partner scptr, mi
/*contact and quality of relationship with children*/
foreach var of varlist scchda-scchdm{
tab `var'
label list `var'
}
foreach var of varlist scchda scchdb scchdc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scchdd scchde scchdf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_children=rowtotal(scchda2 scchdb2 scchdc2 scchdd2 scchde2 scchdf2)
replace quality_children=. if scchda2==. & scchdb2==. & scchdc2==. & scchdd2==. & ///
 scchde2==. & scchdf2==. 
tab quality_children, mi
tab quality_children scchd, mi 
/*contact and quality of relationship with family*/
foreach var of varlist scfama-scfamm{
tab `var'
label list `var'
}
foreach var of varlist scfama scfamb scfamc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scfamd scfame scfamf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_family=rowtotal(scfama2 scfamb2 scfamc2 scfamd2 scfame2 scfamf2)
replace quality_family=. if scfama2==. & scfamb2==. & scfamc2==. & scfamd2==. & ///
 scfame2==. & scfamf2==. 
tab quality_family, mi
tab quality_family scfam, mi
/*contact and quality of relationship with friends*/
foreach var of varlist scfrda-scfrdm{
tab `var'
label list `var'
}
foreach var of varlist scfrda scfrdb scfrdc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scfrdd scfrde scfrdf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_friends=rowtotal(scfrda2 scfrdb2 scfrdc2 scfrdd2 scfrde2 scfrdf2)
replace quality_friends=. if scfrda2==. & scfrdb2==. & scfrdc2==. & scfrdd2==. & ///
 scfrde2==. & scfrdf2==. 
tab quality_friends, mi
tab quality_friends scfrd, mi
/*SOCIAL ISOLATION*/
tab scptr
label list scptr
foreach var of varlist scchdi scfami scfrdi{
tab `var'
label list `var'
}
gen social_isolation=0
replace social_isolation=1 if scptr==2 & (scchdi!=1 | scfami!=1 | scfrdi!=1)
replace social_isolation=. if scptr<0 & scchdi<0 & scfami<0 & scfrdi<0
tab social_isolation, mi */
/************************************************/
/*FRAILTY INDEX*/
/*mobility difficulties*/
foreach var of varlist heada01-heada11{
tab `var', mi
label list `var'
}
gen M_walking=0
gen M_sitting=0
gen M_getting_up=0
gen M_stairs_several=0
gen M_stairs_one=0
gen M_stoop=0
gen M_reaching=0
gen M_pulling=0
gen M_lifting=0
gen M_picking=0
gen missing_flag=0
replace missing_flag=1 if heada01<0 
foreach var of varlist heada01-heada11{
replace M_walking=1 if `var'==1
replace M_sitting=1 if `var'==2
replace M_getting_up=1 if `var'==3
replace M_stairs_several=1 if `var'==4
replace M_stairs_one=1 if `var'==5
replace M_stoop=1 if `var'==6
replace M_reaching=1 if `var'==7
replace M_pulling=1 if `var'==8
replace M_lifting=1 if `var'==9
replace M_picking=1 if `var'==10
}
tab missing_flag, mi
foreach var of varlist M_walking-M_picking{
replace `var'=. if missing_flag==1
tab `var', mi
}
drop missing_flag
/*disability ADL/iADL*/
foreach var of varlist headb01-headb14{
tab `var', mi
label list `var'
}
gen ADL_dressing=0
gen ADL_walking=0
gen ADL_bathing=0
gen ADL_eating=0
gen ADL_outofbed=0
gen ADL_toilet=0
gen ADL_usingmap=0
gen ADL_hotmeal=0
gen ADL_shopping=0
gen ADL_telephone=0
gen ADL_medication=0
gen ADL_housework=0
gen ADL_money=0
gen missing_flag=0
replace missing_flag=1 if heada01<0 
foreach var of varlist headb01-headb14{
replace ADL_dressing=1 if `var'==1 
replace ADL_walking=1 if `var'==2 
replace ADL_bathing=1 if `var'==3 
replace ADL_eating=1 if `var'==4 
replace ADL_outofbed=1 if `var'==5 
replace ADL_toilet=1 if `var'==6 
replace ADL_usingmap=1 if `var'==7 
replace ADL_hotmeal=1 if `var'==8 
replace ADL_shopping=1 if `var'==9 
replace ADL_telephone=1 if `var'==10 
replace ADL_medication=1 if `var'==11
replace ADL_housework=1 if `var'==12 
replace ADL_money=1 if `var'==13
} 
tab missing_flag, mi
foreach var of varlist ADL_dressing-ADL_money{
replace `var'=. if missing_flag==1
tab `var', mi
}
drop missing_flag
/*general health*/
/*NB - a lot of missing for this one - wave 0 questions much more complete*/
/*suggest use info from wave 0*/
tab hegenh, mi 
label list hegenh
tab hehelfb, mi
label list hehelfb
tab hehelfb hegenh, mi
gen general_health=0
replace general_health=1 if hehelfb==4 | hehelfb==5
replace general_health=. if hehelfb<0
tab hehelfb general_health, mi
tab general_health, mi
/*2nd general health var*/
recode hehelfb (-9/-1=.), gen(srgeneralh)
label values srgeneralh hehelfb
tab hehelfb srgeneralh, mi
/*depressive symptoms*/
foreach var of varlist psceda-pscedc pscede pscedg pscedh{
tab `var'
label list `var'
recode `var' (2=0) (-9/-1=.), gen (dep_`var')
tab `var' dep_`var', mi
}

foreach var of varlist pscedf pscedd{
tab `var'
label list `var'
recode `var' (2=1) (1=0) (-9/-1=.), gen(dep_`var')
tab `var' dep_`var', mi
}
/*high BP - stroke -USE THIS ONE*/
foreach var of varlist hedim01-hedim07{
tab `var', mi
label list `var'
}
gen highBP=0
gen angina=0
gen heartattack=0
gen congestHF=0
gen abnormalheart=0
gen diabetes=0
gen stroke=0
gen miss_flag=0
replace miss_flag=1 if hedim01<0
foreach var of varlist hedim01-hedim07{
replace highBP=1 if `var'==1
replace angina=1 if `var'==2
replace heartattack=1 if `var'==3
replace congestHF=1 if `var'==4
replace abnormalheart=1 if `var'==6
replace diabetes=1 if `var'==7
replace stroke=1 if `var'==8
}
foreach var of varlist highBP-stroke{
replace `var'=. if miss_flag==1
tab `var', mi
}
drop miss_flag
/*chronic lung - dementia*/
foreach var of varlist hedib01-hedib10{
tab `var', mi
label list `var'
}
gen chroniclung=0
gen asthma=0
gen arthritis=0
gen osteoporosis=0
gen cancer=0
gen parkinsons=0
gen anyemotional=0
gen alzheimers=0
gen dementia=0
gen miss_flag=0
replace miss_flag=1 if hedib01<0
foreach var of varlist hedib01-hedib10{
replace chroniclung=1 if `var'==1
replace asthma=1 if `var'==2
replace arthritis=1 if `var'==3
replace osteoporosis=1 if `var'==4
replace cancer=1 if `var'==5
replace parkinsons=1 if `var'==6
replace anyemotional=1 if `var'==7
replace alzheimers=1 if `var'==8
replace dementia=1 if `var'==9
}
foreach var  of varlist chroniclung-dementia{
replace `var'=. if miss_flag==1
tab `var', mi
}
drop miss_flag
/*eyesight*/
tab heeye, mi
label list heeye
recode heeye (-9/-1=.) (1/3=0) (4/6=1), gen(eyesight)
tab heeye eyesight, mi
/*hearing*/
tab hehear, mi
label list hehear
recode hehear (-9/-1=.) (1/3=0) (4/5=1), gen(hearing)
tab hehear hearing, mi
/*cognitive function*/
/*date test*/
tab cfdatd, mi
label list cfdatd
recode cfdatd (-9/-1=.) (2=1) (1=0), gen(todaysdate)
/**/
tab cfdatm, mi
label list cfdatm
recode cfdatm (-9/-1=.) (2=1) (1=0), gen(month)
/**/
tab cfdaty, mi
label list cfdaty
recode cfdaty (-9/-1=.) (2=1) (1=0), gen(year)
/**/
tab cfday, mi
label list cfday
recode cfday (-9/-1=.) (2=1) (1=0), gen(dayofweek)
/*word recall*/
/*delay*/
tab cflisd, mi
label list cflisd
recode cflisd (-9/-1=.), gen(word_recall_delay)
tab cflisd word_recall_delay, mi
/*immediately*/
tab cflisen, mi
label list cflisen
recode cflisen (-9/-1=.), gen(word_recall_immed)
tab cflisen word_recall_immed, mi
/*rename for consistency*/
rename scfmh2 scfamh2
rename scorg12 scorg012
rename scorga22 scorg022
rename scorg42 scorg042
rename scorg52 scorg052
rename scorg62 scorg062
rename scorg72 scorg072
rename scorg82 scorg082
/**************************************/
/*unmet need score*/
/*************/
/*move round house*/
gen move_need=1 if ADL_walking==1
replace move_need=0 if ADL_walking==0
/*wash or dress*/
gen washdress_need=1 if ADL_bathing==1 | ADL_dressing==1
replace washdress_need=0 if ADL_bathing==0 | ADL_dressing==0 
/*prepare meal or eat*/
gen mealeat_need=1 if ADL_hotmeal==1 | ADL_eating==1
replace mealeat_need=0 if ADL_hotmeal==0 | ADL_eating==0
/*shopping or housework*/
gen shophous_need=1 if ADL_housework==1 | ADL_shopping==1
replace shophous_need=0 if ADL_housework==0 | ADL_shopping==0 
/*phone or money*/
gen phonemon_need=1 if ADL_telephone==1 | ADL_money==1
replace phonemon_need=0 if ADL_telephone==0 | ADL_money==0
/*medications*/
gen medicat_need=1 if ADL_medication==1
replace medicat_need=0 if ADL_medication==0

egen adliadl_items=rownonmiss(move_need washdress_need mealeat_need shophous_need phonemon_need medicat_need)
tab adliadl_items, mi /* NB cases either have all 6 answers or missing on all - if missing on less than 6, may need to set some to missing*/
egen total_adliadl_items=rowtotal(move_need washdress_need mealeat_need shophous_need phonemon_need medicat_need)
replace total_adliadl_items=. if adliadl_items<6 
/****************************************/
/*recieved care?*/
gen care_flag=0
gen formal_care=0
foreach var of varlist hehpb01-hehpb16{
tab `var', mi
label list `var'
replace care_flag=1 if `var'>0 & `var'!=.
replace care_flag=. if hehpb01<0 & total_adliadl_items==.
replace formal_care=1 if `var'==13 | `var'==14
replace formal_care=. if hehpb01<0 & total_adliadl_items==.
/*only set to missing where no record of care need & no record of care recieved///
those without care need were not asked about care recieved...these are not missing1**/
}
/*unmet care need?*/
gen unmet_flag=0
gen unmet_formal=0
foreach var of varlist move_need washdress_need mealeat_need shophous_need phonemon_need medicat_need {
replace unmet_flag=1 if `var'==1 & care_flag!=1
replace unmet_formal=1 if `var'==1 & formal_care!=1
}
/*set to missing if who cares vars were missing*/
replace unmet_flag=. if care_flag==.
replace unmet_formal=. if formal_care==. 
/*set to missing if need care vars were mising*/
replace unmet_flag=. if adliadl_items==0
replace unmet_formal=. if adliadl_items==0
/****************************************************/ 
/*CASP plus control, create vars for latent psychosocial path*/
/*positively worded*/
foreach var of varlist scqolc scqole scqolg{
recode `var' (1=3) (2=2) (3=1) (4=0), gen(`var'2)
}
/*negatively worded*/
foreach var of varlist scqola scqolb scqold scqolf {
recode `var' (1=0) (2=1) (3=2) (4=3), gen(`var'2)
}
/*2 extra questions, not casp*/
/*positive*/ recode scdca (1=5) (2=4) (3=3) (4=2) (5=1) (6=0), gen(scdca2)
/*negative*/ recode scdcc (1=0) (2=1) (3=2) (4=3) (5=4) (6=5), gen(scdcc2) 

order scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2, after(scqolg)
browse scqola scqolb scqolc scqold scqole scqolf scqolg scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca scdca2 scdcc scdcc2
foreach var of varlist scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca2 scdcc2 {
replace `var'=. if `var'<0
}
/*ITEMS FOR BEHAVIOURAL FACTOR*/
/*SMOKING*/
/*ever smoked*/
tab hesmk
label list hesmk
/*currently*/ 
tab heska
label list heska
tab hesmk heska
gen smoke1=.
replace smoke1=2 if hesmk==2
replace smoke1=1 if hesmk==1 & heska==2
replace smoke1=0 if heska==1
label define smoke1 0 "current smoker" 1 "past smoker" 2 "never smoked"
label values smoke1 smoke1
tab smoke1, mi
tab heska smoke1, mi
tab hesmk smoke1, mi
/*EXERCISE*/
tab heactb
label list heactb
recode heactb (1=2) (2 3=1) (4=0) (-9/-1=.), gen(exercise_mod)
label define exercise_mod 2 "2 or more times per week" 1 "1 to 4 times per month" 0 "hardly ever or never" 
label values exercise_mod exercise_mod
tab heactb exercise_mod, mi
tab exercise_mod, mi
/*ACCESS ITEMS*/
/*GP and dentist - higher=better*/
label list scaccc scaccd scacce scaccg
recode scaccd (1=2) (2=1) (3/4=0) (-9/-1 =.), gen(gp_access)
recode scaccc (1=2) (2=1) (3/4=0) (-9/-1 =.), gen(dentist_access)
recode scacce (1=2) (2=1) (3/4=0) (-9/-1 =.), gen(hospital_access)
recode scaccg (1=2) (2=1) (3/4=0) (-9/-1 =.), gen(optician_access)
label define access 0  "difficult or unable" 1 "quite easy" 2 "very easy"
label values gp_access dentist_access hospital_access optician_access access
tab scaccd gp_access, mi
tab scaccc dentist_access, mi
tab scacce hospital_access, mi
tab scaccg optician_access, mi
/*KEEP ONLY THE VARS I NEED*/
keep idauniq dateofinterview SIFdateofinterview ethnicity wave nssec8 nssec5 nssec3 tenure2 edqual edu_yearsof difjob2 sclddr2 ///
num_durables num_housing_probs housing_prob car_ownership tenure3 private_health ///
scptr scchd scfam scfrd livsppt chicontact famcontact friecontact memorg memreg ///
scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2 ///
scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2 ///
scptr scchd scfam scfrd ///
scchdg2 scchdh2 scchdi2 scfamg2 scfamh2 scfami2 scfrdg2 scfrdh2 scfrdi2 ///
scorg012 scorg022 scorg042 scorg052 scorg062 scorg072 scorg082 ///
M_walking M_sitting M_getting_up M_stairs_several M_stairs_one M_stoop M_reaching ///
M_pulling M_lifting M_picking ADL_dressing ADL_walking ADL_bathing ADL_eating ///
ADL_outofbed ADL_toilet ADL_usingmap ADL_hotmeal ADL_shopping ADL_telephone ADL_medication ///
ADL_housework ADL_money general_health dep_psceda dep_pscedb dep_pscedc dep_pscedd ///
dep_pscede dep_pscedf dep_pscedg dep_pscedh highBP angina heartattack congestHF ///
abnormalheart diabetes stroke chroniclung asthma arthritis osteoporosis cancer ///
parkinsons anyemotional alzheimers dementia eyesight hearing todaysdate month ///
year dayofweek word_recall_delay word_recall_immed ///
unmet_flag unmet_formal ///
scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca2 scdcc2 ///
smoke1 exercise_mod ///
gp_access dentist_access hospital_access optician_access transport_deprived ///
srgeneralh
/*save*/
save "$work\wave_1_core_data_v3_prepped.dta", replace

/**********************************************************************************/
/*WAVE 2*/
clear
use "$raw\wave_2_core_data_v4.dta"
/*interview date*/
tab iintdtm
tab iintdty
label list iintdtm
label list iintdty
tostring iintdtm, force replace
tostring iintdty, force replace
gen dateofinterview= "01/" + iintdtm + "/" + iintdty 
gen SIFdateofinterview=date(dateofinterview, "DMY")
/*gen wave num*/
gen wave=2
/*ethnicity*/
label list fqethnr
recode fqethnr (-9/-1 = .), gen(ethnicity)
tab ethnicity fqethnr, mi
label define ethnicitylab 1 White 2 "Non-white"
label values ethnicity ethnicitylab
/*NS-SEC*/
/*8 cat*/
tab w2nssec8, mi 
describe w2nssec8
label list w2nssec8 
recode w2nssec8 (-6/-1 =.), gen(nssec8)
label values nssec8 w2nssec8
tab w2nssec8 nssec8, mi
/*5 cat*/
tab w2nssec5, mi 
describe w2nssec5
label list w2nssec5 
recode w2nssec5 (-6/-1 =.), gen(nssec5)
label values nssec5 w2nssec5
tab w2nssec5 nssec5, mi
/*3 cat*/
tab w2nssec3, mi 
describe w2nssec3
label list w2nssec3 
recode w2nssec3 (-6/-1 =.), gen(nssec3)
label values nssec3 w2nssec3
tab w2nssec3 nssec3, mi
/*************************/
/*HOUSING TENURE - coding from wave 4 and 6 reports*/
tab hotenu
label list hotenu
recode hotenu (2 3 =2) (4 5 =3) (6 =4) (-9 -8 -1 =.), gen(tenure2)
label define atenureb2 1 "Owner occupied" 2 "Buying with mortgage" 3 "Renting or rent free" 4 "Other" 
label values tenure2 atenureb2
tab hotenu tenure2, mi
/************************/
/*EDUCATION*/
/*no highest qual var*/
/***************************/
/*PATERNAL OCCUPATIONAL CLASS AT 14*/
/*recode fathers occu as in panos wealth paper*/
tab DiFJob /*fathers occup*/
label list DiFJob
recode DiFJob (2 3 4 = 1) (5 6 = 2) (7 8 9 12 14 15 = 3) (10 11 13 1 = 4) (-9 -8 -1 =.), gen(difjob2)
label define difjob2lab 1 "Managerial and professional occupations/run own business" ///
2 "Intermediate occupations" 3 "Routine occupations/casual jobs/unemployed/disabled" ///
4 "Other (incl Armed Forces and Retired)"
label values difjob2 difjob2lab
tab DiFJob difjob2, mis
/*****************************/
/*SUBJECTIVE SOCIAL STATUS - 10 RUNG*/
tab sclddr /*sss*/
label list sclddr
recode sclddr (5 10 =10) (15 20=20) (25 30 =30) (35 40 =40) (45 50 =50) (55 60 =60) (65 70 =70) (75 80 =80) ///
(85 90 =90) (95 100 =100) (-9/-1 =.), gen(sclddr2)
tab sclddr sclddr2, mi
/*******************************/
/*******************************/
/*ITEMS FOR MATERIAL DEPRIVATION FACTOR*/
/*HOUSING PROBLEMS*/
/*lack of central heating*/
tab hocenh 
label list hocenh 
gen central_heat=0
replace central_heat=1 if hocenh==2
replace central_heat=. if hocenh<0
tab hocenh central_heat, mi
/*type of heating*/
/*foreach var of varlist hoohea1-hoohea3 hoohem1-hoohem3{
tab `var'
} */
foreach var of varlist hoprm1-hoprm10{
tab `var'
describe `var'
label list `var'
}
gen space=0
gen dark=0
gen damp=0
gen roof=0
gen condensation=0
gen electrics=0
gen rot=0
gen pests=0
gen cold=0
foreach var of varlist hoprm1-hoprm10{
replace space=1 if `var'==1
replace dark=1 if `var'==4
replace damp=1 if `var'==6
replace roof=1 if `var'==7
replace condensation=1 if `var'==8
replace electrics=1 if `var'==9
replace rot=1 if `var'==10
replace pests=1 if `var'==11
replace cold=1 if `var'==12
}
egen num_housing_probs=rowtotal(central_heat-cold)
replace num_housing_probs=. if hoprm1<0
tab num_housing_probs, mis
/*also these other 'merged vars' hoprm01-hoprm10 - include some extra cats ///
but not needed*/
/*gen binary housing*/
gen housing_prob=.
replace housing_prob=0 if num_housing_probs>=1 & num_housing_probs!=.
replace housing_prob=1 if num_housing_probs==0
label define housing_prob 0 problems 1 "no problems"
label values housing_prob housing_prob
tab num_housing_probs housing_prob, mi
/************************************/
/*DURABLES*/
foreach var of varlist hohav1-hohav11{
tab `var'
label list `var'
}
gen tv=0
gen video_rec=0
gen cd_player=0
gen freezer=0
gen wash_machin=0
gen tumble_dry=0
gen dishwash=0
gen microwave=0
gen computer=0
gen sat_tv=0
gen phone=0
gen dvd=0
foreach var of varlist hohav1-hohav11{
replace tv=1 if `var'==1
replace video_rec=1 if `var'==2
replace cd_player=1 if `var'==3
replace freezer=1 if `var'==4
replace wash_machin=1 if `var'==5
replace tumble_dry=1 if `var'==6
replace dishwash=1 if `var'==7
replace microwave=1 if `var'==8
replace computer=1 if `var'==9
replace sat_tv=1 if `var'==10
replace phone=1 if `var'==11
replace dvd=1 if `var'==12
}
egen count_durables=rowtotal(tv video_rec cd_player freezer wash_machin tumble_dry ///
 dishwash microwave computer sat_tv phone dvd)
/*condition the score*/
recode count_durables (0 1=0) (2/4=1) (5/8=2) (9/12=3), gen(num_durables)
replace num_durables=. if hohav1<0 
replace num_durables=3 if hohav1==95
replace num_durables=0 if hohav1==96
label define num_durables 0 "<2" 1 "2-4" 2 "5-8" 3 ">8"
label values num_durables num_durables
tab num_durables, mi
/***********************************/
/*TRANSPORT*/
/*car, van or motorbike ownership*/
tab hoveh
label list hoveh
foreach var of varlist hocc01-hocc20{
label list `var'
}
gen car_ownership=.
replace car_ownership=0 if hoveh==0
replace car_ownership=1 if hoveh>=1
foreach var of varlist hocc01-hocc20{
replace car_ownership=1 if `var'==1 | `var'==3 | `var'==4 
}
label define car_ownership 0 "no car or van" 1 "at least 1 car, van or motorbike"
label values car_ownership car_ownership 
tab hoveh car_ownership, mi
/**************/
/*tenure binary*/
recode hotenu (1 2 3=1) (4 5 6=0) (-9 -8 -1 =.), gen(tenure3)
label define tenure3 1 "owner" 0 "other"
label values tenure3 tenure3
tab hotenu tenure3, mi
/***************************/
/*private insurance*/
tab wpphi
label list wpphi
gen private_health=.
replace private_health=0 if wpphi==3
replace private_health=1 if wpphi==1 | wpphi==2
label define private_health 0 "no private insurance" 1 "private insurance"
label values private_health private_health
tab wpphi private_health, mi
/************************/
/***********************************/
/*TRANSPORT*/
foreach var of varlist sptrm01-sptrm07{
tab `var'
label list `var'
}
tab SPCar, mi
label list SPCar

gen dont_need_to=0
foreach var of varlist sptrm01-sptrm07{
replace dont_need_to=1 if `var'==5
}
replace dont_need_to=. if SPTraB1<0
tab dont_need_to, mi

tab SPTraA
label list SPTraA
gen transport_deprived=0
replace transport_deprived=1 if SPCar==2 & (SPTraA==4 | SPTraA==5 & dont_need_to!=1)
replace transport_deprived=. if SPCar<0 & SPTraA<0 
tab transport_deprived, mi
tab SPCar transport_deprived, mi
tab SPTraA transport_deprived, mi
/*************************************/
/*SOCIAL INTEGRATION - see Banks 2010, and Ding 2017*/
/*higher is optimal*/
/*living with spouse or partner*/ 
/*NB wording of questions is 'do you have a husband or wife with whom you live?*/
/*need to check posibly with Ding that this is the correct var to use - it doesnt use the broader term spouse but i cant see a question that does*/
recode scptr (-9 -1 =.) (2 = 0), gen(livsppt)
tab scptr livsppt, mi
label var livsppt "living with spouse or partner"
/*do you have children family friends*/
foreach var of varlist scchd scfam scfrd{
tab `var'
label list `var'
}
/*contact with children, family, friends (including: face to face, phone, email or write)*/
/*NB for each group taking the highest from face to face, phone or email - this is not the only way to do this - you could for example take the average across the 3 types of contact ///
/// just be aware that this is essentially an arbritrary decision that could be questioned*/
foreach var of varlist scchdg scchdh scchdi scfamg scfamh scfami scfrdg scfrdh scfrdi {
tab `var'
label list `var'
recode `var' (-9 -1 = .) (1 2 = 3) (3 = 2) (4 = 1) (5 6 = 0), gen(`var'2)
}
replace scchdg2=0 if scchd==2
replace scchdh2=0 if scchd==2
replace scchdi2=0 if scchd==2
egen chicontact = rowmax(scchdg2 scchdh2 scchdi2)
label var chicontact "contact with children"
replace scfamg2=0 if scfam==2
replace scfamh2=0 if scfam==2
replace scfami2=0 if scfam==2
egen famcontact = rowmax(scfamg2 scfamh2 scfami2)
label var famcontact "contact with family"
replace scfrdg2=0 if scfrd==2
replace scfrdh2=0 if scfrd==2
replace scfrdi2=0 if scfrd==2
egen friecontact = rowmax(scfrdg2 scfrdh2 scfrdi2)
label var friecontact "contact with friends"
/*low membership of organisations*/
/*NB im including 'any other group' Ding does not include but i cant see a good reason for not including*/
foreach var of varlist scorg01 scorg02 scorg04 scorg05 scorg06 scorg07 scorg08{
tab `var'
label list `var'
recode `var' (-9 -1 = . ), gen (`var'2)
}
egen totalorgs = rowtotal (scorg012-scorg082)
replace totalorgs=. if (scorg012==. & scorg022==. & scorg042==. & scorg052==. & scorg062==. & scorg072==. & scorg082==.)
tab totalorgs, mi
recode totalorgs (1 2 = 1) (3 4 = 2) (5 6 7 = 3), gen(memorg)
label var memorg "membership of organisations"
tab memorg, mi
/*member of religious group*/
tab scorg03
label list scorg03
recode scorg03 (-9 -1 = .), gen (memreg)
label var memreg "membership of religious group"
tab memreg, mi
/*total social integration score - generate this after appending all files and imputing data for each component*/
/****************************************/
/*SOCIAL SUPPORT - see Banks 2010, and Dings 2017*/
/*do you have partner, children, family, friends?*/
foreach var of varlist scptr scchd scfam scfrd{
tab `var'
label list `var'
}
/*positive relationships with children, family and friends*/
foreach var of varlist scptra scptrb scptrc scchda scchdb scchdc scfama scfamb scfamc scfrda scfrdb scfrdc {
tab `var'
label list `var'
recode `var' (-9 -1 = .) (1 = 3) (3 = 1) (4 = 0), gen(`var'2)
tab `var' `var'2, mi
}
/*negative relationships with children, family and friends*/
foreach var of varlist scptrd scptre scptrf scchdd scchde scchdf scfamd scfame scfamf scfrdd scfrde scfrdf {
tab `var'
label list `var'
recode `var' (-9 -1 = .) (1 = 0) (2 = 1) (3 = 2) (4 = 3), gen(`var'2)
tab `var' `var'2, mi
}
replace scptra2=0 if scptr==2
replace scptrb2=0 if scptr==2 
replace scptrc2=0 if scptr==2 
replace scptrd2=0 if scptr==2 
replace scptre2=0 if scptr==2 
replace scptrf2=0 if scptr==2

replace scchda2=0 if scchd==2
replace scchdb2=0 if scchd==2
replace scchdc2=0 if scchd==2
replace scchdd2=0 if scchd==2
replace scchde2=0 if scchd==2
replace scchdf2=0 if scchd==2

replace scfama2=0 if scfam==2
replace scfamb2=0 if scfam==2
replace scfamc2=0 if scfam==2
replace scfamd2=0 if scfam==2
replace scfame2=0 if scfam==2
replace scfamf2=0 if scfam==2

replace scfrda2=0 if scfrd==2
replace scfrdb2=0 if scfrd==2
replace scfrdc2=0 if scfrd==2
replace scfrdd2=0 if scfrd==2
replace scfrde2=0 if scfrd==2
replace scfrdf2=0 if scfrd==2
/*total social support score - generate this after appending all files and imputing data for each component*/
/*
/******************************************/
/*QUALITY OF RELATIONSIPS*/
/*do you have partner, children, family, friends?*/
foreach var of varlist scptr scchd scfam scfrd{
tab `var'
label list `var'
}
/*contact and quality of relationship with spouse/partner*/
foreach var of varlist scptra-scptrg{
tab `var'
label list `var'
}
foreach var of varlist scptra scptrb scptrc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scptrd scptre scptrf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_partner=rowtotal(scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2)
replace quality_partner=. if scptra2==. & scptrb2==. & scptrc2==. & scptrd2==. & ///
 scptre2==. & scptrf2==. 
tab quality_partner, mi
tab quality_partner scptr, mi
/*contact and quality of relationship with children*/
foreach var of varlist scchda-scchdm{
tab `var'
label list `var'
}
foreach var of varlist scchda scchdb scchdc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scchdd scchde scchdf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_children=rowtotal(scchda2 scchdb2 scchdc2 scchdd2 scchde2 scchdf2)
replace quality_children=. if scchda2==. & scchdb2==. & scchdc2==. & scchdd2==. & ///
 scchde2==. & scchdf2==. 
tab quality_children, mi
tab quality_children scchd, mi 
/*contact and quality of relationship with family*/
foreach var of varlist scfama-scfamm{
tab `var'
label list `var'
}
foreach var of varlist scfama scfamb scfamc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scfamd scfame scfamf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_family=rowtotal(scfama2 scfamb2 scfamc2 scfamd2 scfame2 scfamf2)
replace quality_family=. if scfama2==. & scfamb2==. & scfamc2==. & scfamd2==. & ///
 scfame2==. & scfamf2==. 
tab quality_family, mi
tab quality_family scfam, mi
/*contact and quality of relationship with friends*/
foreach var of varlist scfrda-scfrdm{
tab `var'
label list `var'
}
foreach var of varlist scfrda scfrdb scfrdc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scfrdd scfrde scfrdf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_friends=rowtotal(scfrda2 scfrdb2 scfrdc2 scfrdd2 scfrde2 scfrdf2)
replace quality_friends=. if scfrda2==. & scfrdb2==. & scfrdc2==. & scfrdd2==. & ///
 scfrde2==. & scfrdf2==. 
tab quality_friends, mi
tab quality_friends scfrd, mi
/*SOCIAL ISOLATION*/
tab scptr
label list scptr
foreach var of varlist scchdi scfami scfrdi{
tab `var'
label list `var'
}
gen social_isolation=0
replace social_isolation=1 if scptr==2 & (scchdi!=1 | scfami!=1 | scfrdi!=1)
replace social_isolation=. if scptr<0 & scchdi<0 & scfami<0 & scfrdi<0
tab social_isolation, mi */
/************************************************/
/*HEALTH LITERACY*/
foreach var of varlist CfLitB-CfLitE{
tab `var'
label list `var'
recode `var' (-9 -8 -1 = .) (2 = 0), gen(`var'2)
tab `var' `var'2, mis
}
egen healthlitscore=rowtotal(CfLitB2 CfLitC2 CfLitD2 CfLitE2)
tab healthlitscore, mi
replace healthlitscore=. if CfLitB2==. & CfLitC2==. & CfLitD2==. & CfLitE2==.
gen healthlit=.
replace healthlit=1 if healthlitscore==4
replace healthlit=2 if healthlitscore>=0 & healthlitscore<=3
label define healthlit 1 adequate 2 limited
label values healthlit healthlit
tab healthlitscore healthlit, mi
/*************************************************/
/*FRAILTY INDEX*/
/*mobility difficulties*/
foreach var of varlist heada01-heada10{
tab `var', mi
label list `var'
}
gen M_walking=0
gen M_sitting=0
gen M_getting_up=0
gen M_stairs_several=0
gen M_stairs_one=0
gen M_stoop=0
gen M_reaching=0
gen M_pulling=0
gen M_lifting=0
gen M_picking=0
gen missing_flag=0
replace missing_flag=1 if heada01<0 
foreach var of varlist heada01-heada10{
replace M_walking=1 if `var'==1
replace M_sitting=1 if `var'==2
replace M_getting_up=1 if `var'==3
replace M_stairs_several=1 if `var'==4
replace M_stairs_one=1 if `var'==5
replace M_stoop=1 if `var'==6
replace M_reaching=1 if `var'==7
replace M_pulling=1 if `var'==8
replace M_lifting=1 if `var'==9
replace M_picking=1 if `var'==10
}
tab missing_flag, mi
foreach var of varlist M_walking-M_picking{
replace `var'=. if missing_flag==1
tab `var', mi
}
drop missing_flag
/*disability ADL/iADL*/
foreach var of varlist headb01-headb13{
tab `var', mi
label list `var'
}
gen ADL_dressing=0
gen ADL_walking=0
gen ADL_bathing=0
gen ADL_eating=0
gen ADL_outofbed=0
gen ADL_toilet=0
gen ADL_usingmap=0
gen ADL_hotmeal=0
gen ADL_shopping=0
gen ADL_telephone=0
gen ADL_medication=0
gen ADL_housework=0
gen ADL_money=0
gen missing_flag=0
replace missing_flag=1 if heada01<0 
foreach var of varlist headb01-headb13{
replace ADL_dressing=1 if `var'==1 
replace ADL_walking=1 if `var'==2 
replace ADL_bathing=1 if `var'==3 
replace ADL_eating=1 if `var'==4 
replace ADL_outofbed=1 if `var'==5 
replace ADL_toilet=1 if `var'==6 
replace ADL_usingmap=1 if `var'==7 
replace ADL_hotmeal=1 if `var'==8 
replace ADL_shopping=1 if `var'==9 
replace ADL_telephone=1 if `var'==10 
replace ADL_medication=1 if `var'==11
replace ADL_housework=1 if `var'==12 
replace ADL_money=1 if `var'==13
} 
tab missing_flag, mi
foreach var of varlist ADL_dressing-ADL_money{
replace `var'=. if missing_flag==1
tab `var', mi
}
drop missing_flag
/*general health*/
/*NB - a lot of missing for this one - wave 0 questions much more complete*/
/*suggest use info from wave 0*/
tab Hehelf, mi 
label list Hehelf
gen general_health=0
replace general_health=1 if Hehelf==4 | Hehelf==5
replace general_health=. if Hehelf<0
tab Hehelf general_health, mi
tab general_health, mi
/*2nd general health var*/
recode Hehelf (-9/-1=.), gen(srgeneralh)
label values srgeneralh Hehelf
tab Hehelf srgeneralh, mi
/*depressive symptoms*/
foreach var of varlist PScedA-PScedH{
label list `var'
}
rename PScedA psceda
rename PScedB pscedb
rename PScedC pscedc
rename PScedD pscedd
rename PScedE pscede
rename PScedF pscedf
rename PScedG pscedg
rename PScedH pscedh

foreach var of varlist psceda-pscedc pscede pscedg pscedh{
tab `var'
recode `var' (2=0) (-9/-1=.), gen (dep_`var')
tab `var' dep_`var', mi
}

foreach var of varlist pscedf pscedd{
tab `var'
recode `var' (2=1) (1=0) (-9/-1=.), gen(dep_`var')
tab `var' dep_`var', mi
}

/*high BP - stroke*/
/*merged first mentioned at wave 2*/
foreach var of varlist hedim01-hedim08{
tab `var', mi
label list `var'
}
gen highBP=0
gen angina=0
gen heartattack=0
gen congestHF=0
gen abnormalheart=0
gen diabetes=0
gen stroke=0
gen miss_flag=0
replace miss_flag=1 if hedim01<0
foreach var of varlist hedim01-hedim07{
replace highBP=1 if `var'==1
replace angina=1 if `var'==2
replace heartattack=1 if `var'==3
replace congestHF=1 if `var'==4
replace abnormalheart=1 if `var'==6
replace diabetes=1 if `var'==7
replace stroke=1 if `var'==8
}
foreach var of varlist highBP-stroke{
replace `var'=. if miss_flag==1
tab `var', mi
}
drop miss_flag
/*gen flag if had at wave 1 as well*/
foreach var of varlist hediaw1-HeDiaW8{
tab `var', mi
label list `var'
}
gen AhighBP=0
gen Aangina=0
gen Aheartattack=0
gen AcongestHF=0
gen Aabnormalheart=0
gen Adiabetes=0
gen Astroke=0
gen Amiss_flag=0
foreach var of varlist hediaw1-HeDiaW8{
replace AhighBP=1 if `var'==1
replace Aangina=1 if `var'==2
replace Aheartattack=1 if `var'==3
replace AcongestHF=1 if `var'==4
replace Aabnormalheart=1 if `var'==6
replace Adiabetes=1 if `var'==7
replace Astroke=1 if `var'==8
}
foreach var of varlist highBP-stroke{
replace `var'=1 if A`var'==1
tab `var', mi
}
/*chronic lung - dementia*/
/*newly reported*/
foreach var of varlist hedib01-hedib04{
tab `var', mi
label list `var'
}
gen chroniclung=0
gen asthma=0
gen arthritis=0
gen osteoporosis=0
gen cancer=0
gen parkinsons=0
gen anyemotional=0
gen alzheimers=0
gen dementia=0
gen miss_flag=0
replace miss_flag=1 if hedib01<0
foreach var of varlist hedib01-hedib04{
replace chroniclung=1 if `var'==1
replace asthma=1 if `var'==2
replace arthritis=1 if `var'==3
replace osteoporosis=1 if `var'==4
replace cancer=1 if `var'==5
replace parkinsons=1 if `var'==6
replace anyemotional=1 if `var'==7
replace alzheimers=1 if `var'==8
replace dementia=1 if `var'==9
}
foreach var  of varlist chroniclung-dementia{
replace `var'=. if miss_flag==1
tab `var', mi
}
drop miss_flag
/*which chronic conditions from wave 1*/
foreach var of varlist hedibw1-HeDibW9{
tab `var', mi
label list `var'
}
gen Achroniclung=0
gen Aasthma=0
gen Aarthritis=0
gen Aosteoporosis=0
gen Acancer=0
gen Aparkinsons=0
gen Aanyemotional=0
gen Aalzheimers=0
gen Adementia=0
foreach var of varlist hedibw1-HeDibW9{
replace Achroniclung=1 if `var'==1
replace Aasthma=1 if `var'==2
replace Aarthritis=1 if `var'==3
replace Aosteoporosis=1 if `var'==4
replace Acancer=1 if `var'==5
replace Aparkinsons=1 if `var'==6
replace Aanyemotional=1 if `var'==7
replace Aalzheimers=1 if `var'==8
replace Adementia=1 if `var'==9
}
foreach var of varlist chroniclung-dementia{
replace `var'=1 if A`var'==1
tab `var', mi
}

/*eyesight*/
tab Heeye, mi
label list Heeye
recode Heeye (-9/-1=.) (1/3=0) (4/6=1), gen(eyesight)
tab Heeye eyesight, mi
/*hearing*/
tab Hehear, mi
label list Hehear
recode Hehear (-9/-1=.) (1/3=0) (4/5=1), gen(hearing)
tab Hehear hearing, mi
/*cognitive function*/
/*date test*/
tab CfDatD, mi
label list CfDatD
recode CfDatD (-9/-1=.) (2=1) (1=0), gen(todaysdate)
tab CfDatD todaysdate, mi
/**/
tab CfDatM, mi
label list CfDatM
recode CfDatM (-9/-1=.) (2=1) (1=0), gen(month)
tab CfDatM month, mi
/**/
tab CfDatY, mi
label list CfDatY
recode CfDatY (-9/-1=.) (2=1) (1=0), gen(year)
tab CfDatY year, mi
/**/
tab CfDay, mi
label list CfDay
recode CfDay (-9/-1=.) (2=1) (1=0), gen(dayofweek)
tab CfDay dayofweek, mi
/*word recall*/
/*delay*/
tab CfLisD, mi
label list CfLisD
recode CfLisD(-9/-1=.), gen(word_recall_delay)
tab CfLisD word_recall_delay, mi
/*immediately*/
tab CfLisEn, mi
label list CfLisEn
recode CfLisEn (-9/-1=.), gen(word_recall_immed)
tab CfLisEn word_recall_immed, mi
/*********************/
/*unmet need score*/
/*************/
/*move round house*/
gen move_need=1 if ADL_walking==1
replace move_need=0 if ADL_walking==0
/*wash or dress*/
gen washdress_need=1 if ADL_bathing==1 | ADL_dressing==1
replace washdress_need=0 if ADL_bathing==0 | ADL_dressing==0 
/*prepare meal or eat*/
gen mealeat_need=1 if ADL_hotmeal==1 | ADL_eating==1
replace mealeat_need=0 if ADL_hotmeal==0 | ADL_eating==0
/*shopping or housework*/
gen shophous_need=1 if ADL_housework==1 | ADL_shopping==1
replace shophous_need=0 if ADL_housework==0 | ADL_shopping==0 
/*phone or money*/
gen phonemon_need=1 if ADL_telephone==1 | ADL_money==1
replace phonemon_need=0 if ADL_telephone==0 | ADL_money==0
/*medications*/
gen medicat_need=1 if ADL_medication==1
replace medicat_need=0 if ADL_medication==0

egen adliadl_items=rownonmiss(move_need washdress_need mealeat_need shophous_need phonemon_need medicat_need)
tab adliadl_items, mi /* NB cases either have all 6 answers or missing on all - if missing on less than 6, may need to set some to missing*/
egen total_adliadl_items=rowtotal(move_need washdress_need mealeat_need shophous_need phonemon_need medicat_need)
replace total_adliadl_items=. if adliadl_items<6 
/****************************************/
/*recieved care?*/
gen care_flag=0
gen formal_care=0
foreach var of varlist HeHpb01-HeHpb09{
tab `var', mi
label list `var'
replace care_flag=1 if `var'>0 & `var'!=.
replace care_flag=. if HeHpb01<0 & total_adliadl_items==.
replace formal_care=1 if `var'==13 | `var'==14
replace formal_care=. if HeHpb01<0 & total_adliadl_items==.
/*only set to missing where no record of care need & no record of care recieved///
those without care need were not asked about care recieved...these are not missing1**/
}
/*unmet care need?*/
gen unmet_flag=0
gen unmet_formal=0
foreach var of varlist move_need washdress_need mealeat_need shophous_need phonemon_need medicat_need {
replace unmet_flag=1 if `var'==1 & care_flag!=1
replace unmet_formal=1 if `var'==1 & formal_care!=1
}
/*set to missing if who cares vars were missing*/
replace unmet_flag=. if care_flag==.
replace unmet_formal=. if formal_care==. 
/*set to missing if need care vars were mising*/
replace unmet_flag=. if adliadl_items==0
replace unmet_formal=. if adliadl_items==0
/***************************************************/
/*CASP plus control, create vars for latent psychosocial path*/
/*positively worded*/
foreach var of varlist scqolc scqole scqolg{
recode `var' (1=3) (2=2) (3=1) (4=0), gen(`var'2)
}
/*negatively worded*/
foreach var of varlist scqola scqolb scqold scqolf {
recode `var' (1=0) (2=1) (3=2) (4=3), gen(`var'2)
}
/*2 extra questions, not casp*/
/*positive*/ recode scdca (1=5) (2=4) (3=3) (4=2) (5=1) (6=0), gen(scdca2)
/*negative*/ recode scdcc (1=0) (2=1) (3=2) (4=3) (5=4) (6=5), gen(scdcc2) 

order scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2, after(scqolg)
browse scqola scqolb scqolc scqold scqole scqolf scqolg scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca scdca2 scdcc scdcc2
foreach var of varlist scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca2 scdcc2 {
replace `var'=. if `var'<0
}
/*ITEMS FOR BEHAVIOURAL FACTOR*/
/*SMOKING*/
/*ever smoked - large % n/a here in this wave, i cant work out how to improve BUT very few of eol sample enter in wave 2 so not very worried*/
tab HeSmk
label list HeSmk
/*currently*/ 
tab HESka
label list HESka
tab HeSmk HESka
gen smoke2=.
replace smoke2=2 if HeSmk==2
replace smoke2=1 if HeSmk==1 & HESka==2
replace smoke2=0 if HESka==1
label define smoke2 0 "current smoker" 1 "past smoker" 2 "never smoked"
label values smoke2 smoke2
tab HESka smoke2, mi
tab HeSmk smoke2, mi
tab smoke2, mi
/*EXERCISE*/
tab HeActb
label list HeActb
recode HeActb (1=2) (2 3=1) (4=0) (-9/-1=.), gen(exercise_mod)
label define exercise_mod 2 "2 or more times per week" 1 "1 to 4 times per month" 0 "hardly ever or never" 
label values exercise_mod exercise_mod
tab HeActb exercise_mod, mi
/************************************************/
/*ACCESS ITEMS*/
/*GP and dentist - higher=better*/
label list scaccc scaccd scacce scaccg
recode scaccd (1=2) (2=1) (3/4=0) (-9/-1 5 =.), gen(gp_access)
recode scaccc (1=2) (2=1) (3/4=0) (-9/-1 5 =.), gen(dentist_access)
recode scacce (1=2) (2=1) (3/4=0) (-9/-1 5 =.), gen(hospital_access)
recode scaccg (1=2) (2=1) (3/4=0) (-9/-1 5 =.), gen(optician_access)
label define access 0  "difficult or unable" 1 "quite easy" 2 "very easy"
label values gp_access dentist_access hospital_access optician_access access
tab scaccd gp_access, mi
tab scaccc dentist_access, mi
tab scacce hospital_access, mi
tab scaccg optician_access, mi
/*KEEP ONLY THE VARS I NEED*/
keep idauniq dateofinterview SIFdateofinterview ethnicity wave nssec8 nssec5 nssec3 tenure2 FqEnd difjob2 sclddr2  ///
num_durables num_housing_probs housing_prob car_ownership tenure3 private_health ///
scptr scchd scfam scfrd livsppt chicontact famcontact friecontact memorg memreg ///
scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2 ///
scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2 ///
scptr scchd scfam scfrd ///
scchdg2 scchdh2 scchdi2 scfamg2 scfamh2 scfami2 scfrdg2 scfrdh2 scfrdi2 ///
scorg012 scorg022 scorg042 scorg052 scorg062 scorg072 scorg082 ///
healthlitscore healthlit M_walking M_sitting M_getting_up M_stairs_several M_stairs_one M_stoop M_reaching ///
M_pulling M_lifting M_picking ADL_dressing ADL_walking ADL_bathing ADL_eating ///
ADL_outofbed ADL_toilet ADL_usingmap ADL_hotmeal ADL_shopping ADL_telephone ADL_medication ///
ADL_housework ADL_money general_health dep_psceda dep_pscedb dep_pscedc dep_pscedd ///
dep_pscede dep_pscedf dep_pscedg dep_pscedh highBP angina heartattack congestHF ///
abnormalheart diabetes stroke chroniclung asthma arthritis osteoporosis cancer ///
parkinsons anyemotional alzheimers dementia eyesight hearing todaysdate month ///
year dayofweek word_recall_delay word_recall_immed ///
unmet_flag unmet_formal ///
scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca2 scdcc2 ///
smoke2 exercise_mod ///
gp_access dentist_access hospital_access optician_access transport_deprived ///
srgeneralh
save "$work\wave_2_core_data_v4_prepped.dta", replace

/**********************************************************************************/
/*WAVE 3*/
clear
use "$raw\wave_3_elsa_data_v4.dta"
/*interview date*/
tab iintdatm
tab iintdaty 
label list iintdatm
label list iintdaty
tostring iintdatm, force replace
tostring iintdaty, force replace
gen dateofinterview= "01/" + iintdatm + "/" + iintdaty 
gen SIFdateofinterview=date(dateofinterview, "DMY")
/*gen wave num*/
gen wave=3
/*ethnicity*/
label list fqethnr
recode fqethnr (-9/-1 = .), gen(ethnicity)
tab ethnicity fqethnr, mi
label define ethnicitylab 1 White 2 "Non-white"
label values ethnicity ethnicitylab
/*NS-SEC*/
/*8 cat*/
tab w3nssec8, mi 
describe w3nssec8
label list w3nssec8 
recode w3nssec8 (-6/-1 =.), gen(nssec8)
label values nssec8 w3nssec8
tab w3nssec8 nssec8, mi
/*5 cat*/
tab w3nssec5, mi 
describe w3nssec5
label list w3nssec5 
recode w3nssec5 (-6/-1  =.), gen(nssec5)
label values nssec5 w3nssec5
tab w3nssec5 nssec5, mi
/*3 cat*/
tab w3nssec3, mi 
describe w3nssec3
label list w3nssec3 
recode w3nssec3 (-6/-1 =.), gen(nssec3)
label values nssec3 w3nssec3
tab w3nssec3 nssec3, mi
/*************************/
/*HOUSING TENURE - coding from wave 4 and 6 reports*/
tab hotenu
label list hotenu
recode hotenu (2 3 =2) (4 5 =3) (6 =4) (-9 -8 -1 =.), gen(tenure2)
label define atenureb2 1 "Owner occupied" 2 "Buying with mortgage" 3 "Renting or rent free" 4 "Other" 
label values tenure2 atenureb2
tab hotenu tenure2, mi
/************************/
/*EDUCATION*/
tab w3edqual/*high qual*/
label list w3edqual
/*recode highest qual as in panos wealth paper*/ /*
recode w3edqual (1/3=1) (4/6=2) (7=3) (-9 -8 -1 =.), gen(edqual2)
label define edqual2lab 1 "A-level or higher" 2 "GCSE/O-level/other qualification" 3 "No qualification"
label values edqual2 edqual2lab
tab w3edqual edqual2, mi*/
/***************************/
/*PATERNAL OCCUPATIONAL CLASS AT 14*/
/*recode fathers occu as in panos wealth paper*/
tab difjob /*fathers occup*/
label list difjob
recode difjob (2 3 4 = 1) (5 6 = 2) (7 8 9 12 14 15 = 3) (10 11 13 1 = 4) (-9 -8 -1 =.), gen(difjob2)
label define difjob2lab 1 "Managerial and professional occupations/run own business" ///
2 "Intermediate occupations" 3 "Routine occupations/casual jobs/unemployed/disabled" ///
4 "Other (incl Armed Forces and Retired)"
label values difjob2 difjob2lab
tab difjob difjob2, mis
/*****************************/
/*SUBJECTIVE SOCIAL STATUS - 10 RUNG*/
tab sclddr /*sss*/
label list sclddr
recode sclddr (5 10 =10) (15 20=20) (25 30 =30) (35 40 =40) (45 50 =50) (55 60 =60) (65 70 =70) (75 80 =80) ///
(85 90 =90) (95 100 =100) (-9/-1 =.), gen(sclddr2)
tab sclddr sclddr2, mi
/*******************************/
/*******************************/
/*ITEMS FOR MATERIAL DEPRIVATION FACTOR*/
/*HOUSING problems*/
tab hocenh 
label list hocenh 
gen central_heat=.
replace central_heat=1 if hocenh==2
tab hocenh central_heat, mi
foreach var of varlist hopromsp-hopromco{
tab `var'
describe `var'
label list `var'
}
recode hoprosp (-9/-1=.), gen (space)
tab hoprosp space, mi
recode hoprodk (-9/-1=.), gen (dark)
tab hoprodk dark, mi
recode hoprord (-9/-1=.), gen (damp)
tab hoprord damp, mi
recode hoprowa (-9/-1=.), gen (roof)
tab hoprowa roof, mi
recode hoprocp (-9/-1=.), gen (condensation)
tab hoprocp condensation, mi
recode hoproep (-9/-1=.), gen (electrics)
tab hoproep electrics, mi
recode hoproro (-9/-1=.), gen (rot)
tab hoproro rot, mi
recode hoproin (-9/-1=.), gen (pests)
tab hoproin pests, mi
recode hoproco (-9/-1=.), gen (cold)
tab hoproco cold, mi
egen num_housing_probs=rowtotal(central_heat space-cold)
replace num_housing_probs=. if hopronz<0 & hopropo<0 & hoprord<0 & hoproro<0 ///
& hoprosn<0 & hoprosp<0 & hoprowa<0 & hoproin<0 & hoproep<0 & hoprodk<0 ///
& hoprocp<0 & hoproco<0 & hopro96<0 & hopro95<0 
tab num_housing_probs, mis
/*gen binary housing*/
gen housing_prob=.
replace housing_prob=0 if num_housing_probs>=1 & num_housing_probs!=.
replace housing_prob=1 if num_housing_probs==0
label define housing_prob 0 problems 1 "no problems"
label values housing_prob housing_prob
tab num_housing_probs housing_prob, mi
/************************************/
/*DURABLES*/
foreach var of varlist hohavtv hohavvr hohavcd hohavff hohavwm hohavwd hohavdw hohavmo hohavpc hohavdt hohavph hohavdv {
tab `var'
label list `var'
}
recode hohavtv (-9/-1=.), gen (tv)
tab hohavtv tv, mi
recode hohavvr (-9/-1=.), gen (video_rec)
tab hohavvr video_rec, mi
recode hohavcd (-9/-1=.), gen (cd_player)
tab hohavvr cd_player, mi
recode hohavff (-9/-1=.), gen (freezer)
tab hohavff freezer, mi
recode hohavwm (-9/-1=.), gen (wash_machin)
tab hohavwm wash_machin, mi
recode hohavwd (-9/-1=.), gen (tumble_dry)
tab hohavvr tumble_dry, mi
recode hohavdw (-9/-1=.), gen (dishwash)
tab hohavvr dishwash, mi
recode hohavmo (-9/-1=.), gen (microwave)
tab hohavmo microwave, mi
recode hohavpc (-9/-1=.), gen (pc)
tab hohavvr pc, mi
recode hohavdt (-9/-1=.), gen (sat_tv)
tab hohavvr sat_tv, mi
recode hohavph (-9/-1=.), gen (phone)
tab hohavvr phone, mi
recode hohavdv (-9/-1=.), gen (dvd)
tab hohavvr dvd, mi
egen count_durables=rowtotal(tv-dvd)
replace count_durables=. if hohavcd<0 & hohavdt<0 & hohavdv<0 & hohavdw<0 ///
& hohavff<0 & hohavmo<0 & hohavpc<0 & hohavph<0 & hohavtv<0 & hohavvr<0 & hohavwd<0 & hohavwm<0
tab count_durables, mis
/*gen cat var*/
recode count_durables (0 1=0) (2/4=1) (5/8=2) (9/12=3), gen(num_durables)
label define num_durables 0 "<2" 1 "2-4" 2 "5-8" 3 ">8"
label values num_durables num_durables
tab count_durables num_durables, mi
tab num_durables, mi
/********************************/
/*car, van or motorbike ownership*/
tab hoveh
label list hoveh
foreach var of varlist hocc01-hocc20{
label list `var'
}
gen car_ownership=.
replace car_ownership=0 if hoveh==0
replace car_ownership=1 if hoveh>=1
foreach var of varlist hocc01-hocc20{
replace car_ownership=1 if `var'==1 | `var'==3 | `var'==4 
}
label define car_ownership 0 "no car or van" 1 "at least 1 car, van or motorbike"
label values car_ownership car_ownership 
tab hoveh car_ownership, mi
/**************/
/*tenure binary*/
recode hotenu (1 2 3=1) (4 5 6=0) (-9 -8 -1 =.), gen(tenure3)
label define tenure3 1 "owner" 0 "other"
label values tenure3 tenure3
tab hotenu tenure3, mi
/***************************/
/*private insurance*/
tab wpphi
label list wpphi
gen private_health=.
replace private_health=0 if wpphi==3
replace private_health=1 if wpphi==1 | wpphi==2
label define private_health 0 "no private insurance" 1 "private insurance"
label values private_health private_health
tab wpphi private_health, mi
/***********************************/
/*TRANSPORT*/
tab spcar, mi
label list spcar
tab sptrmnee
label list sptrmnee
recode sptrmnee (-9/-1=.), gen (dont_need_to)
tab sptrmnee dont_need_to, mi
tab sptraa
label list sptraa
gen transport_deprived=0
replace transport_deprived=1 if spcar==2 & (sptraa==5 | sptraa==6 & dont_need_to!=1)
replace transport_deprived=. if spcar<0 & sptraa<0 
tab transport_deprived, mi
tab spcar transport_deprived, mi
tab sptraa transport_deprived, mi
/******************************************/
/*************************************/
/*SOCIAL INTEGRATION - see Banks 2010, and Ding 2017*/
/*higher is optimal*/
/*living with spouse or partner*/ 
/*NB wording of questions is 'do you have a husband or wife with whom you live?*/
/*need to check posibly with Ding that this is the correct var to use - it doesnt use the broader term spouse but i cant see a question that does*/
recode scptr (-9 -1 =.) (2 = 0), gen(livsppt)
tab scptr livsppt, mi
label var livsppt "living with spouse or partner"
/*do you have children family friends*/
foreach var of varlist scchd scfam scfrd{
tab `var'
label list `var'
}
/*contact with children, family, friends (including: face to face, phone, email or write)*/
/*NB for each group taking the highest from face to face, phone or email - this is not the only way to do this - you could for example take the average across the 3 types of contact ///
/// just be aware that this is essentially an arbritrary decision that could be questioned*/
foreach var of varlist scchdg scchdh scchdi scfamg scfamh scfami scfrdg scfrdh scfrdi {
tab `var'
label list `var'
recode `var' (-9 -1 = .) (1 2 = 3) (3 = 2) (4 = 1) (5 6 = 0), gen(`var'2)
}
replace scchdg2=0 if scchd==2
replace scchdh2=0 if scchd==2
replace scchdi2=0 if scchd==2
egen chicontact = rowmax(scchdg2 scchdh2 scchdi2)
label var chicontact "contact with children"
replace scfamg2=0 if scfam==2
replace scfamh2=0 if scfam==2
replace scfami2=0 if scfam==2
egen famcontact = rowmax(scfamg2 scfamh2 scfami2)
label var famcontact "contact with family"
replace scfrdg2=0 if scfrd==2
replace scfrdh2=0 if scfrd==2
replace scfrdi2=0 if scfrd==2
egen friecontact = rowmax(scfrdg2 scfrdh2 scfrdi2)
label var friecontact "contact with friends"
/*low membership of organisations*/
/*NB im including 'any other group' Ding does not include but i cant see a good reason for not including*/
foreach var of varlist scorg01 scorg02 scorg04 scorg05 scorg06 scorg07 scorg08{
tab `var'
label list `var'
recode `var' (-9 -1 = . ), gen (`var'2)
}
egen totalorgs = rowtotal (scorg012-scorg082)
replace totalorgs=. if (scorg012==. & scorg022==. & scorg042==. & scorg052==. & scorg062==. & scorg072==. & scorg082==.)
tab totalorgs, mi
recode totalorgs (1 2 = 1) (3 4 = 2) (5 6 7 = 3), gen(memorg)
label var memorg "membership of organisations"
tab memorg, mi
/*member of religious group*/
tab scorg03
label list scorg03
recode scorg03 (-9 -1 = .), gen (memreg)
label var memreg "membership of religious group"
tab memreg, mi
/*total social integration score - generate this after appending all files and imputing data for each component*/
/****************************************/
/*SOCIAL SUPPORT - see Banks 2010, and Dings 2017*/
/*do you have partner, children, family, friends?*/
foreach var of varlist scptr scchd scfam scfrd{
tab `var'
label list `var'
}
/*positive relationships with children, family and friends*/
foreach var of varlist scptra scptrb scptrc scchda scchdb scchdc scfama scfamb scfamc scfrda scfrdb scfrdc {
tab `var'
label list `var'
recode `var' (-9 -1 -8 = .) (1 = 3) (3 = 1) (4 = 0), gen(`var'2)
tab `var' `var'2, mi
}
/*negative relationships with children, family and friends*/
foreach var of varlist scptrd scptre scptrf scchdd scchde scchdf scfamd scfame scfamf scfrdd scfrde scfrdf {
tab `var'
label list `var'
recode `var' (-9 -1 = .) (1 = 0) (2 = 1) (3 = 2) (4 = 3), gen(`var'2)
tab `var' `var'2, mi
}
replace scptra2=0 if scptr==2
replace scptrb2=0 if scptr==2 
replace scptrc2=0 if scptr==2 
replace scptrd2=0 if scptr==2 
replace scptre2=0 if scptr==2 
replace scptrf2=0 if scptr==2

replace scchda2=0 if scchd==2
replace scchdb2=0 if scchd==2
replace scchdc2=0 if scchd==2
replace scchdd2=0 if scchd==2
replace scchde2=0 if scchd==2
replace scchdf2=0 if scchd==2

replace scfama2=0 if scfam==2
replace scfamb2=0 if scfam==2
replace scfamc2=0 if scfam==2
replace scfamd2=0 if scfam==2
replace scfame2=0 if scfam==2
replace scfamf2=0 if scfam==2

replace scfrda2=0 if scfrd==2
replace scfrdb2=0 if scfrd==2
replace scfrdc2=0 if scfrd==2
replace scfrdd2=0 if scfrd==2
replace scfrde2=0 if scfrd==2
replace scfrdf2=0 if scfrd==2
/*total social support score - generate this after appending all files and imputing data for each component*/
/******************************************************/
/*
/*QUALITY OF RELATIONSIPS*/
/*do you have partner, children, family, friends?*/
foreach var of varlist scptr scchd scfam scfrd{
tab `var'
label list `var'
}
/*contact and quality of relationship with spouse/partner*/
foreach var of varlist scptra-scptrg{
tab `var'
label list `var'
}
foreach var of varlist scptra scptrb scptrc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scptrd scptre scptrf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_partner=rowtotal(scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2)
replace quality_partner=. if scptra2==. & scptrb2==. & scptrc2==. & scptrd2==. & ///
 scptre2==. & scptrf2==. 
tab quality_partner, mi
tab quality_partner scptr, mi
/*contact and quality of relationship with children*/
foreach var of varlist scchda-scchdm{
tab `var'
label list `var'
}
foreach var of varlist scchda scchdb scchdc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scchdd scchde scchdf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_children=rowtotal(scchda2 scchdb2 scchdc2 scchdd2 scchde2 scchdf2)
replace quality_children=. if scchda2==. & scchdb2==. & scchdc2==. & scchdd2==. & ///
 scchde2==. & scchdf2==. 
tab quality_children, mi
tab quality_children scchd, mi 
/*contact and quality of relationship with family*/
foreach var of varlist scfama-scfamm{
tab `var'
label list `var'
}
foreach var of varlist scfama scfamb scfamc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scfamd scfame scfamf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_family=rowtotal(scfama2 scfamb2 scfamc2 scfamd2 scfame2 scfamf2)
replace quality_family=. if scfama2==. & scfamb2==. & scfamc2==. & scfamd2==. & ///
 scfame2==. & scfamf2==. 
tab quality_family, mi
tab quality_family scfam, mi
/*contact and quality of relationship with friends*/
foreach var of varlist scfrda-scfrdm{
tab `var'
label list `var'
}
foreach var of varlist scfrda scfrdb scfrdc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scfrdd scfrde scfrdf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_friends=rowtotal(scfrda2 scfrdb2 scfrdc2 scfrdd2 scfrde2 scfrdf2)
replace quality_friends=. if scfrda2==. & scfrdb2==. & scfrdc2==. & scfrdd2==. & ///
 scfrde2==. & scfrdf2==. 
tab quality_friends, mi
tab quality_friends scfrd, mi
/*SOCIAL ISOLATION*/
tab scptr
label list scptr
foreach var of varlist scchdi scfami scfrdi{
tab `var'
label list `var'
}
gen social_isolation=0
replace social_isolation=1 if scptr==2 & (scchdi!=1 | scfami!=1 | scfrdi!=1)
replace social_isolation=. if scptr<0 & scchdi<0 & scfami<0 & scfrdi<0
tab social_isolation, mi
*/
/*************************************************/
/*FRAILTY INDEX*/
/*mobility difficulties*/
foreach var of varlist hemobwa-hemobpi{
tab `var', mi
label list `var'
}
recode hemobwa (-9/-1=.), gen (M_walking)
tab hemobwa M_walking, mi
recode hemobsi (-9/-1=.), gen (M_sitting)
tab hemobsi M_sitting, mi
recode hemobch (-9/-1=.), gen (M_getting_up)
tab hemobch M_getting_up, mi
recode hemobcs (-9/-1=.), gen (M_stairs_several)
tab hemobcs M_stairs_several, mi
recode hemobcl (-9/-1=.), gen (M_stairs_one)
tab hemobcl M_stairs_one, mi
recode hemobst (-9/-1=.), gen (M_stoop)
tab hemobst M_stoop, mi
recode hemobre (-9/-1=.), gen (M_reaching)
tab hemobre M_reaching, mi
recode hemobpu (-9/-1=.), gen (M_pulling)
tab hemobpu M_pulling, mi
recode hemobli (-9/-1=.), gen (M_lifting)
tab hemobli M_lifting, mi
recode hemobpi (-9/-1=.), gen (M_picking)
tab hemobpi M_picking, mi

/*disability ADL/iADL*/
foreach var of varlist headldr-headlmo{
tab `var', mi
label list `var'
}
recode headldr (-9/-1=.), gen (ADL_dressing)
tab headldr ADL_dressing, mi
recode headlwa (-9/-1=.), gen (ADL_walking)
tab headlwa ADL_walking, mi
recode headlba (-9/-1=.), gen (ADL_bathing)
tab headlba ADL_bathing, mi
recode headlea (-9/-1=.), gen (ADL_eating)
tab headlea ADL_eating, mi
recode headlbe (-9/-1=.), gen (ADL_outofbed)
tab headlbe ADL_outofbed, mi
recode headlwc (-9/-1=.), gen (ADL_toilet)
tab headlwc ADL_toilet, mi
recode headlma (-9/-1=.), gen (ADL_usingmap)
tab headlma ADL_usingmap, mi
recode headlpr (-9/-1=.), gen (ADL_hotmeal)
tab headlpr ADL_hotmeal, mi
recode headlsh (-9/-1=.), gen (ADL_shopping)
tab headlsh ADL_shopping, mi
recode headlph (-9/-1=.), gen (ADL_telephone)
tab headlph ADL_telephone, mi
recode headlme (-9/-1=.), gen (ADL_medication)
tab headlme ADL_medication, mi
recode headlho (-9/-1=.), gen (ADL_housework)
tab headlho ADL_housework, mi
recode headlmo (-9/-1=.), gen (ADL_money)
tab headlmo ADL_money, mi

/*general health*/
tab hegenh, mi 
label list hegenh
gen general_health=0
replace general_health=1 if hegenh==4 | hegenh==5
replace general_health=. if hegenh<0
tab hegenh general_health, mi
tab general_health, mi
/*2nd general health var - wave 3 vars does not have the 'excellent' cat??*/
/*depressive symptoms*/
foreach var of varlist psceda-pscedc pscede pscedg pscedh{
tab `var'
label list `var'
recode `var' (2=0) (-9/-1=.), gen (dep_`var')
tab `var' dep_`var', mi
}
foreach var of varlist pscedf pscedd{
tab `var'
label list `var'
recode `var' (2=1) (1=0) (-9/-1=.), gen(dep_`var')
tab `var' dep_`var', mi
}
/*high BP - stroke*/
foreach var of varlist hedimbp-hedimst{
tab `var', mi
label list `var'
}
recode hedimbp (1/3=1) (-9/-1=0), gen (highBP)
tab hedimbp highBP, mi
recode hediman (1/3=1) (-9/-1=0), gen (angina)
tab hediman angina, mi
recode hedimmi (1/3=1) (-9/-1=0), gen (heartattack)
tab hedimmi heartattack, mi
recode hedimhf (1/3=1) (-9/-1=0), gen (congestHF)
tab hedimhf congestHF, mi
recode hedimar (1/3=1) (-9/-1=0), gen (abnormalheart)
tab hedimar abnormalheart, mi
recode hedimdi (1/3=1) (-9/-1=0), gen (diabetes)
tab hedimdi diabetes, mi
recode hedimst (1/3=1) (-9/-1=0), gen (stroke)
tab hedimst stroke, mi 
/*NB - PROBLEM - no missing data for these vars*/
/*
/*newley diagnosed*/
DONT USE THIS BUT KEEP INCASE NEEDED LATER
foreach var of varlist dhedimbp-dhedimst{
tab `var', mi
label list `var'
}
recode dhedimbp (-9/-1=.), gen (highBPA)
tab dhedimbp highBP, mi
recode dhediman (-9/-1=.), gen (anginaA)
tab dhediman angina, mi
recode dhedimmi (-9/-1=.), gen (heartattackA)
tab dhedimmi heartattack, mi
recode dhedimhf (-9/-1=.), gen (congestHFA)
tab dhedimhf congestHF, mi
recode dhedimar (-9/-1=.), gen (abnormalheartA)
tab dhedimar abnormalheart, mi
recode dhedimdi (-9/-1=.), gen (diabetesA)
tab dhedimdi diabetes, mi
recode dhedimst (-9/-1=.), gen (strokeA)
tab dhedimst stroke, mi
/*fed forward*/
foreach var of varlist hedawbp-hedawst{
tab `var', mi
label list `var'
}
gen highBPB=0
gen anginaB=0
gen heartattackB=0
gen congestHFB=0
gen abnormalheartB=0
gen diabetesB=0
gen strokeB=0
gen miss_flagB=0
replace miss_flag=1 if hedawbp<0
foreach var of varlist hedawbp-hedawst{
replace highBPB=1 if `var'==1
replace anginaB=1 if `var'==2
replace heartattackB=1 if `var'==3
replace congestHFB=1 if `var'==4
replace abnormalheartB=1 if `var'==6
replace diabetesB=1 if `var'==7
replace strokeB=1 if `var'==8
}
foreach var of varlist highBPB-strokeB{
replace `var'=. if miss_flag==1
tab `var', mi
}
gen highBP=highBPB
gen angina=anginaB
gen heartattack=heartattackB
gen congestHF=congestHFB
gen abnormalheart=abnormalheartB
gen diabetes=diabetesB
gen stroke=strokeB
replace highBP=1 if highBPA==1
replace angina=1 if anginaA==1
replace heartattack=1 if heartattackA==1
replace congestHF=1 if congestHFA==1
replace abnormalheart=1 if abnormalheartA==1
replace diabetes=1 if diabetesA==1
replace stroke=1 if strokeA==1
foreach var of varlist highBP-stroke{
tab `var', mi
}
*/
/*chronic lung - dementia*/
foreach var of varlist hediblu-hedibde{
tab `var', mi
label list `var'
}
recode hediblu (1/3=1) (-3 =0) (-2/-1=.), gen (chroniclung)
tab hediblu chroniclung, mi
recode hedibas (1/3=1) (-3 =0) (-2/-1=.), gen (asthma)
tab hedibas asthma, mi
recode hedibar (1/3=1) (-3 =0) (-2/-1=.), gen (arthritis)
tab hedibar arthritis, mi
recode hedibos (1/3=1) (-3 =0) (-2/-1=.), gen (osteoporosis)
tab hedibos osteoporosis, mi
recode hedibca (1/3=1) (-3 =0) (-2/-1=.), gen (cancer)
tab hedibca cancer, mi
recode hedibpd (1/3=1) (-3 =0) (-2/-1=.), gen (parkinsons)
tab hedibpd parkinsons, mi
recode hedibps (1/3=1) (-3 =0) (-2/-1=.), gen (anyemotional)
tab hedibps anyemotional, mi
recode hedibad (1/3=1) (-3 =0) (-2/-1=.), gen (alzheimers)
tab hedibad alzheimers, mi
recode hedibde (1/3=1) (-3 =0) (-2/-1=.), gen (dementia)
tab hedibde dementia, mi
/*NB - PROBLEM - no missing data for these vars*/
/*eyesight*/
tab heeye, mi
label list heeye
recode heeye (-9/-1=.) (1/3=0) (4/6=1), gen(eyesight)
tab heeye eyesight, mi
/*hearing*/
tab hehear, mi
label list hehear
recode hehear (-9/-1=.) (1/3=0) (4/5=1), gen(hearing)
tab hehear hearing, mi
/*cognitive function*/
/*date test*/
tab cfdatd, mi
label list cfdatd
recode cfdatd (-9/-1=.) (2=1) (1=0), gen(todaysdate)
tab cfdatd todaysdate, mi
/**/
tab cfdatm, mi
label list cfdatm
recode cfdatm (-9/-1=.) (2=1) (1=0), gen(month)
tab cfdatm month, mi
/**/
tab cfdaty, mi
label list cfdaty
recode cfdaty (-9/-1=.) (2=1) (1=0), gen(year)
tab cfdaty year, mi
/**/
tab cfday, mi
label list cfday
recode cfday (-9/-1=.) (2=1) (1=0), gen(dayofweek)
tab cfday dayofweek, mi
/*word recall*/
/*delay*/
tab cflisd, mi
label list cflisd
recode cflisd (-9/-1=.), gen(word_recall_delay)
tab cflisd word_recall_delay, mi
/*immediately*/
tab cflisen, mi
label list cflisen
recode cflisen (-9/-1=.), gen(word_recall_immed)
tab cflisen word_recall_immed, mi
/*******************************/
/*unmet need score*/
/*************/
/*move round house*/
gen move_need=1 if headlwa==1
replace move_need=0 if headlwa==0
/*wash or dress*/
gen washdress_need=1 if headlba==1 | headldr==1
replace washdress_need=0 if headlba==0 | headldr==0 
/*prepare meal or eat*/
gen mealeat_need=1 if headlea==1 | headlpr==1
replace mealeat_need=0 if headlea==0 | headlpr==0
/*shopping or housework*/
gen shophous_need=1 if headlsh==1 | headlho==1
replace shophous_need=0 if headlsh==0 | headlho==0 
/*phone or money*/
gen phonemon_need=1 if headlph==1 | headlmo==1
replace phonemon_need=0 if headlph==0 | headlmo==0
/*medications*/
gen medicat_need=1 if headlme==1
replace medicat_need=0 if headlme==0
/****************************************/
/*type of care recieved*/
foreach var of varlist hehphsp - hehpm96{
tab `var', mi
label list `var'
}
/*move round house*/
gen move=1 if hehphsp==1 | hehphpa==1 | hehphso==1 | hehphsl==1 | hehphda==1 | hehphdl==1 | hehphsi==1 | hehphbr==1 | hehphgs==1 | hehphgd==1 | hehphor==1 | hehphfr==1
replace move=2 if hehphss==1 | hehphnu==1 | hehphos==1
replace move=3 if hehphpr==1
replace move=4 if hehphot==1 | hehphvo==1
replace move=5 if hehph96==1
replace move=0 if move_need==0 
/*wash or dress*/
gen washdress=1 if hehpwsp==1 | hehpwpa==1 | hehpwso==1 | hehpwsl==1 | hehpwda==1 | hehpwdl==1 | hehpwsi==1 | hehpwbr==1 | hehpwgs==1 | hehpwgd==1 | hehpwor==1 |  hehpwfr==1
replace washdress=2 if hehpwss==1 | hehpwnu==1 | hehpwos==1
replace washdress=3 if hehpwpr==1
replace washdress=4 if hehpwot==1 | hehpwvo==1
replace washdress=5 if hehpw96==1
replace washdress=0 if washdress_need==0
/*prepare meal or eat*/
gen mealeat=1 if hehpdsp==1 | hehpdpa==1 | hehpdso==1 | hehpdsl==1 | hehpdda==1 | hehpddl==1 | hehpdsi==1 | hehpdbr==1 | hehpdgs==1 | hehpdgd==1 | hehpdor==1 |  hehpdfr==1
replace mealeat=2 if hehpdss==1 | hehpdnu==1 | hehpdos==1
replace mealeat=3 if hehpdpr==1
replace mealeat=4 if hehpdot==1 | hehpdvo==1
replace mealeat=5 if hehpd96==1
replace mealeat=0 if mealeat_need==0
/*shopping or housework*/
gen shophous=1 if hehppsp==1 | hehpppa==1 | hehppso==1 | hehppsl==1 | hehppda==1 | hehppdl==1 | hehppsi==1 | hehppbr==1 | hehppgs==1 | hehppgd==1 | hehppor==1 |  hehppfr==1
replace shophous=2 if hehppss==1 | hehppnu==1 | hehppos==1
replace shophous=3 if hehpppr==1
replace shophous=4 if hehppvo==1 |  hehppot==1
replace shophous=5 if hehpp96==1
replace shophous=0 if shophous_need==0
/*phone or money*/
gen phonemon=1 if hehptsp==1 | hehptpa==1 | hehptso==1 | hehptsl==1 | hehptda==1 | hehptdl==1 | hehptsi==1 | hehptbr==1 | hehptgs==1 | hehptgd==1 | hehptor==1 |  hehptfr==1
replace phonemon=2 if hehptss==1 | hehptnu==1 | hehptos==1
replace phonemon=3 if hehptpr==1
replace phonemon=4 if hehptvo==1 |  hehptot==1
replace phonemon=5 if hehpt96==1
replace phonemon=0 if phonemon_need==0
/*medications*/
gen medicat=1 if hehpmsp==1 | hehpmpa==1 | hehpmso==1 | hehpmsl==1 | hehpmda==1 | hehpmdl==1 | hehpmsi==1 | hehpmbr==1 | hehpmgs==1 | hehpmgd==1 | hehpmor==1 |  hehpmfr==1
replace medicat=2 if hehpmss==1 | hehpmnu==1 | hehpmos==1
replace medicat=3 if hehpmpr==1
replace medicat=4 if hehpmvo==1 |  hehpmot==1
replace medicat=5 if hehpm96==1
replace medicat=0 if medicat_need==0
/*label the care provided*/
label define carelab 0 "no need identified" 1 "met by informal" 2 "met by state" 3 "met by private" 4 "met by other" 5 "not met"
foreach var of varlist move-medicat{
label values `var' carelab
}
/*see how many care needs, and care recieved were asked about*/
/*will use to set the flags to missign where incomplete data*/
egen adliadl_items=rownonmiss(move_need washdress_need mealeat_need shophous_need phonemon_need medicat_need)
tab adliadl_items, mi 
egen care_recieveditems=rownonmiss(move washdress mealeat shophous phonemon medicat)
/*gen unmet by formal flag*/
gen unmet_flag=0
gen unmet_formal=0
foreach var of varlist move-medicat{
replace unmet_flag=1 if `var'_need==1 & `var'==5
replace unmet_formal=1 if `var'_need==1 & (`var'!=2 | `var'!=3)
}
replace unmet_formal=. if adliadl_items<6 | care_recieveditems<6
replace unmet_flag=. if adliadl_items<6 | care_recieveditems<6
/**********************************************/
/*CASP plus control, create vars for latent psychosocial path*/
/*positively worded*/
foreach var of varlist scqolc scqole scqolg{
recode `var' (1=3) (2=2) (3=1) (4=0), gen(`var'2)
}
/*negatively worded*/
foreach var of varlist scqola scqolb scqold scqolf {
recode `var' (1=0) (2=1) (3=2) (4=3), gen(`var'2)
}
/*2 extra questions, not casp*/
/*positive*/ recode scdca (1=5) (2=4) (3=3) (4=2) (5=1) (6=0), gen(scdca2)
/*negative*/ recode scdcc (1=0) (2=1) (3=2) (4=3) (5=4) (6=5), gen(scdcc2) 

order scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2, after(scqolg)
browse scqola scqolb scqolc scqold scqole scqolf scqolg scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca scdca2 scdcc scdcc2
foreach var of varlist scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca2 scdcc2 {
replace `var'=. if `var'<0
}
/*ITEMS FOR BEHAVIOURAL FACTOR*/
/*SMOKING*/
/*ever smoked*/
tab hesmk
label list hesmk
/*currently*/ 
tab heska
label list heska
tab hesmk heska
gen smoke3=.
replace smoke3=2 if hesmk==2
replace smoke3=1 if hesmk==1 & heska==2
replace smoke3=0 if heska==1
label define smoke3 0 "current smoker" 1 "past smoker" 2 "never smoked"
label values smoke3 smoke3
tab heska smoke3, mi
tab hesmk smoke3, mi
/*EXERCISE*/
tab heactb
label list heactb
recode heactb (1=2) (2 3=1) (4=0) (-9/-1=.), gen(exercise_mod)
label define exercise_mod 2 "2 or more times per week" 1 "1 to 4 times per month" 0 "hardly ever or never" 
label values exercise_mod exercise_mod
tab heactb exercise_mod, mi
/************************************************/
/*ACCESS ITEMS*/
/*GP and dentist - NOT AVAILABLE IN WAVE 3*/
/**********************************************************************************/
/************************************************/
/*KEEP ONLY THE VARS I NEED*/
keep idauniq dateofinterview SIFdateofinterview ethnicity wave nssec8 nssec5 nssec3 tenure2 fqend w3edqual difjob2 sclddr2 ///
num_durables num_housing_probs housing_prob car_ownership tenure3 private_health ///
scptr scchd scfam scfrd livsppt chicontact famcontact friecontact memorg memreg ///
scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2 ///
scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2 ///
scptr scchd scfam scfrd ///
scchdg2 scchdh2 scchdi2 scfamg2 scfamh2 scfami2 scfrdg2 scfrdh2 scfrdi2 ///
scorg012 scorg022 scorg042 scorg052 scorg062 scorg072 scorg082 ///
M_walking M_sitting M_getting_up M_stairs_several M_stairs_one M_stoop M_reaching ///
M_pulling M_lifting M_picking ADL_dressing ADL_walking ADL_bathing ADL_eating ///
ADL_outofbed ADL_toilet ADL_usingmap ADL_hotmeal ADL_shopping ADL_telephone ADL_medication ///
ADL_housework ADL_money general_health dep_psceda dep_pscedb dep_pscedc dep_pscedd ///
dep_pscede dep_pscedf dep_pscedg dep_pscedh highBP angina heartattack congestHF ///
abnormalheart diabetes stroke chroniclung asthma arthritis osteoporosis cancer ///
parkinsons anyemotional alzheimers dementia eyesight hearing todaysdate month ///
year dayofweek word_recall_delay word_recall_immed ///
unmet_flag unmet_formal ///
scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca2 scdcc2 ///
smoke3 exercise_mod transport_deprived
save "$work\wave_3_elsa_data_v4_prepped.dta", replace

/**********************************************************************************/
/*WAVE 4*/
clear
use "$raw\wave_4_elsa_data_v3.dta"
/*interview date*/
tab iintdatm
tab iintdaty 
tostring iintdatm, force replace
tostring iintdaty, force replace
gen dateofinterview= "01/" + iintdatm + "/" + iintdaty 
gen SIFdateofinterview=date(dateofinterview, "DMY")
/*gen wave num*/
gen wave=4
/*ethnicity*/
label list fqethnr
recode fqethnr (-9/-1 = .), gen(ethnicity)
tab ethnicity fqethnr, mi
label define ethnicitylab 1 White 2 "Non-white"
label values ethnicity ethnicitylab
/*NS-SEC*/
/*8 cat*/
tab w4nssec8, mi 
describe w4nssec8
label list w4nssec8 
recode w4nssec8 (-6/-1  =.), gen(nssec8)
label values nssec8 w4nssec8
tab w4nssec8 nssec8, mi
/*5 cat*/
tab w4nssec5, mi 
describe w4nssec5
label list w4nssec5 
recode w4nssec5 (-6/-1 =.), gen(nssec5)
label values nssec5 w4nssec5
tab w4nssec5 nssec5, mi
/*3 cat*/
tab w4nssec3, mi 
describe w4nssec3
label list w4nssec3 
recode w4nssec3 (-6/-1 =.), gen(nssec3)
label values nssec3 w4nssec3
tab w4nssec3 nssec3, mi
/*************************/
/*HOUSING TENURE - coding from wave 4 and 6 reports*/
tab hotenu
label list hotenu
recode hotenu (2 3 =2) (4 5 =3) (6 =4) (-9 -8 -1 =.), gen(tenure2)
label define atenureb2 1 "Owner occupied" 2 "Buying with mortgage" 3 "Renting or rent free" 4 "Other" 
label values tenure2 atenureb2
tab hotenu tenure2, mi
/************************/
/*EDUCATION*/
tab w4edqual/*high qual*/
label list w4edqual
/*recode highest qual as in panos wealth paper*/ /*
recode w4edqual (1/3=1) (4/6=2) (7=3) (-9 -8 -3 =.), gen(edqual2)
label define edqual2lab 1 "A-level or higher" 2 "GCSE/O-level/other qualification" 3 "No qualification"
label values edqual2 edqual2lab
tab w4edqual edqual2, mi */
/***************************/
/*PATERNAL OCCUPATIONAL CLASS AT 14*/
/*recode fathers occu as in panos wealth paper*/
tab difjob /*fathers occup*/
label list difjob
recode difjob (2 3 4 = 1) (5 6 = 2) (7 8 9 12 14 15 = 3) (10 11 13 1 = 4) (-9 -8 -2 -1 =.), gen(difjob2)
label define difjob2lab 1 "Managerial and professional occupations/run own business" ///
2 "Intermediate occupations" 3 "Routine occupations/casual jobs/unemployed/disabled" ///
4 "Other (incl Armed Forces and Retired)"
label values difjob2 difjob2lab
tab difjob difjob2, mis
/*****************************/
/*SUBJECTIVE SOCIAL STATUS - 10 RUNG*/
tab sclddr /*sss*/
label list sclddr
recode sclddr (5 10 =10) (15 20=20) (25 30 =30) (35 40 =40) (45 50 =50) (55 60 =60) (65 70 =70) (75 80 =80) ///
(85 90 =90) (95 100 =100) (-9/-1 =.), gen(sclddr2)
tab sclddr sclddr2, mi
/*******************************/
/*ITEMS FOR MATERIAL DEPRIVATION FACTOR*/
/*HOUSING problems*/
tab hocenh 
label list hocenh 
gen central_heat=.
replace central_heat=1 if hocenh==2
tab hocenh central_heat, mi
foreach var of varlist hopromsp-hopromco{
tab `var'
describe `var'
label list `var'
}
recode hoprosp (-9/-1=.), gen (space)
tab hoprosp space, mi
recode hoprodk (-9/-1=.), gen (dark)
tab hoprodk dark, mi
recode hoprord (-9/-1=.), gen (damp)
tab hoprord damp, mi
recode hoprowa (-9/-1=.), gen (roof)
tab hoprowa roof, mi
recode hoprocp (-9/-1=.), gen (condensation)
tab hoprocp condensation, mi
recode hoproep (-9/-1=.), gen (electrics)
tab hoproep electrics, mi
recode hoproro (-9/-1=.), gen (rot)
tab hoproro rot, mi
recode hoproin (-9/-1=.), gen (pests)
tab hoproin pests, mi
recode hoproco (-9/-1=.), gen (cold)
tab hoproco cold, mi
egen num_housing_probs=rowtotal(central_heat space-cold)
replace num_housing_probs=. if hopronz<0 & hopropo<0 & hoprord<0 & hoproro<0 ///
& hoprosn<0 & hoprosp<0 & hoprowa<0 & hoproin<0 & hoproep<0 & hoprodk<0 ///
& hoprocp<0 & hoproco<0 & hopro96<0 & hopro95<0 
tab num_housing_probs, mis
/*gen binary housing*/
gen housing_prob=.
replace housing_prob=0 if num_housing_probs>=1 & num_housing_probs!=.
replace housing_prob=1 if num_housing_probs==0
label define housing_prob 0 problems 1 "no problems"
label values housing_prob housing_prob
tab num_housing_probs housing_prob, mi
/************************************/
/*DURABLES*/
foreach var of varlist hohavtv hohavvr hohavcd hohavff hohavwm hohavwd hohavdw hohavmo hohavpc hohavdt hohavph hohavdv {
tab `var'
label list `var'
}
recode hohavtv (-9/-1=.), gen (tv)
tab hohavtv tv, mi
recode hohavvr (-9/-1=.), gen (video_rec)
tab hohavvr video_rec, mi
recode hohavcd (-9/-1=.), gen (cd_player)
tab hohavvr cd_player, mi
recode hohavff (-9/-1=.), gen (freezer)
tab hohavff freezer, mi
recode hohavwm (-9/-1=.), gen (wash_machin)
tab hohavwm wash_machin, mi
recode hohavwd (-9/-1=.), gen (tumble_dry)
tab hohavvr tumble_dry, mi
recode hohavdw (-9/-1=.), gen (dishwash)
tab hohavvr dishwash, mi
recode hohavmo (-9/-1=.), gen (microwave)
tab hohavmo microwave, mi
recode hohavpc (-9/-1=.), gen (pc)
tab hohavvr pc, mi
recode hohavdt (-9/-1=.), gen (sat_tv)
tab hohavvr sat_tv, mi
recode hohavph (-9/-1=.), gen (phone)
tab hohavvr phone, mi
recode hohavdv (-9/-1=.), gen (dvd)
tab hohavvr dvd, mi
egen count_durables=rowtotal(tv-dvd)
replace count_durables=. if hohavcd<0 & hohavdt<0 & hohavdv<0 & hohavdw<0 ///
& hohavff<0 & hohavmo<0 & hohavpc<0 & hohavph<0 & hohavtv<0 & hohavvr<0 & hohavwd<0 & hohavwm<0
tab count_durables, mis
/*gen cat var*/
recode count_durables (0 1=0) (2/4=1) (5/8=2) (9/12=3), gen(num_durables)
label define num_durables 0 "<2" 1 "2-4" 2 "5-8" 3 ">8"
label values num_durables num_durables
tab count_durables num_durables, mi
tab num_durables, mi
/********************************/
/*car, van or motorbike ownership*/
tab hoveh
label list hoveh
foreach var of varlist hocc01-hocc20{
label list `var'
}
gen car_ownership=.
replace car_ownership=0 if hoveh==0
replace car_ownership=1 if hoveh>=1
foreach var of varlist hocc01-hocc20{
replace car_ownership=1 if `var'==1 | `var'==3 | `var'==4 
}
label define car_ownership 0 "no car or van" 1 "at least 1 car, van or motorbike"
label values car_ownership car_ownership 
tab hoveh car_ownership, mi
/**************/
/*tenure binary*/
recode hotenu (1 2 3=1) (4 5 6=0) (-9 -8 -1 =.), gen(tenure3)
label define tenure3 1 "owner" 0 "other"
label values tenure3 tenure3
tab hotenu tenure3, mi
/***************************/
/*private insurance*/
tab wpphi
label list wpphi
gen private_health=.
replace private_health=0 if wpphi==3
replace private_health=1 if wpphi==1 | wpphi==2
label define private_health 0 "no private insurance" 1 "private insurance"
label values private_health private_health
tab wpphi private_health, mi
/***********************************/
/***********************************/
/*TRANSPORT*/
tab spcar, mi
label list spcar
tab sptrmnee
label list sptrmnee
recode sptrmnee (-9/-1=.), gen (dont_need_to)
tab sptrmnee dont_need_to, mi
tab sptraa
label list sptraa
gen transport_deprived=0
replace transport_deprived=1 if spcar==2 & (sptraa==5 | sptraa==6 & dont_need_to!=1)
replace transport_deprived=. if spcar<0 & sptraa<0 
tab transport_deprived, mi
tab spcar transport_deprived, mi
tab sptraa transport_deprived, mi
/*************************************/
/*SOCIAL INTEGRATION - see Banks 2010, and Ding 2017*/
/*higher is optimal*/
/*living with spouse or partner*/ 
/*NB wording of questions is 'do you have a husband or wife with whom you live?*/
/*need to check posibly with Ding that this is the correct var to use - it doesnt use the broader term spouse but i cant see a question that does*/
tab scptr, mi
label list scptr
recode scptr (-9 -1 -8 =.) (2 = 0), gen(livsppt)
tab scptr livsppt, mi
label var livsppt "living with spouse or partner"
/*do you have children family friends*/
foreach var of varlist scchd scfam scfrd{
tab `var'
label list `var'
}
/*contact with children, family, friends (including: face to face, phone, email or write)*/
/*NB for each group taking the highest from face to face, phone or email - this is not the only way to do this - you could for example take the average across the 3 types of contact ///
/// just be aware that this is essentially an arbritrary decision that could be questioned*/
foreach var of varlist scchdg scchdh scchdi scfamg scfmh scfami scfrdg scfrdh scfrdi {
tab `var'
label list `var'
recode `var' (-9 -1 -8 = .) (1 2 = 3) (3 = 2) (4 = 1) (5 6 = 0), gen(`var'2)
}
replace scchdg2=0 if scchd==2
replace scchdh2=0 if scchd==2
replace scchdi2=0 if scchd==2
egen chicontact = rowmax(scchdg2 scchdh2 scchdi2)
label var chicontact "contact with children"
replace scfamg2=0 if scfam==2
replace scfmh2=0 if scfam==2
replace scfami2=0 if scfam==2
egen famcontact = rowmax(scfamg2 scfmh2 scfami2)
label var famcontact "contact with family"
replace scfrdg2=0 if scfrd==2
replace scfrdh2=0 if scfrd==2
replace scfrdi2=0 if scfrd==2
egen friecontact = rowmax(scfrdg2 scfrdh2 scfrdi2)
label var friecontact "contact with friends"
/*low membership of organisations*/
/*NB im including 'any other group' Ding does not include but i cant see a good reason for not including*/
foreach var of varlist scorg01 scorg02 scorg04 scorg05 scorg06 scorg07 scorg08{
tab `var'
label list `var'
recode `var' (-9 -1 -8 = . ), gen (`var'2)
}
egen totalorgs = rowtotal (scorg012-scorg082)
replace totalorgs=. if (scorg012==. & scorg022==. & scorg042==. & scorg052==. & scorg062==. & scorg072==. & scorg082==.)
tab totalorgs, mi
recode totalorgs (1 2 = 1) (3 4 = 2) (5 6 7 = 3), gen(memorg)
label var memorg "membership of organisations"
tab memorg, mi
/*member of religious group*/
tab scorg03
label list scorg03
recode scorg03 (-9 -1 = .), gen (memreg)
label var memreg "membership of religious group"
tab memreg, mi
/*total social integration score - generate this after appending all files and imputing data for each component*/
/****************************************/
/*SOCIAL SUPPORT - see Banks 2010, and Dings 2017*/
/*do you have partner, children, family, friends?*/
foreach var of varlist scptr scchd scfam scfrd{
tab `var'
label list `var'
}
/*positive relationships with children, family and friends*/
foreach var of varlist scptra scptrb scptrc scchda scchdb scchdc scfama scfamb scfamc scfrda scfrdb scfrdc {
tab `var'
label list `var'
recode `var' (-9 -1 -8 = .) (1 = 3) (3 = 1) (4 = 0), gen(`var'2)
tab `var' `var'2, mi
}
/*negative relationships with children, family and friends*/
foreach var of varlist scptrd scptre scptrf scchdd scchde scchdf scfamd scfame scfamf scfrdd scfrde scfrdf {
tab `var'
label list `var'
recode `var' (-9 -1 = .) (1 = 0) (2 = 1) (3 = 2) (4 = 3), gen(`var'2)
tab `var' `var'2, mi
}
replace scptra2=0 if scptr==2
replace scptrb2=0 if scptr==2 
replace scptrc2=0 if scptr==2 
replace scptrd2=0 if scptr==2 
replace scptre2=0 if scptr==2 
replace scptrf2=0 if scptr==2

replace scchda2=0 if scchd==2
replace scchdb2=0 if scchd==2
replace scchdc2=0 if scchd==2
replace scchdd2=0 if scchd==2
replace scchde2=0 if scchd==2
replace scchdf2=0 if scchd==2

replace scfama2=0 if scfam==2
replace scfamb2=0 if scfam==2
replace scfamc2=0 if scfam==2
replace scfamd2=0 if scfam==2
replace scfame2=0 if scfam==2
replace scfamf2=0 if scfam==2

replace scfrda2=0 if scfrd==2
replace scfrdb2=0 if scfrd==2
replace scfrdc2=0 if scfrd==2
replace scfrdd2=0 if scfrd==2
replace scfrde2=0 if scfrd==2
replace scfrdf2=0 if scfrd==2
/*total social support score - generate this after appending all files and imputing data for each component*/
/*
/******************************************/
/*QUALITY OF RELATIONSIPS*/
/*do you have partner, children, family, friends?*/
foreach var of varlist scptr scchd scfam scfrd{
tab `var'
label list `var'
}
/*contact and quality of relationship with spouse/partner*/
foreach var of varlist scptra-scptrg{
tab `var'
label list `var'
}
foreach var of varlist scptra scptrb scptrc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scptrd scptre scptrf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_partner=rowtotal(scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2)
replace quality_partner=. if scptra2==. & scptrb2==. & scptrc2==. & scptrd2==. & ///
 scptre2==. & scptrf2==. 
tab quality_partner, mi
tab quality_partner scptr, mi
/*contact and quality of relationship with children*/
foreach var of varlist scchda-scchdm{
tab `var'
label list `var'
}
foreach var of varlist scchda scchdb scchdc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scchdd scchde scchdf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_children=rowtotal(scchda2 scchdb2 scchdc2 scchdd2 scchde2 scchdf2)
replace quality_children=. if scchda2==. & scchdb2==. & scchdc2==. & scchdd2==. & ///
 scchde2==. & scchdf2==. 
tab quality_children, mi
tab quality_children scchd, mi 
/*contact and quality of relationship with family*/
foreach var of varlist scfama-scfamm{
tab `var'
label list `var'
}
foreach var of varlist scfama scfamb scfamc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scfamd scfame scfamf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_family=rowtotal(scfama2 scfamb2 scfamc2 scfamd2 scfame2 scfamf2)
replace quality_family=. if scfama2==. & scfamb2==. & scfamc2==. & scfamd2==. & ///
 scfame2==. & scfamf2==. 
tab quality_family, mi
tab quality_family scfam, mi
/*contact and quality of relationship with friends*/
foreach var of varlist scfrda-scfrdm{
tab `var'
label list `var'
}
foreach var of varlist scfrda scfrdb scfrdc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scfrdd scfrde scfrdf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_friends=rowtotal(scfrda2 scfrdb2 scfrdc2 scfrdd2 scfrde2 scfrdf2)
replace quality_friends=. if scfrda2==. & scfrdb2==. & scfrdc2==. & scfrdd2==. & ///
 scfrde2==. & scfrdf2==. 
tab quality_friends, mi
tab quality_friends scfrd, mi
/*SOCIAL ISOLATION*/
tab scptr
label list scptr
foreach var of varlist scchdi scfami scfrdi{
tab `var'
label list `var'
}
gen social_isolation=0
replace social_isolation=1 if scptr==2 & (scchdi!=1 | scfami!=1 | scfrdi!=1)
replace social_isolation=. if scptr<0 & scchdi<0 & scfami<0 & scfrdi<0
tab social_isolation, mi
*/
/************************************************/
/*FRAILTY INDEX*/
/*mobility difficulties*/
foreach var of varlist hemobwa-hemobpi{
tab `var', mi
label list `var'
}
recode hemobwa (-9/-1=.), gen (M_walking)
tab hemobwa M_walking, mi
recode hemobsi (-9/-1=.), gen (M_sitting)
tab hemobsi M_sitting, mi
recode hemobch (-9/-1=.), gen (M_getting_up)
tab hemobch M_getting_up, mi
recode hemobcs (-9/-1=.), gen (M_stairs_several)
tab hemobcs M_stairs_several, mi
recode hemobcl (-9/-1=.), gen (M_stairs_one)
tab hemobcl M_stairs_one, mi
recode hemobst (-9/-1=.), gen (M_stoop)
tab hemobst M_stoop, mi
recode hemobre (-9/-1=.), gen (M_reaching)
tab hemobre M_reaching, mi
recode hemobpu (-9/-1=.), gen (M_pulling)
tab hemobpu M_pulling, mi
recode hemobli (-9/-1=.), gen (M_lifting)
tab hemobli M_lifting, mi
recode hemobpi (-9/-1=.), gen (M_picking)
tab hemobpi M_picking, mi
/*disability ADL/iADL*/
foreach var of varlist headldr-headlmo{
tab `var', mi
label list `var'
}
recode headldr (-9/-1=.), gen (ADL_dressing)
tab headldr ADL_dressing, mi
recode headlwa (-9/-1=.), gen (ADL_walking)
tab headlwa ADL_walking, mi
recode headlba (-9/-1=.), gen (ADL_bathing)
tab headlba ADL_bathing, mi
recode headlea (-9/-1=.), gen (ADL_eating)
tab headlea ADL_eating, mi
recode headlbe (-9/-1=.), gen (ADL_outofbed)
tab headlbe ADL_outofbed, mi
recode headlwc (-9/-1=.), gen (ADL_toilet)
tab headlwc ADL_toilet, mi
recode headlma (-9/-1=.), gen (ADL_usingmap)
tab headlma ADL_usingmap, mi
recode headlpr (-9/-1=.), gen (ADL_hotmeal)
tab headlpr ADL_hotmeal, mi
recode headlsh (-9/-1=.), gen (ADL_shopping)
tab headlsh ADL_shopping, mi
recode headlte (-9/-1=.), gen (ADL_telephone)
tab headlte ADL_telephone, mi
recode headlme (-9/-1=.), gen (ADL_medication)
tab headlme ADL_medication, mi
recode headlho (-9/-1=.), gen (ADL_housework)
tab headlho ADL_housework, mi
recode headlmo (-9/-1=.), gen (ADL_money)
tab headlmo ADL_money, mi
/*general health*/
tab hehelf, mi 
label list hehelf
gen general_health=0
replace general_health=1 if hehelf==4 | hehelf==5
replace general_health=. if hehelf<0
tab hehelf general_health, mi
tab general_health, mi
/*2nd general health var*/
recode hehelf (-9/-1=.), gen(srgeneralh)
label values srgeneralh hehelf
tab hehelf srgeneralh, mi
/*depressive symptoms*/
foreach var of varlist psceda-pscedc pscede pscedg pscedh{
tab `var'
label list `var'
recode `var' (2=0) (-9/-1=.), gen (dep_`var')
tab `var' dep_`var', mi
}
foreach var of varlist pscedf pscedd{
tab `var'
label list `var'
recode `var' (2=1) (1=0) (-9/-1=.), gen(dep_`var')
tab `var' dep_`var', mi
}
/*high BP - stroke*/
foreach var of varlist HEdiagbp-Hediagst{
tab `var', mi
label list `var'
}
recode HEdiagbp (1/4=1) (-9/-1=.), gen (highBP)
tab HEdiagbp highBP, mi
recode Hediagan (1/4=1) (-9/-1=.), gen (angina)
tab Hediagan angina, mi
recode Hediagmi (1/4=1) (-9/-1=.), gen (heartattack)
tab Hediagmi heartattack, mi
recode Hediaghf (1/4=1) (-9/-1=.), gen (congestHF)
tab Hediaghf congestHF, mi
recode Hediagar (1/4=1) (-9/-1=.), gen (abnormalheart)
tab Hediagar abnormalheart, mi
recode Hediagdh (1/4=1) (-9/-1=.), gen (diabetes)
tab Hediagdh diabetes, mi
recode Hediagst (1/4=1) (-9/-1=.), gen (stroke)
tab Hediagst stroke, mi
/*chronic lung - dementia*/
foreach var of varlist HeBdiaLU-HeBdiaDE{
tab `var', mi
label list `var'
}
recode HeBdiaLU (1/4=1)  (-9/-1=.), gen (chroniclung)
tab HeBdiaLU chroniclung, mi
recode HeBdiaAS (1/4=1) (-9/-1=.), gen (asthma)
tab HeBdiaAS asthma, mi
recode HeBdiaAR (1/4=1) (-9/-1=.), gen (arthritis)
tab HeBdiaAR arthritis, mi
recode HeBdiaOS (1/4=1) (-9/-1=.), gen (osteoporosis)
tab HeBdiaOS osteoporosis, mi
recode HeBdiaCA (1/4=1) (-9/-1=.), gen (cancer)
tab HeBdiaCA cancer, mi
recode HeBdiaPD (1/4=1) (-9/-1=.), gen (parkinsons)
tab HeBdiaPD parkinsons, mi
recode HeBdiaPS (1/4=1) (-9/-1=.), gen (anyemotional)
tab HeBdiaPS anyemotional, mi
recode HeBdiaAD (1/4=1) (-9/-1=.), gen (alzheimers)
tab HeBdiaAD alzheimers, mi
recode HeBdiaDE (1/4=1) (-9/-1=.), gen (dementia)
tab HeBdiaDE dementia, mi
/*eyesight*/
tab heeye, mi
label list heeye
recode heeye (-9/-1=.) (1/3=0) (4/6=1), gen(eyesight)
tab heeye eyesight, mi
/*hearing*/
tab hehear, mi
label list hehear
recode hehear (-9/-1=.) (1/3=0) (4/5=1), gen(hearing)
tab hehear hearing, mi
/*cognitive function*/
/*date test*/
tab cfdatd, mi
label list cfdatd
recode cfdatd (-9/-1=.) (2=1) (1=0), gen(todaysdate)
tab cfdatd todaysdate, mi
/**/
tab cfdatm, mi
label list cfdatm
recode cfdatm (-9/-1=.) (2=1) (1=0), gen(month)
tab cfdatm month, mi
/**/
tab cfdaty, mi
label list cfdaty
recode cfdaty (-9/-1=.) (2=1) (1=0), gen(year)
tab cfdaty year, mi
/**/
tab cfday, mi
label list cfday
recode cfday (-9/-1=.) (2=1) (1=0), gen(dayofweek)
tab cfday dayofweek, mi
/*word recall*/
/*delay*/
tab cflisd, mi
label list cflisd
recode cflisd (-9/-1=.), gen(word_recall_delay)
tab cflisd word_recall_delay, mi
/*immediately*/
tab cflisen, mi
label list cflisen
recode cflisen (-9/-1=.), gen(word_recall_immed)
tab cflisen word_recall_immed, mi
/*rename for consistency*/
rename scfmh2 scfamh2
/*************************************/
/*unmet need score*/
/*************/
/*move round house*/
gen move_need=1 if headlwa==1
replace move_need=0 if headlwa==0
/*wash or dress*/
gen washdress_need=1 if headlba==1 | headldr==1
replace washdress_need=0 if headlba==0 | headldr==0 
/*prepare meal or eat*/
gen mealeat_need=1 if headlea==1 | headlpr==1
replace mealeat_need=0 if headlea==0 | headlpr==0
/*shopping or housework*/
gen shophous_need=1 if headlsh==1 | headlho==1
replace shophous_need=0 if headlsh==0 | headlho==0 
/*phone or money*/
gen phonemon_need=1 if headlte==1 | headlmo==1
replace phonemon_need=0 if headlte==0 | headlmo==0
/*medications*/
gen medicat_need=1 if headlme==1
replace medicat_need=0 if headlme==0
/****************************************/
/*type of care recieved*/
foreach var of varlist hehphsp - hehpm96{
tab `var', mi
label list `var'
}
/*move round house*/
gen move=1 if hehphsp==1 | hehphso==1 | hehphda==1 | hehphsi==1 | hehphbr==1 | hehphor==1 | hehphfr==1
replace move=2 if hehphla==1 | hehphnu==1
replace move=3 if hehphpp==1
replace move=4 if hehphst==1 | hehphot==1
replace move=5 if hehph96==1
replace move=0 if move_need==0 
/*wash or dress*/
gen washdress=1 if hehpwsp==1 | hehpwso==1 | hehpwda==1 | hehpwsi==1 | hehpwbr==1 | hehpwor==1 |  hehpwfr==1
replace washdress=2 if hehpwla==1 | hehpwnu==1
replace washdress=3 if hehpwpp==1
replace washdress=4 if hehpwst==1 |  hehpwot==1
replace washdress=5 if hehpw96==1
replace washdress=0 if washdress_need==0
/*prepare meal or eat*/
gen mealeat=1 if hehpdsp==1 | hehpdso==1 | hehpdda==1 | hehpdsi==1 | hehpdbr==1 | hehpdor==1 |  hehpdfr==1
replace mealeat=2 if hehpdla==1 | hehpdnu==1
replace mealeat=3 if hehpdpp==1
replace mealeat=4 if hehpdst==1 |  hehpdot==1
replace mealeat=5 if hehpd96==1
replace mealeat=0 if mealeat_need==0
/*shopping or housework*/
gen shophous=1 if hehppsp==1 | hehppso==1 | hehppda==1 | hehppsi==1 | hehppbr==1 | hehppor==1 |  hehppfr==1
replace shophous=2 if hehppla==1 | hehppnu==1
replace shophous=3 if hehpppp==1
replace shophous=4 if hehppst==1 |  hehppot==1
replace shophous=5 if hehpp96==1
replace shophous=0 if shophous_need==0
/*phone or money*/
gen phonemon=1 if hehptsp==1 | hehptso==1 | hehptda==1 | hehptsi==1 | hehptbr==1 | hehptor==1 |  hehptfr==1
replace phonemon=2 if hehptla==1 | hehptnu==1
replace phonemon=3 if hehptpp==1
replace phonemon=4 if hehptst==1 |  hehptot==1
replace phonemon=5 if hehpt96==1
replace phonemon=0 if phonemon_need==0
/*medications*/
gen medicat=1 if hehpmsp==1 | hehpmso==1 | hehpmda==1 | hehpmsi==1 | hehpmbr==1 | hehpmor==1 |  hehpmfr==1
replace medicat=2 if hehpmla==1 | hehpmnu==1
replace medicat=3 if hehpmpp==1 
replace medicat=4 if hehpmst==1 |  hehpmot==1
replace medicat=5 if hehpm96==1
replace medicat=0 if medicat_need==0
/*label the care provided*/
label define carelab 0 "no need identified" 1 "met by informal" 2 "met by state" 3 "met by private" 4 "met by other" 5 "not met"
foreach var of varlist move-medicat{
label values `var' carelab
}
/*see how many care needs, and care recieved were asked about*/
/*will use to set the flags to missign where incomplete data*/
egen adliadl_items=rownonmiss(move_need washdress_need mealeat_need shophous_need phonemon_need medicat_need)
tab adliadl_items, mi 
egen care_recieveditems=rownonmiss(move washdress mealeat shophous phonemon medicat)
tab care_recieveditems
/*gen unmet by formal flag*/
gen unmet_flag=0
gen unmet_formal=0
foreach var of varlist move-medicat{
replace unmet_flag=1 if `var'_need==1 & `var'==5
replace unmet_formal=1 if `var'_need==1 & (`var'!=2 | `var'!=3)
}
replace unmet_formal=. if adliadl_items<6 | care_recieveditems<6
replace unmet_flag=. if adliadl_items<6 | care_recieveditems<6
tab unmet_formal, mi
tab unmet_flag, mi
/********************************/
/*CASP plus control, create vars for latent psychosocial path*/
/*positively worded*/
foreach var of varlist scqolc scqole scqolg{
recode `var' (1=3) (2=2) (3=1) (4=0), gen(`var'2)
}
/*negatively worded*/
foreach var of varlist scqola scqolb scqold scqolf {
recode `var' (1=0) (2=1) (3=2) (4=3), gen(`var'2)
}
/*2 extra questions, not casp*/
/*positive*/ recode scdca (1=5) (2=4) (3=3) (4=2) (5=1) (6=0), gen(scdca2)
/*negative*/ recode scdcc (1=0) (2=1) (3=2) (4=3) (5=4) (6=5), gen(scdcc2) 

order scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2, after(scqolg)
browse scqola scqolb scqolc scqold scqole scqolf scqolg scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca scdca2 scdcc scdcc2
foreach var of varlist scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca2 scdcc2 {
replace `var'=. if `var'<0
}
/*ITEMS FOR BEHAVIOURAL FACTOR*/
/*SMOKING*/
/*ever smoked*/
tab hesmk
label list hesmk
/*currently*/ 
tab heska
label list heska
tab hesmk heska
gen smoke4=.
replace smoke4=2 if hesmk==2
replace smoke4=1 if hesmk==1 & heska==2
replace smoke4=0 if heska==1
label define smoke4 0 "current smoker" 1 "past smoker" 2 "never smoked"
label values smoke4 smoke4
tab heska smoke4, mi
tab hesmk smoke4, mi
/*EXERCISE*/
tab heactb
label list heactb
recode heactb (1=2) (2 3=1) (4=0) (-9/-1=.), gen(exercise_mod)
label define exercise_mod 2 "2 or more times per week" 1 "1 to 4 times per month" 0 "hardly ever or never" 
label values exercise_mod exercise_mod
tab heactb exercise_mod, mi
/**************************************************/
/*ACCESS ITEMS*/
/*GP and dentist - higher=better*/
label list scedgp scedde scedho scedop
recode scedgp (1=2) (2=1) (3/5=0) (-9/-1 6 =.), gen(gp_access)
recode scedde (1=2) (2=1) (3/5=0) (-9/-1 6 =.), gen(dentist_access)
recode scedho (1=2) (2=1) (3/5=0) (-9/-1 6 =.), gen(hospital_access)
recode scedop (1=2) (2=1) (3/5=0) (-9/-1 6 =.), gen(optician_access)
label define access 0  "difficult or unable" 1 "quite easy" 2 "very easy"
label values gp_access dentist_access hospital_access optician_access access
tab scedgp gp_access, mi
tab scedde dentist_access, mi
tab scedho hospital_access, mi
tab scedop optician_access, mi
/*************************************************************/
/*KEEP ONLY THE VARS I NEED*/
keep idauniq dateofinterview SIFdateofinterview ethnicity wave nssec8 nssec5 nssec3 tenure2 fqend w4edqual difjob2 sclddr2 ///
num_durables num_housing_probs housing_prob car_ownership tenure3 private_health ///
scptr scchd scfam scfrd livsppt chicontact famcontact friecontact memorg memreg ///
scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2 ///
scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2 ///
scptr scchd scfam scfrd ///
scchdg2 scchdh2 scchdi2 scfamg2 scfamh2 scfami2 scfrdg2 scfrdh2 scfrdi2 ///
scorg012 scorg022 scorg042 scorg052 scorg062 scorg072 scorg082 ///
M_walking M_sitting M_getting_up M_stairs_several M_stairs_one M_stoop M_reaching ///
M_pulling M_lifting M_picking ADL_dressing ADL_walking ADL_bathing ADL_eating ///
ADL_outofbed ADL_toilet ADL_usingmap ADL_hotmeal ADL_shopping ADL_telephone ADL_medication ///
ADL_housework ADL_money general_health dep_psceda dep_pscedb dep_pscedc dep_pscedd ///
dep_pscede dep_pscedf dep_pscedg dep_pscedh highBP angina heartattack congestHF ///
abnormalheart diabetes stroke chroniclung asthma arthritis osteoporosis cancer ///
parkinsons anyemotional alzheimers dementia eyesight hearing todaysdate month ///
year dayofweek word_recall_delay word_recall_immed ///
unmet_flag unmet_formal ///
scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca2 scdcc2 ///
smoke4 exercise_mod ///
gp_access dentist_access hospital_access optician_access transport_deprived ///
srgeneralh
save "$work\wave_4_elsa_data_v3_prepped.dta", replace

/**********************************************************************************/
/*WAVE 5*/
clear
use "$raw\wave_5_elsa_data_v4.dta"
/*interview date*/
tab iintdatm
tab iintdaty 
tostring iintdatm, force replace
tostring iintdaty, force replace
gen dateofinterview= "01/" + iintdatm + "/" + iintdaty 
gen SIFdateofinterview=date(dateofinterview, "DMY")
/*gen wave num*/
gen wave=5
/*ethnicity*/
label list fqethnr
recode fqethnr (-9/-1 = .), gen(ethnicity)
tab ethnicity fqethnr, mi
label define ethnicitylab 1 White 2 "Non-white"
label values ethnicity ethnicitylab
/*NS-SEC*/
/*8 cat*/
tab w5nssec8, mi 
describe w5nssec8
label list w5nssec8 
recode w5nssec8 (-6/-1  =.), gen(nssec8)
label values nssec8 w5nssec8
tab w5nssec8 nssec8, mi
/*5 cat*/
tab w5nssec5, mi 
describe w5nssec5
label list w5nssec5 
recode w5nssec5 (-6/-1 =.), gen(nssec5)
label values nssec5 w5nssec5
tab w5nssec5 nssec5, mi
/*3 cat*/
tab w5nssec3, mi 
describe w5nssec3
label list w5nssec3 
recode w5nssec3 (-6/-1 =.), gen(nssec3)
label values nssec3 w5nssec3
tab w5nssec3 nssec3, mi
/*************************/
/*HOUSING TENURE - coding from wave 4 and 6 reports*/
tab hotenu
label list hotenu
recode hotenu (2 3 =2) (4 5 =3) (6 =4) (-9 -8 -1 =.), gen(tenure2)
label define atenureb2 1 "Owner occupied" 2 "Buying with mortgage" 3 "Renting or rent free" 4 "Other" 
label values tenure2 atenureb2
tab hotenu tenure2, mi
/************************/
/*EDUCATION*/
tab w5edqual/*high qual*/
label list w5edqual
/*recode highest qual as in panos wealth paper*/ /*
recode w5edqual (1/3=1) (4/6=2) (7=3) (-9 -8 -3 =.), gen(edqual2)
label define edqual2lab 1 "A-level or higher" 2 "GCSE/O-level/other qualification" 3 "No qualification"
label values edqual2 edqual2lab
tab w5edqual edqual2, mi */
/*years of ed*/
tab fqend
tab fffqend
tab fqend fffqend, mi
label list fqend 
label list fffqend
gen edu_yearsof=fffqend
replace edu_yearsof=fqend if fffqend==-9 | fffqend==-8 | fffqend==-2 | fffqend==-1
tab fffqend edu_yearsof 
label values edu_yearsof fffqend
tab edu_yearsof, mi
/***************************/
/*PATERNAL OCCUPATIONAL CLASS AT 14*/
/*recode fathers occu as in panos wealth paper*/
tab difjob /*fathers occup*/
label list difjob
recode difjob (2 3 4 = 1) (5 6 = 2) (7 8 9 12 14 15 = 3) (10 11 13 1 = 4) (-9 -8 -2 -1 =.), gen(difjob2)
label define difjob2lab 1 "Managerial and professional occupations/run own business" ///
2 "Intermediate occupations" 3 "Routine occupations/casual jobs/unemployed/disabled" ///
4 "Other (incl Armed Forces and Retired)"
label values difjob2 difjob2lab
tab difjob difjob2, mis
/*****************************/
/*SUBJECTIVE SOCIAL STATUS - 10 RUNG*/
tab sclddr /*sss*/
label list sclddr
recode sclddr (5 10 =10) (15 20=20) (25 30 =30) (35 40 =40) (45 50 =50) (55 60 =60) (65 70 =70) (75 80 =80) ///
(85 90 =90) (95 100 =100) (-9/-1 =.), gen(sclddr2)
tab sclddr sclddr2, mi
/*******************************/
/*ITEMS FOR MATERIAL DEPRIVATION FACTOR*/
/*HOUSING problems*/
tab hocenh 
label list hocenh 
gen central_heat=.
replace central_heat=1 if hocenh==2
tab hocenh central_heat, mi
foreach var of varlist hopromsp-hopromco{
tab `var'
describe `var'
label list `var'
}
recode hoprosp (-9/-1=.), gen (space)
tab hoprosp space, mi
recode hoprodk (-9/-1=.), gen (dark)
tab hoprodk dark, mi
recode hoprord (-9/-1=.), gen (damp)
tab hoprord damp, mi
recode hoprowa (-9/-1=.), gen (roof)
tab hoprowa roof, mi
recode hoprocp (-9/-1=.), gen (condensation)
tab hoprocp condensation, mi
recode hoproep (-9/-1=.), gen (electrics)
tab hoproep electrics, mi
recode hoproro (-9/-1=.), gen (rot)
tab hoproro rot, mi
recode hoproin (-9/-1=.), gen (pests)
tab hoproin pests, mi
recode hoproco (-9/-1=.), gen (cold)
tab hoproco cold, mi
egen num_housing_probs=rowtotal(central_heat space-cold)
replace num_housing_probs=. if hopronz<0 & hopropo<0 & hoprord<0 & hoproro<0 ///
& hoprosn<0 & hoprosp<0 & hoprowa<0 & hoproin<0 & hoproep<0 & hoprodk<0 ///
& hoprocp<0 & hoproco<0 & hopro96<0 & hopro95<0 
tab num_housing_probs, mis
/*gen binary housing*/
gen housing_prob=.
replace housing_prob=0 if num_housing_probs>=1 & num_housing_probs!=.
replace housing_prob=1 if num_housing_probs==0
label define housing_prob 0 problems 1 "no problems"
label values housing_prob housing_prob
tab num_housing_probs housing_prob, mi
/************************************/
/*DURABLES*/
foreach var of varlist hohavtv hohavvr hohavcd hohavff hohavwm hohavwd hohavdw hohavmo hohavpc hohavdt hohavph hohavdv {
tab `var'
label list `var'
}
recode hohavtv (-9/-1=.), gen (tv)
tab hohavtv tv, mi
recode hohavvr (-9/-1=.), gen (video_rec)
tab hohavvr video_rec, mi
recode hohavcd (-9/-1=.), gen (cd_player)
tab hohavvr cd_player, mi
recode hohavff (-9/-1=.), gen (freezer)
tab hohavff freezer, mi
recode hohavwm (-9/-1=.), gen (wash_machin)
tab hohavwm wash_machin, mi
recode hohavwd (-9/-1=.), gen (tumble_dry)
tab hohavvr tumble_dry, mi
recode hohavdw (-9/-1=.), gen (dishwash)
tab hohavvr dishwash, mi
recode hohavmo (-9/-1=.), gen (microwave)
tab hohavmo microwave, mi
recode hohavpc (-9/-1=.), gen (pc)
tab hohavvr pc, mi
recode hohavdt (-9/-1=.), gen (sat_tv)
tab hohavvr sat_tv, mi
recode hohavph (-9/-1=.), gen (phone)
tab hohavvr phone, mi
recode hohavdv (-9/-1=.), gen (dvd)
tab hohavvr dvd, mi
egen count_durables=rowtotal(tv-dvd)
replace count_durables=. if hohavcd<0 & hohavdt<0 & hohavdv<0 & hohavdw<0 ///
& hohavff<0 & hohavmo<0 & hohavpc<0 & hohavph<0 & hohavtv<0 & hohavvr<0 & hohavwd<0 & hohavwm<0
tab count_durables, mis
/*gen cat var*/
recode count_durables (0 1=0) (2/4=1) (5/8=2) (9/12=3), gen(num_durables)
label define num_durables 0 "<2" 1 "2-4" 2 "5-8" 3 ">8"
label values num_durables num_durables
tab count_durables num_durables, mi
tab num_durables, mi
/********************************/
/*car, van or motorbike ownership*/
tab hoveh
label list hoveh
foreach var of varlist hocc01-hocc20{
label list `var'
}
gen car_ownership=.
replace car_ownership=0 if hoveh==0
replace car_ownership=1 if hoveh>=1
foreach var of varlist hocc01-hocc20{
replace car_ownership=1 if `var'==1 | `var'==3 | `var'==4 
}
label define car_ownership 0 "no car or van" 1 "at least 1 car, van or motorbike"
label values car_ownership car_ownership 
tab hoveh car_ownership, mi
/**************/
/*tenure binary*/
recode hotenu (1 2 3=1) (4 5 6=0) (-9 -8 -1 =.), gen(tenure3)
label define tenure3 1 "owner" 0 "other"
label values tenure3 tenure3
tab hotenu tenure3, mi
/***************************/
/*private insurance*/
tab wpphi
label list wpphi
gen private_health=.
replace private_health=0 if wpphi==3
replace private_health=1 if wpphi==1 | wpphi==2
label define private_health 0 "no private insurance" 1 "private insurance"
label values private_health private_health
tab wpphi private_health, mi
/***********************************/
/***********************************/
/*TRANSPORT*/
tab spcar, mi
label list spcar
tab sptram7
label list sptram7
recode sptram7 (-9/-1=.), gen (dont_need_to)
tab sptram7 dont_need_to, mi
tab sptraa
label list sptraa
gen transport_deprived=0
replace transport_deprived=1 if spcar==2 & (sptraa==5 | sptraa==6 & dont_need_to!=1)
replace transport_deprived=. if spcar<0 & sptraa<0 
tab transport_deprived, mi
tab spcar transport_deprived, mi
tab sptraa transport_deprived, mi
/******************************************/
/*************************************/
/*SOCIAL INTEGRATION - see Banks 2010, and Ding 2017*/
/*higher is optimal*/
/*living with spouse or partner*/ 
/*NB wording of questions is 'do you have a husband or wife with whom you live?*/
/*need to check posibly with Ding that this is the correct var to use - it doesnt use the broader term spouse but i cant see a question that does*/
tab scptr, mi
label list scptr
recode scptr (-9 -1 -2 =.) (2 = 0), gen(livsppt)
tab scptr livsppt, mi
label var livsppt "living with spouse or partner"
/*do you have children family friends*/
foreach var of varlist scchd scfam scfrd{
tab `var'
label list `var'
}
/*contact with children, family, friends (including: face to face, phone, email or write)*/
/*NB for each group taking the highest from face to face, phone or email - this is not the only way to do this - you could for example take the average across the 3 types of contact ///
/// just be aware that this is essentially an arbritrary decision that could be questioned*/
foreach var of varlist scchdg scchdh scchdi scfamg scfamh scfami scfrdg scfrdh scfrdi {
tab `var'
label list `var'
recode `var' (-9 -1 -8 -2 = .) (1 2 = 3) (3 = 2) (4 = 1) (5 6 = 0), gen(`var'2)
}
replace scchdg2=0 if scchd==2
replace scchdh2=0 if scchd==2
replace scchdi2=0 if scchd==2
egen chicontact = rowmax(scchdg2 scchdh2 scchdi2)
label var chicontact "contact with children"
replace scfamg2=0 if scfam==2
replace scfamh2=0 if scfam==2
replace scfami2=0 if scfam==2
egen famcontact = rowmax(scfamg2 scfamh2 scfami2)
label var famcontact "contact with family"
replace scfrdg2=0 if scfrd==2
replace scfrdh2=0 if scfrd==2
replace scfrdi2=0 if scfrd==2
egen friecontact = rowmax(scfrdg2 scfrdh2 scfrdi2)
label var friecontact "contact with friends"
/*low membership of organisations*/
/*NB im including 'any other group' Ding does not include but i cant see a good reason for not including*/
foreach var of varlist scorg01 scorg02 scorg04 scorg05 scorg06 scorg07 scorg08{
tab `var'
label list `var'
recode `var' (-9 -1 -8 -2 = . ), gen (`var'2)
}
egen totalorgs = rowtotal (scorg012-scorg082)
replace totalorgs=. if (scorg012==. & scorg022==. & scorg042==. & scorg052==. & scorg062==. & scorg072==. & scorg082==.)
tab totalorgs, mi
recode totalorgs (1 2 = 1) (3 4 = 2) (5 6 7 = 3), gen(memorg)
label var memorg "membership of organisations"
tab memorg, mi
/*member of religious group*/
tab scorg03
label list scorg03
recode scorg03 (-9 -1 -8 -2 = .), gen (memreg)
label var memreg "membership of religious group"
tab memreg, mi
/*total social integration score - generate this after appending all files and imputing data for each component*/
/****************************************/
/*SOCIAL SUPPORT - see Banks 2010, and Dings 2017*/
/*do you have partner, children, family, friends?*/
foreach var of varlist scptr scchd scfam scfrd{
tab `var'
label list `var'
}
/*positive relationships with children, family and friends*/
foreach var of varlist scptra scptrb scptrc scchda scchdb scchdc scfama scfamb scfamc scfrda scfrdb scfrdc {
tab `var'
label list `var'
recode `var' (-9 -1 -8 -2 = .) (1 = 3) (3 = 1) (4 = 0), gen(`var'2)
tab `var' `var'2, mi
}
/*negative relationships with children, family and friends*/
foreach var of varlist scptrd scptre scptrf scchdd scchde scchdf scfamd scfame scfamf scfrdd scfrde scfrdf {
tab `var'
label list `var'
recode `var' (-9 -1 -8 -2 = .) (1 = 0) (2 = 1) (3 = 2) (4 = 3), gen(`var'2)
tab `var' `var'2, mi
}
replace scptra2=0 if scptr==2
replace scptrb2=0 if scptr==2 
replace scptrc2=0 if scptr==2 
replace scptrd2=0 if scptr==2 
replace scptre2=0 if scptr==2 
replace scptrf2=0 if scptr==2

replace scchda2=0 if scchd==2
replace scchdb2=0 if scchd==2
replace scchdc2=0 if scchd==2
replace scchdd2=0 if scchd==2
replace scchde2=0 if scchd==2
replace scchdf2=0 if scchd==2

replace scfama2=0 if scfam==2
replace scfamb2=0 if scfam==2
replace scfamc2=0 if scfam==2
replace scfamd2=0 if scfam==2
replace scfame2=0 if scfam==2
replace scfamf2=0 if scfam==2

replace scfrda2=0 if scfrd==2
replace scfrdb2=0 if scfrd==2
replace scfrdc2=0 if scfrd==2
replace scfrdd2=0 if scfrd==2
replace scfrde2=0 if scfrd==2
replace scfrdf2=0 if scfrd==2
/*total social support score - generate this after appending all files and imputing data for each component*/
/****************************************************************/
/*
/*QUALITY OF RELATIONSIPS*/
/*do you have partner, children, family, friends?*/
foreach var of varlist scptr scchd scfam scfrd{
tab `var'
label list `var'
}
/*contact and quality of relationship with spouse/partner*/
foreach var of varlist scptra-scptrg{
tab `var'
label list `var'
}
foreach var of varlist scptra scptrb scptrc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scptrd scptre scptrf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_partner=rowtotal(scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2)
replace quality_partner=. if scptra2==. & scptrb2==. & scptrc2==. & scptrd2==. & ///
 scptre2==. & scptrf2==. 
tab quality_partner, mi
tab quality_partner scptr, mi
/*contact and quality of relationship with children*/
foreach var of varlist scchda-scchdm{
tab `var'
label list `var'
}
foreach var of varlist scchda scchdb scchdc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scchdd scchde scchdf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_children=rowtotal(scchda2 scchdb2 scchdc2 scchdd2 scchde2 scchdf2)
replace quality_children=. if scchda2==. & scchdb2==. & scchdc2==. & scchdd2==. & ///
 scchde2==. & scchdf2==. 
tab quality_children, mi
tab quality_children scchd, mi 
/*contact and quality of relationship with family*/
foreach var of varlist scfama-scfamm{
tab `var'
label list `var'
}
foreach var of varlist scfama scfamb scfamc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scfamd scfame scfamf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_family=rowtotal(scfama2 scfamb2 scfamc2 scfamd2 scfame2 scfamf2)
replace quality_family=. if scfama2==. & scfamb2==. & scfamc2==. & scfamd2==. & ///
 scfame2==. & scfamf2==. 
tab quality_family, mi
tab quality_family scfam, mi
/*contact and quality of relationship with friends*/
foreach var of varlist scfrda-scfrdm{
tab `var'
label list `var'
}
foreach var of varlist scfrda scfrdb scfrdc{
recode `var' (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
foreach var of varlist scfrdd scfrde scfrdf{
recode `var' (1=4) (2=3) (3=2) (4=1) (-9/-1 =.), gen(`var'2)
tab `var' `var'2, mi
}
egen quality_friends=rowtotal(scfrda2 scfrdb2 scfrdc2 scfrdd2 scfrde2 scfrdf2)
replace quality_friends=. if scfrda2==. & scfrdb2==. & scfrdc2==. & scfrdd2==. & ///
 scfrde2==. & scfrdf2==. 
tab quality_friends, mi
tab quality_friends scfrd, mi
/*SOCIAL ISOLATION*/
tab scptr
label list scptr
foreach var of varlist scchdi scfami scfrdi{
tab `var'
label list `var'
}
gen social_isolation=0
replace social_isolation=1 if scptr==2 & (scchdi!=1 | scfami!=1 | scfrdi!=1)
replace social_isolation=. if scptr<0 & scchdi<0 & scfami<0 & scfrdi<0
tab social_isolation, mi
*/
/************************************************/
/*HEALTH LITERACY*/
foreach var of varlist cflitb-cflite{
tab `var'
label list `var'
recode `var' (-9 -8 -1 = .) (2 = 0), gen(`var'2)
tab `var' `var'2, mis
}
egen healthlitscore=rowtotal(cflitb2 cflitc2 cflitd2 cflite2)
tab healthlitscore, mi
replace healthlitscore=. if cflitb2==. & cflitc2==. & cflitd2==. & cflite2==.
gen healthlit=.
replace healthlit=1 if healthlitscore==4
replace healthlit=2 if healthlitscore>=0 & healthlitscore<=3
label define healthlit 1 adequate 2 limited
label values healthlit healthlit
tab healthlitscore healthlit, mi
/*************************************************/
/*FRAILTY INDEX*/
/*mobility difficulties*/
foreach var of varlist hemobwa-hemobpi{
tab `var', mi
label list `var'
}
recode hemobwa (-9/-1=.), gen (M_walking)
tab hemobwa M_walking, mi
recode hemobsi (-9/-1=.), gen (M_sitting)
tab hemobsi M_sitting, mi
recode hemobch (-9/-1=.), gen (M_getting_up)
tab hemobch M_getting_up, mi
recode hemobcs (-9/-1=.), gen (M_stairs_several)
tab hemobcs M_stairs_several, mi
recode hemobcl (-9/-1=.), gen (M_stairs_one)
tab hemobcl M_stairs_one, mi
recode hemobst (-9/-1=.), gen (M_stoop)
tab hemobst M_stoop, mi
recode hemobre (-9/-1=.), gen (M_reaching)
tab hemobre M_reaching, mi
recode hemobpu (-9/-1=.), gen (M_pulling)
tab hemobpu M_pulling, mi
recode hemobli (-9/-1=.), gen (M_lifting)
tab hemobli M_lifting, mi
recode hemobpi (-9/-1=.), gen (M_picking)
tab hemobpi M_picking, mi
/*disability ADL/iADL*/
foreach var of varlist headldr-headlmo{
tab `var', mi
label list `var'
}
recode headldr (-9/-1=.), gen (ADL_dressing)
tab headldr ADL_dressing, mi
recode headlwa (-9/-1=.), gen (ADL_walking)
tab headlwa ADL_walking, mi
recode headlba (-9/-1=.), gen (ADL_bathing)
tab headlba ADL_bathing, mi
recode headlea (-9/-1=.), gen (ADL_eating)
tab headlea ADL_eating, mi
recode headlbe (-9/-1=.), gen (ADL_outofbed)
tab headlbe ADL_outofbed, mi
recode headlwc (-9/-1=.), gen (ADL_toilet)
tab headlwc ADL_toilet, mi
recode headlma (-9/-1=.), gen (ADL_usingmap)
tab headlma ADL_usingmap, mi
recode headlpr (-9/-1=.), gen (ADL_hotmeal)
tab headlpr ADL_hotmeal, mi
recode headlsh (-9/-1=.), gen (ADL_shopping)
tab headlsh ADL_shopping, mi
recode headlte (-9/-1=.), gen (ADL_telephone)
tab headlte ADL_telephone, mi
recode headlme (-9/-1=.), gen (ADL_medication)
tab headlme ADL_medication, mi
recode headlho (-9/-1=.), gen (ADL_housework)
tab headlho ADL_housework, mi
recode headlmo (-9/-1=.), gen (ADL_money)
tab headlmo ADL_money, mi
/*general health*/
tab hehelf, mi 
label list hehelf
gen general_health=0
replace general_health=1 if hehelf==4 | hehelf==5
replace general_health=. if hehelf<0
tab hehelf general_health, mi
tab general_health, mi
/*2nd general health var*/
recode hehelf (-9/-1=.), gen(srgeneralh)
label values srgeneralh hehelf
tab hehelf srgeneralh, mi
/*depressive symptoms*/
foreach var of varlist psceda-pscedc pscede pscedg pscedh{
tab `var'
label list `var'
recode `var' (2=0) (-9/-1=.), gen (dep_`var')
tab `var' dep_`var', mi
}
foreach var of varlist pscedf pscedd{
tab `var'
label list `var'
recode `var' (2=1) (1=0) (-9/-1=.), gen(dep_`var')
tab `var' dep_`var', mi
}
/*high BP - stroke*/
foreach var of varlist HEdiagbp-Hediagst{
tab `var', mi
label list `var'
}
recode HEdiagbp (1/5=1) (-9/-1=.), gen (highBP)
tab HEdiagbp highBP, mi
recode Hediagan (1/5=1) (-9/-1=.), gen (angina)
tab Hediagan angina, mi
recode Hediagmi (1/5=1) (-9/-1=.), gen (heartattack)
tab Hediagmi heartattack, mi
recode Hediaghf (1/5=1) (-9/-1=.), gen (congestHF)
tab Hediaghf congestHF, mi
recode Hediagar (1/5=1) (-9/-1=.), gen (abnormalheart)
tab Hediagar abnormalheart, mi
recode Hediagdh (1/5=1) (-9/-1=.), gen (diabetes)
tab Hediagdh diabetes, mi
recode Hediagst (1/5=1) (-9/-1=.), gen (stroke)
tab Hediagst stroke, mi
/*chronic lung - dementia*/
foreach var of varlist HeBdiaLU-HeBdiaDE{
tab `var', mi
label list `var'
}
recode HeBdiaLU (1/5=1)  (-9/-1=.), gen (chroniclung)
tab HeBdiaLU chroniclung, mi
recode HeBdiaAS (1/5=1) (-9/-1=.), gen (asthma)
tab HeBdiaAS asthma, mi
recode HeBdiaAR (1/5=1) (-9/-1=.), gen (arthritis)
tab HeBdiaAR arthritis, mi
recode HeBdiaOS (1/5=1) (-9/-1=.), gen (osteoporosis)
tab HeBdiaOS osteoporosis, mi
recode HeBdiaCA (1/5=1) (-9/-1=.), gen (cancer)
tab HeBdiaCA cancer, mi
recode HeBdiaPD (1/5=1) (-9/-1=.), gen (parkinsons)
tab HeBdiaPD parkinsons, mi
recode HeBdiaPS (1/5=1) (-9/-1=.), gen (anyemotional)
tab HeBdiaPS anyemotional, mi
recode HeBdiaAD (1/5=1) (-9/-1=.), gen (alzheimers)
tab HeBdiaAD alzheimers, mi
recode HeBdiaDE (1/5=1) (-9/-1=.), gen (dementia)
tab HeBdiaDE dementia, mi
/*eyesight*/
tab heeye, mi
label list heeye
recode heeye (-9/-1=.) (1/3=0) (4/6=1), gen(eyesight)
tab heeye eyesight, mi
/*hearing*/
tab hehear, mi
label list hehear
recode hehear (-9/-1=.) (1/3=0) (4/5=1), gen(hearing)
tab hehear hearing, mi
/*cognitive function*/
/*date test*/
tab cfdatd, mi
label list cfdatd
recode cfdatd (-9/-1=.) (2=1) (1=0), gen(todaysdate)
tab cfdatd todaysdate, mi
/**/
tab cfdatm, mi
label list cfdatm
recode cfdatm (-9/-1=.) (2=1) (1=0), gen(month)
tab cfdatm month, mi
/**/
tab cfdaty, mi
label list cfdaty
recode cfdaty (-9/-1=.) (2=1) (1=0), gen(year)
tab cfdaty year, mi
/**/
tab cfday, mi
label list cfday
recode cfday (-9/-1=.) (2=1) (1=0), gen(dayofweek)
tab cfday dayofweek, mi
/*word recall*/
/*delay*/
tab cflisd, mi
label list cflisd
recode cflisd (-9/-1=.), gen(word_recall_delay)
tab cflisd word_recall_delay, mi
/*immediately*/
tab cflisen, mi
label list cflisen
recode cflisen (-9/-1=.), gen(word_recall_immed)
tab cflisen word_recall_immed, mi
/*unmet need score*/
/*************/
/*move round house*/
gen move_need=1 if headlwa==1
replace move_need=0 if headlwa==0
/*wash or dress*/
gen washdress_need=1 if headlba==1 | headldr==1
replace washdress_need=0 if headlba==0 | headldr==0 
/*prepare meal or eat*/
gen mealeat_need=1 if headlea==1 | headlpr==1
replace mealeat_need=0 if headlea==0 | headlpr==0
/*shopping or housework*/
gen shophous_need=1 if headlsh==1 | headlho==1
replace shophous_need=0 if headlsh==0 | headlho==0 
/*phone or money*/
gen phonemon_need=1 if headlte==1 | headlmo==1
replace phonemon_need=0 if headlte==0 | headlmo==0
/*medications*/
gen medicat_need=1 if headlme==1
replace medicat_need=0 if headlme==0
/****************************************/
/*type of care recieved*/
foreach var of varlist hehphsp - hehpm96{
tab `var', mi
label list `var'
}
/*move round house*/
gen move=1 if hehphsp==1 | hehphso==1 | hehphda==1 | hehphsi==1 | hehphbr==1 | hehphor==1 | hehphfr==1
replace move=2 if hehphla==1 | hehphnu==1
replace move=3 if hehphpp==1
replace move=4 if hehphst==1 | hehphot==1
replace move=5 if hehph96==1
replace move=0 if move_need==0 
/*wash or dress*/
gen washdress=1 if hehpwsp==1 | hehpwso==1 | hehpwda==1 | hehpwsi==1 | hehpwbr==1 | hehpwor==1 |  hehpwfr==1
replace washdress=2 if hehpwla==1 | hehpwnu==1
replace washdress=3 if hehpwpp==1
replace washdress=4 if hehpwst==1 |  hehpwot==1
replace washdress=5 if hehpw96==1
replace washdress=0 if washdress_need==0
/*prepare meal or eat*/
gen mealeat=1 if hehpdsp==1 | hehpdso==1 | hehpdda==1 | hehpdsi==1 | hehpdbr==1 | hehpdor==1 |  hehpdfr==1
replace mealeat=2 if hehpdla==1 | hehpdnu==1
replace mealeat=3 if hehpdpp==1
replace mealeat=4 if hehpdst==1 |  hehpdot==1
replace mealeat=5 if hehpd96==1
replace mealeat=0 if mealeat_need==0
/*shopping or housework*/
gen shophous=1 if hehppsp==1 | hehppso==1 | hehppda==1 | hehppsi==1 | hehppbr==1 | hehppor==1 |  hehppfr==1
replace shophous=2 if hehppla==1 | hehppnu==1
replace shophous=3 if hehpppp==1
replace shophous=4 if hehppst==1 |  hehppot==1
replace shophous=5 if hehpp96==1
replace shophous=0 if shophous_need==0
/*phone or money*/
gen phonemon=1 if hehptsp==1 | hehptso==1 | hehptda==1 | hehptsi==1 | hehptbr==1 | hehptor==1 |  hehptfr==1
replace phonemon=2 if hehptla==1 | hehptnu==1
replace phonemon=3 if hehptpp==1
replace phonemon=4 if hehptst==1 |  hehptot==1
replace phonemon=5 if hehpt96==1
replace phonemon=0 if phonemon_need==0
/*medications*/
gen medicat=1 if hehpmsp==1 | hehpmso==1 | hehpmda==1 | hehpmsl==1 | hehpmbr==1 | hehpmor==1 |  hehpmfr==1
replace medicat=2 if hehpmla==1 | hehpmnu==1
replace medicat=3 if hehpmsi==1 /*nb: a difference in the var name here and for sister*/
replace medicat=4 if hehpmst==1 |  hehpmot==1
replace medicat=5 if hehpm96==1
replace medicat=0 if medicat_need==0
/*label the care provided*/
label define carelab 0 "no need identified" 1 "met by informal" 2 "met by state" 3 "met by private" 4 "met by other" 5 "not met"
foreach var of varlist move-medicat{
label values `var' carelab
}
/*see how many care needs, and care recieved were asked about*/
/*will use to set the flags to missign where incomplete data*/
egen adliadl_items=rownonmiss(move_need washdress_need mealeat_need shophous_need phonemon_need medicat_need)
tab adliadl_items, mi 
egen care_recieveditems=rownonmiss(move washdress mealeat shophous phonemon medicat)
/*gen unmet by formal flag*/
gen unmet_flag=0
gen unmet_formal=0
foreach var of varlist move-medicat{
replace unmet_flag=1 if `var'_need==1 & `var'==5
replace unmet_formal=1 if `var'_need==1 & (`var'!=2 | `var'!=3)
}
replace unmet_formal=. if adliadl_items<6 | care_recieveditems<6
replace unmet_flag=. if adliadl_items<6 | care_recieveditems<6
tab unmet_flag, mi
tab unmet_formal, mi
/**********************************************************************************/
/*CASP plus control, create vars for latent psychosocial path*/
/*positively worded*/
foreach var of varlist scqolc scqole scqolg{
recode `var' (1=3) (2=2) (3=1) (4=0), gen(`var'2)
}
/*negatively worded*/
foreach var of varlist scqola scqolb scqold scqolf {
recode `var' (1=0) (2=1) (3=2) (4=3), gen(`var'2)
}
/*2 extra questions, not casp*/
/*positive*/ recode scdca (1=5) (2=4) (3=3) (4=2) (5=1) (6=0), gen(scdca2)
/*negative*/ recode scdcc (1=0) (2=1) (3=2) (4=3) (5=4) (6=5), gen(scdcc2) 

order scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2, after(scqolg)
browse scqola scqolb scqolc scqold scqole scqolf scqolg scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca scdca2 scdcc scdcc2
foreach var of varlist scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca2 scdcc2 {
replace `var'=. if `var'<0
}
/*ITEMS FOR BEHAVIOURAL FACTOR*/
/*SMOKING*/
/*ever smoked*/
tab hesmk
label list hesmk
/*currently*/ 
tab heska
label list heska
tab hesmk heska
gen smoke5=.
replace smoke5=2 if hesmk==2
replace smoke5=1 if hesmk==1 & heska==2
replace smoke5=0 if heska==1
label define smoke5 0 "current smoker" 1 "past smoker" 2 "never smoked"
label values smoke5 smoke5
tab heska smoke5, mi
tab hesmk smoke5, mi
/*EXERCISE*/
tab heactb
label list heactb
recode heactb (1=2) (2 3=1) (4=0) (-9/-1=.), gen(exercise_mod)
label define exercise_mod 2 "2 or more times per week" 1 "1 to 4 times per month" 0 "hardly ever or never" 
label values exercise_mod exercise_mod
tab heactb exercise_mod, mi
/*********************************/
/*ACCESS ITEMS*/
/*GP and dentist - higher=better*/
label list scedgp scedde scedho scedop
recode scedgp (1=2) (2=1) (3/5=0) (-9/-1 6 =.), gen(gp_access)
recode scedde (1=2) (2=1) (3/5=0) (-9/-1 6 =.), gen(dentist_access)
recode scedho (1=2) (2=1) (3/5=0) (-9/-1 6 =.), gen(hospital_access)
recode scedop (1=2) (2=1) (3/5=0) (-9/-1 6 =.), gen(optician_access)
label define access 0  "difficult or unable" 1 "quite easy" 2 "very easy"
label values gp_access dentist_access hospital_access optician_access access
tab scedgp gp_access, mi
tab scedde dentist_access, mi
tab scedho hospital_access, mi
tab scedop optician_access, mi
/*************************************************/
/*KEEP ONLY THE VARS I NEED*/
keep idauniq dateofinterview SIFdateofinterview ethnicity wave nssec8 nssec5 nssec3 tenure2 w5edqual edu_yearsof difjob2 sclddr2 ///
num_durables num_housing_probs housing_prob car_ownership tenure3 private_health ///
scptr scchd scfam scfrd livsppt chicontact famcontact friecontact memorg memreg ///
scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2 ///
scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2 ///
scptr scchd scfam scfrd ///
scchdg2 scchdh2 scchdi2 scfamg2 scfamh2 scfami2 scfrdg2 scfrdh2 scfrdi2 ///
scorg012 scorg022 scorg042 scorg052 scorg062 scorg072 scorg082 ///
healthlitscore healthlit M_walking M_sitting M_getting_up M_stairs_several M_stairs_one M_stoop M_reaching ///
M_pulling M_lifting M_picking ADL_dressing ADL_walking ADL_bathing ADL_eating ///
ADL_outofbed ADL_toilet ADL_usingmap ADL_hotmeal ADL_shopping ADL_telephone ADL_medication ///
ADL_housework ADL_money general_health dep_psceda dep_pscedb dep_pscedc dep_pscedd ///
dep_pscede dep_pscedf dep_pscedg dep_pscedh highBP angina heartattack congestHF ///
abnormalheart diabetes stroke chroniclung asthma arthritis osteoporosis cancer ///
parkinsons anyemotional alzheimers dementia eyesight hearing todaysdate month ///
year dayofweek word_recall_delay word_recall_immed ///
unmet_flag unmet_formal ///
scqola2 scqolb2 scqolc2 scqold2 scqole2 scqolf2 scqolg2 scdca2 scdcc2 ///
smoke5 exercise_mod ///
gp_access dentist_access hospital_access optician_access transport_deprived ///
srgeneralh
save "$work\wave_5_elsa_data_v4_prepped.dta", replace
/*******************************************/
/*prep the nurse data and merge it to respective waves*/
/*wave 2*/
clear
use "$raw\wave_2_nurse_data_v2.dta"
/*fvc*/
sum htfvc, detail
label list htfvc
replace htfvc=. if htfvc==-9 | htfvc==-8 | htfvc==-1
/*grip*/
sum mmgsd1, detail
sum mmgsd2, detail
sum mmgsd3, detail
label list mmgsd1
label list mmgsd2
label list mmgsd3
replace mmgsd1=. if mmgsd1==-9 | mmgsd1==-8 | mmgsd1==-1
replace mmgsd2=. if mmgsd2==-9 | mmgsd2==-8 | mmgsd2==-1
replace mmgsd3=. if mmgsd3==-9 | mmgsd3==-8 | mmgsd3==-1
egen meangrip=rowmean(mmgsd1 mmgsd2 mmgsd3)
/*chair rise, to to 5 rises - inverse*/
sum mmrrfti, detail
label list mmrrfti
replace mmrrfti=. if mmrrfti==-9 | mmrrfti==-8 | mmrrfti==-3 | mmrrfti==-1
gen chairrise=64-mmrrfti
/*waist to hip*/
gen waist_tohip=.
/*women*/
replace waist_tohip=1 if (whval>0 & whval<0.85) & sex==2
replace waist_tohip=0 if whval>=0.85 & sex==2
/*men*/
replace waist_tohip=1 if (whval>0 & whval<0.95) & sex==1
replace waist_tohip=0 if whval>=0.95 & sex==1
label define waist_tohip 1 "not raised" 0 "raised"
label values waist_tohip waist_tohip
tab waist_tohip, mi
bys sex waist_tohip: sum whval
keep idauniq waist_tohip chairrise meangrip htfvc
sort idauniq 
save "$work\wave_2_nurse_data_v2_prepped.dta", replace
/*merge to wave 2*/
clear
use "$work\wave_2_core_data_v4_prepped.dta"
sort idauniq 
merge 1:1 idauniq using "$work\wave_2_nurse_data_v2_prepped.dta"
drop _merge
save "$work\wave_2_core_data_v4_prepped.dta", replace
/************/
/*wave 4*/
clear
use "$raw\wave_4_nurse_data.dta"
/*fvc*/
sum htfvc, detail
label list htfvc
replace htfvc=. if htfvc==-1
/*grip*/
sum mmgsd1, detail
sum mmgsd2, detail
sum mmgsd3, detail
label list mmgsd1
label list mmgsd2
label list mmgsd3
replace mmgsd1=. if mmgsd1==-9 | mmgsd1==-8 | mmgsd1==-1 | mmgsd1==99
replace mmgsd2=. if mmgsd2==-9 | mmgsd2==-8 | mmgsd2==-1 | mmgsd2==99
replace mmgsd3=. if mmgsd3==-9 | mmgsd3==-8 | mmgsd3==-1 | mmgsd3==99
egen meangrip=rowmean(mmgsd1 mmgsd2 mmgsd3)
/*chair rise, to to 5 rises - inverse*/
sum mmrrfti, detail
label list mmrrfti
replace mmrrfti=. if mmrrfti==-8 | mmrrfti==-1
gen chairrise=64-mmrrfti
/*wait to hip*/
gen waist_tohip=.
/*women*/
replace waist_tohip=1 if (whval>0 & whval<0.85) & dhsex==2
replace waist_tohip=0 if whval>=0.85 & dhsex==2
/*men*/
replace waist_tohip=1 if (whval>0 & whval<0.95) & dhsex==1
replace waist_tohip=0 if whval>=0.95 & dhsex==1
label define waist_tohip 1 "not raised" 0 "raised"
label values waist_tohip waist_tohip
tab waist_tohip, mi
bys dhsex waist_tohip: sum whval
keep idauniq waist_tohip chairrise meangrip htfvc
sort idauniq
save "$work\wave_4_nurse_data_prepped.dta", replace
/*merge to wave 4*/
clear
use "$work\wave_4_elsa_data_v3_prepped.dta"
sort idauniq 
merge 1:1 idauniq using "$work\wave_4_nurse_data_prepped.dta"
drop _merge
save "$work\wave_4_elsa_data_v3_prepped.dta", replace
/*APPEND ALL THE WAVES*/
clear
use "$work\wave_0_common_variables_v2_prepped.dta"
append using "$work\wave_1_core_data_v3_prepped.dta"
/*apply the waist to hip ratio variables to wave 1 records then drop wave 0*/
sort idauniq wave 
replace waist_tohip=waist_tohip[_n-1] if waist_tohip==. & idauniq==idauniq[_n-1] & waist_tohip[_n-1]!=.
drop if wave==0
append using "$work\wave_2_core_data_v4_prepped.dta"
append using "$work\wave_3_elsa_data_v4_prepped.dta"
append using "$work\wave_4_elsa_data_v3_prepped.dta"
append using "$work\wave_5_elsa_data_v4_prepped.dta"
/*merge the different education vars - to carry the answers forward from previous wave*/
label list fqend
label list FqEnd
label list fffqend
label list aeducend
foreach var of varlist fqend FqEnd edu_yearsof{
replace `var'=. if `var'==-9 | `var'==-8 | `var'==-2 | `var'==-1
}
replace edu_yearsof=FqEnd if edu_yearsof==.
replace edu_yearsof=fqend if edu_yearsof==.
drop FqEnd fqend
tab edu_yearsof wave, mi
/*recode education var*/
label list aeducend
replace edu_yearsof=8 if edu_yearsof==1
/*and hihgest qual*/
label list edqual
label list w3edqual
label list w4edqual
label list w5edqual
foreach var of varlist edqual w3edqual-w5edqual{
replace `var'=. if `var'==-9 | `var'==-8 | `var'==-9 | `var'==-3
}
/*nb no edqual for wave 2*/
replace edqual=w3edqual if edqual==.
replace edqual=w4edqual if edqual==.
replace edqual=w5edqual if edqual==.
drop w3edqual w4edqual w5edqual
order edqual, last
/*merge the smoke variables - to carry answers forward from previous waves*/
gen smoke=.
replace smoke=smoke1 if smoke==. & smoke1!=.
replace smoke=smoke2 if smoke==. & smoke2!=.
replace smoke=smoke3 if smoke==. & smoke3!=.
replace smoke=smoke4 if smoke==. & smoke4!=.
replace smoke=smoke5 if smoke==. & smoke5!=.
tab smoke, mi
drop smoke1 smoke2 smoke3 smoke4 smoke5
/*recode some of the items underlying the social integration var to set the -9 -8 etc to . */
foreach var of varlist scptr scchd scfam scfrd{
label list `var'
replace `var'=. if `var'==-9 | `var'==-1 | `var'==-2
tab `var', mi
} 
order idauniq dateofinterview SIFdateofinterview wave ethnicity
order edqual, last
/*CRUDE IMPUTATION*/
sort idauniq wave 
foreach var of varlist ethnicity-edqual{
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
gsort -idauniq -wave 
foreach var of varlist ethnicity-edqual{
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
/*total social integration score - generate this after appending all files and imputing data for each component*/
/*rule is if missing for any item then set missing for overall score - could relax this rule??*/
egen socintscore = rowtotal (livsppt chicontact famcontact friecontact memorg memreg)
egen socintmiss = rowmiss (livsppt chicontact famcontact friecontact memorg memreg)
replace socintscore = . if socintmiss >=1
tab socintscore, mi
/*total social support score */
egen ssscore = rowtotal (scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2)
egen ssmiss = rowmiss (scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2)
replace ssscore = . if ssmiss >=1
tab ssscore, mi
/*also gen mean score for child, fam, friend ss - for looking at domain specific relationships*/
egen ptrscore = rowtotal (scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2)
egen ptrmiss = rowmiss (scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2)
replace ptrscore =. if ptrmiss>=1
egen childscore = rowtotal (scchda2 scchdb2 scchdc2 scchdd2 scchde2 scchdf2)
egen childmiss = rowmiss (scchda2 scchdb2 scchdc2 scchdd2 scchde2 scchdf2)
replace childscore =. if childmiss>=1
egen famscore = rowtotal (scfama2 scfamb2 scfamc2 scfamd2 scfame2 scfamf2)
egen fammiss = rowmiss (scfama2 scfamb2 scfamc2 scfamd2 scfame2 scfamf2)
replace famscore =. if fammiss>=1
egen friscore = rowtotal (scfrda2 scfrdb2 scfrdc2 scfrdd2 scfrde2 scfrdf2)
egen frimiss = rowmiss (scfrda2 scfrdb2 scfrdc2 scfrdd2 scfrde2 scfrdf2)
replace friscore = . if frimiss>=1
/*SSS in to high medium low*/
recode sclddr2 (10/30=1) (40/60=2) (70/100=3), gen(sclddr2_cats)
label define sclddr2_cats 1 low 2 medium 3 high
label values sclddr2_cats sclddr2_cats
tab sclddr2 sclddr2_cats, mi 
/*recode education var to numerical*/
gen edu_yearsof2=edu_yearsof
tab edu_yearsof2
sort idauniq wave
/*recode highest qual as in panos wealth paper - into 3 cats with higher=better*/ 
label list edqual
recode edqual (1/3=3) (4 5=2) (7 6=1) (-9 -8 -1 -3 =.), gen(edqual3)
label define edqual3 3 "A-level or higher" 2 "GCSE/O-level/other" 1 "no formal/other"
label values edqual3 edqual3
tab edqual edqual3, mi 
/*recode highest qual to give 5 cats that could be treated as numerical - higher is better*/
recode edqual (7 6 =1) (5 4=2) (2=4) (1=5) (. = .), gen(edqual5)
label define edqual5 1 "no formal/other" 2 "lower secondary" 3 "higher secondary" 4 "higher ed, below degree" 5 "degree"
label values edqual5 edqual5
tab edqual edqual5, mi
/*recode edqual5 but impute missing into no qual group*/
recode edqual (7 6 .=1) (5 4=2) (2=4) (1=5) (. = .), gen(edqual5imp)
label values edqual5imp edqual5
tab edqual5imp edqual5, mi
/*recode ns-sec to 5 cats, where higher is better*/
/*NB this is the same as nssec5 but groups 'other/long term unemployed' with routine because the number of 'other' is so small*/
/*NB!! I THINK ACTUALLY LONG TERM UNEMPLOYED SHOULD BE MISSINGN NOT GROUPED WITH ROUTINE - THERE IS NO REAL JUSTIFICATION FOR THIS*/
label list nssec5lab
recode nssec5 (1 =5) (2 =4) (3 =3) (4 =2) (5 99 =1) (. =.), gen(nssec5rec)
label define nssec5rec 5 "Managerial and professional occupations" 4 "Intermediate occupations" ///
3 "Small employers and own account workers" 2 "Lower supervisory and technical occupations" 1 "Semi-routine, routine, other and unemployed" 
label values nssec5rec nssec5rec
tab nssec5 nssec5rec, mi
/*and impute missing into lowest cat*/
recode nssec5 (1 =5) (2 =4) (3 =3) (4 =2) (5 99 .=1), gen(nssec5imp)
label values nssec5imp nssec5rec
tab nssec5 nssec5imp, mi
/*recode nssec3 but impute other and missing into lower group And make higher better*/
label list nssec3lab
recode nssec3 (1 = 3) (3 = 1) (99 . =1), gen(nssec3imp)
label define nssec3imp 3 "managerial and professional" 2 "intermediate" 1 "routine and manual"
label values nssec3imp nssec3imp
tab nssec3 nssec3imp, mi
/*frailty index*/
/*create the deciles of word recall for the frailty index*/
egen word_recall_delay2=xtile(word_recall_delay), n(5) by(wave)
egen word_recall_immed2=xtile(word_recall_immed), n(5) by(wave)
replace word_recall_delay2=0 if word_recall_delay2>1 & word_recall_delay2!=.
replace word_recall_immed2=0 if word_recall_immed2>1 & word_recall_immed2!=.
tab word_recall_delay word_recall_delay2, mi
tab word_recall_immed word_recall_immed2, mi
/*gen sum score for frailty*/
egen frailty_items=rownonmiss(M_walking-dayofweek word_recall_delay2 word_recall_immed2)
egen frailty_total=rowtotal (M_walking-dayofweek word_recall_delay2 word_recall_immed2)
gen frailty_score=frailty_total/frailty_items
replace frailty_score=. if frailty_items<30 
/*gen frailty flag*/
gen frailty_flag=0
replace frailty_flag=1 if frailty_score>=0.25
/*at least 1 long-standing chronic illness*/
gen chronic=0
foreach var of varlist chroniclung-dementia{
replace chronic=1 if `var'==1
}
replace chronic=. if chroniclung==. & asthma==. & arthritis==. & osteoporosis==. ///
& cancer==. & parkinsons==. & anyemotional==.  & alzheimers==. & dementia==.
/*at least 1 of three functional limitations*/
gen functlimit=0
foreach var of varlist M_walking M_stairs_one M_lifting{
replace functlimit=1 if `var'==1
}
replace functlimit=. if M_walking==. & M_stairs_one==. & M_lifting==.
save "$work\wave_1_5_elsa_data_prepped.dta", replace
/*NB - coding issue with the items about do you have a partner, children family etc - in the later waves ////
there is a -2 category in the data but not on the label list - i suspect that this ///
/// means that they already stated they dont have a partner etc but has not been coded properly - ///
in the word doc of the items -2 = Schedule Not Applicable
NEED TO CHECK THIS WITH NATCEN*/
/*merge in the financial vars*/
clear
use "$work\wave 1 to 5 financial derived data net non pension wealth.dta"
sort idauniq wave
merge 1:1 idauniq wave using "$work\wave_1_5_elsa_data_prepped.dta"
drop _merge
/*apply crude imputation to the wealth var*/
sort idauniq wave 
foreach var of varlist nettotw_bu_s totwq10_bu_s totwq5_bu_s {
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
gsort -idauniq -wave
foreach var of varlist nettotw_bu_s totwq10_bu_s totwq5_bu_s { 
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
save "$work\wave_1_5_elsa_data_prepped incl financial.dta", replace
/*merge in the index file*/
clear 
use "$work\deceased cohort members only index and eol working prep file.dta"
sort idauniq
save "$work\deceased cohort members only index and eol working prep file.dta", replace
clear
use "$work\wave_1_5_elsa_data_prepped incl financial.dta"
sort idauniq
merge m:1 idauniq using "$work\deceased cohort members only index and eol working prep file.dta"
keep if _merge==3
/*gen 2rd, 3rd, 4th, 5th wave before death*/
gen predeath1=last_productive
bys idauniq: gen predeath2=last_productive-1
bys idauniq: gen predeath3=last_productive-2
bys idauniq: gen predeath4=last_productive-3
bys idauniq: gen predeath5=last_productive-4
foreach var of varlist predeath1-predeath5{
replace `var'=. if `var'<1
}
foreach var of varlist predeath1-predeath5{
replace `var'=. if `var'==1 & prodw1!=1
replace `var'=. if `var'==2 & prodw2!=1
replace `var'=. if `var'==3 & prodw3!=1
replace `var'=. if `var'==4 & prodw4!=1
replace `var'=. if `var'==5 & prodw5!=1
}
sort idauniq wave
gen wave_beforedeath=.
replace wave_beforedeath = 1 if predeath1==wave
replace wave_beforedeath = 2 if predeath2==wave
replace wave_beforedeath = 3 if predeath3==wave
replace wave_beforedeath = 4 if predeath4==wave
replace wave_beforedeath = 5 if predeath5==wave
/*gen cohort flags*/
gen cohort=.
replace cohort=1 if dobyear>=1916 & dobyear<=1917 | dobyear==-7
replace cohort=2 if dobyear>=1918 & dobyear<=1922
replace cohort=3 if dobyear>=1923 & dobyear<=1927
replace cohort=4 if dobyear>=1928 & dobyear<=1932
replace cohort=5 if dobyear>=1933 & dobyear<=1937
replace cohort=6 if dobyear>=1938 & dobyear<=1942
replace cohort=7 if dobyear>=1943 & dobyear<=1947
replace cohort=8 if dobyear>=1948 & dobyear<=1952
replace cohort=9 if dobyear>=1953 & dobyear<=1957
/*dobyear recode*/
gen dobyear3=dobyear
replace dobyear3=1914 if dobyear==-7 
/*gen wave year*/
gen waveyear=.
replace waveyear=2002 if wave==1
replace waveyear=2004 if wave==2
replace waveyear=2006 if wave==3
replace waveyear=2008 if wave==4
replace waveyear=2010 if wave==5
/*gen age at wave */
gen ageatwave=waveyear-dobyear3
/*gen mid age for cohort at wave x*/
gen midageatwave=.
replace midageatwave=87.5 if wave==1 & cohort==1 
replace midageatwave=82.5 if wave==1 & cohort==2
replace midageatwave=77.5 if wave==1 & cohort==3
replace midageatwave=72.5 if wave==1 & cohort==4
replace midageatwave=67.5 if wave==1 & cohort==5
replace midageatwave=62.5 if wave==1 & cohort==6
replace midageatwave=57.5 if wave==1 & cohort==7
replace midageatwave=52.5 if wave==1 & cohort==8
replace midageatwave=47.5 if wave==1 & cohort==9

replace midageatwave=89.5 if wave==2 & cohort==1 
replace midageatwave=84.5 if wave==2 & cohort==2
replace midageatwave=79.5 if wave==2 & cohort==3
replace midageatwave=74.5 if wave==2 & cohort==4
replace midageatwave=69.5 if wave==2 & cohort==5
replace midageatwave=64.5 if wave==2 & cohort==6
replace midageatwave=59.5 if wave==2 & cohort==7
replace midageatwave=54.5 if wave==2 & cohort==8
replace midageatwave=49.5 if wave==2 & cohort==9

replace midageatwave=91.5 if wave==3 & cohort==1 
replace midageatwave=86.5 if wave==3 & cohort==2
replace midageatwave=81.5 if wave==3 & cohort==3
replace midageatwave=76.5 if wave==3 & cohort==4
replace midageatwave=71.5 if wave==3 & cohort==5
replace midageatwave=66.5 if wave==3 & cohort==6
replace midageatwave=61.5 if wave==3 & cohort==7
replace midageatwave=56.5 if wave==3 & cohort==8
replace midageatwave=51.5 if wave==3 & cohort==9

replace midageatwave=93.5 if wave==4 & cohort==1 
replace midageatwave=88.5 if wave==4 & cohort==2
replace midageatwave=83.5 if wave==4 & cohort==3
replace midageatwave=78.5 if wave==4 & cohort==4
replace midageatwave=73.5 if wave==4 & cohort==5
replace midageatwave=68.5 if wave==4 & cohort==6
replace midageatwave=63.5 if wave==4 & cohort==7
replace midageatwave=58.5 if wave==4 & cohort==8
replace midageatwave=53.5 if wave==4 & cohort==9

replace midageatwave=95.5 if wave==5 & cohort==1 
replace midageatwave=90.5 if wave==5 & cohort==2
replace midageatwave=85.5 if wave==5 & cohort==3
replace midageatwave=80.5 if wave==5 & cohort==4
replace midageatwave=75.5 if wave==5 & cohort==5
replace midageatwave=70.5 if wave==5 & cohort==6
replace midageatwave=65.5 if wave==5 & cohort==7
replace midageatwave=60.5 if wave==5 & cohort==8
replace midageatwave=55.5 if wave==5 & cohort==9
/*flag members who contributed to all wave 'balanced cohort'*/
gen balanced_cohort=0
replace balanced_cohort=1 if (prodw2==1 & prodw3==1 & prodw4==1 & prodw5==1)
tab balanced_cohort, mi
/*flip wave*/
recode wave_beforedeath (1=5) (2=4) (4=2) (5=1), gen(wave_bdflipped)
label define wave_bdflipped 5 "2 years" 4 "4 years" 3 "6 years" 2 "8 years" 1 "10 years"
label values wave_bdflipped wave_bdflipped
/*create tertiles of wealth, frailty, ss and socint - based on baseline status*/
xtile frailty3_lp = frailty_score if last_productive==wave, nq(3) 
xtile frailty10_lp = frailty_score if last_productive==wave, nq(10)
xtile frailty3_fp = frailty_score if first_productive==wave & frailty_score!=., nq(3)
xtile wealth3_fp = nettotw_bu_s if first_productive==wave & nettotw_bu_s!=., nq(3)
xtile wealth10_fp = nettotw_bu_s if first_productive==wave & nettotw_bu_s!=., nq(10)
xtile ssscore3_fp = ssscore if first_productive==wave & ssscore!=., nq(3)
xtile socintscore3_fp = socintscore if first_productive==wave & socintscore!=., nq(3)
/*also frailty score at lp*/
gen frailtyscore_lp = frailty_score if last_productive==wave
/*fill down these tertile classifications so they are applied to all longitudinal records for each person - NB this is NOT like the crude imputation!*/
sort idauniq wave 
foreach var of varlist frailty3_fp wealth3_fp wealth10_fp ssscore3_fp socintscore3_fp {
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
gsort idauniq -wave 
foreach var of varlist frailty3_lp frailty10_lp frailtyscore_lp{
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}

/*save temp file to recall*/
save "$work\all deceased all waves post crude imputation for descriptives.dta", replace

/*************************************/
/*also create a pre-crude-imputed dataset for descriptive comparisons*/
/*prep the nurse data and merge it to respective waves*/
/*wave 2*/
clear
use "$raw\wave_2_nurse_data_v2.dta"
/*fvc*/
sum htfvc, detail
label list htfvc
replace htfvc=. if htfvc==-9 | htfvc==-8 | htfvc==-1
/*grip*/
sum mmgsd1, detail
sum mmgsd2, detail
sum mmgsd3, detail
label list mmgsd1
label list mmgsd2
label list mmgsd3
replace mmgsd1=. if mmgsd1==-9 | mmgsd1==-8 | mmgsd1==-1
replace mmgsd2=. if mmgsd2==-9 | mmgsd2==-8 | mmgsd2==-1
replace mmgsd3=. if mmgsd3==-9 | mmgsd3==-8 | mmgsd3==-1
egen meangrip=rowmean(mmgsd1 mmgsd2 mmgsd3)
/*chair rise, to to 5 rises - inverse*/
sum mmrrfti, detail
label list mmrrfti
replace mmrrfti=. if mmrrfti==-9 | mmrrfti==-8 | mmrrfti==-3 | mmrrfti==-1
gen chairrise=64-mmrrfti
/*waist to hip*/
gen waist_tohip=.
/*women*/
replace waist_tohip=1 if (whval>0 & whval<0.85) & sex==2
replace waist_tohip=0 if whval>=0.85 & sex==2
/*men*/
replace waist_tohip=1 if (whval>0 & whval<0.95) & sex==1
replace waist_tohip=0 if whval>=0.95 & sex==1
label define waist_tohip 1 "not raised" 0 "raised"
label values waist_tohip waist_tohip
tab waist_tohip, mi
bys sex waist_tohip: sum whval
keep idauniq waist_tohip chairrise meangrip htfvc
sort idauniq 
save "$work\wave_2_nurse_data_v2_prepped.dta", replace
/*merge to wave 2*/
clear
use "$work\wave_2_core_data_v4_prepped.dta"
sort idauniq 
merge 1:1 idauniq using "$work\wave_2_nurse_data_v2_prepped.dta"
drop _merge
save "$work\wave_2_core_data_v4_prepped.dta", replace
/************/
/*wave 4*/
clear
use "$raw\wave_4_nurse_data.dta"
/*fvc*/
sum htfvc, detail
label list htfvc
replace htfvc=. if htfvc==-1
/*grip*/
sum mmgsd1, detail
sum mmgsd2, detail
sum mmgsd3, detail
label list mmgsd1
label list mmgsd2
label list mmgsd3
replace mmgsd1=. if mmgsd1==-9 | mmgsd1==-8 | mmgsd1==-1 | mmgsd1==99
replace mmgsd2=. if mmgsd2==-9 | mmgsd2==-8 | mmgsd2==-1 | mmgsd2==99
replace mmgsd3=. if mmgsd3==-9 | mmgsd3==-8 | mmgsd3==-1 | mmgsd3==99
egen meangrip=rowmean(mmgsd1 mmgsd2 mmgsd3)
/*chair rise, to to 5 rises - inverse*/
sum mmrrfti, detail
label list mmrrfti
replace mmrrfti=. if mmrrfti==-8 | mmrrfti==-1
gen chairrise=64-mmrrfti
/*wait to hip*/
gen waist_tohip=.
/*women*/
replace waist_tohip=1 if (whval>0 & whval<0.85) & dhsex==2
replace waist_tohip=0 if whval>=0.85 & dhsex==2
/*men*/
replace waist_tohip=1 if (whval>0 & whval<0.95) & dhsex==1
replace waist_tohip=0 if whval>=0.95 & dhsex==1
label define waist_tohip 1 "not raised" 0 "raised"
label values waist_tohip waist_tohip
tab waist_tohip, mi
bys dhsex waist_tohip: sum whval
keep idauniq waist_tohip chairrise meangrip htfvc
sort idauniq
save "$work\wave_4_nurse_data_prepped.dta", replace
/*merge to wave 4*/
clear
use "$work\wave_4_elsa_data_v3_prepped.dta"
sort idauniq 
merge 1:1 idauniq using "$work\wave_4_nurse_data_prepped.dta"
drop _merge
save "$work\wave_4_elsa_data_v3_prepped.dta", replace
/******************************************************************/
/*APPEND ALL THE WAVES*/
clear
use "$work\wave_1_core_data_v3_prepped.dta"
append using "$work\wave_2_core_data_v4_prepped.dta"
append using "$work\wave_3_elsa_data_v4_prepped.dta"
append using "$work\wave_4_elsa_data_v3_prepped.dta"
append using "$work\wave_5_elsa_data_v4_prepped.dta"
/*merge the different education vars*/
label list fqend
label list FqEnd
label list fffqend
label list aeducend
foreach var of varlist fqend FqEnd edu_yearsof{
replace `var'=. if `var'==-9 | `var'==-8 | `var'==-2 | `var'==-1
}
replace edu_yearsof=FqEnd if edu_yearsof==.
replace edu_yearsof=fqend if edu_yearsof==.
drop FqEnd fqend
tab edu_yearsof wave, mi
/*recode education var*/
label list aeducend
replace edu_yearsof=8 if edu_yearsof==1
/*and hihgest qual*/
label list edqual
label list w3edqual
label list w4edqual
label list w5edqual
foreach var of varlist edqual w3edqual-w5edqual{
replace `var'=. if `var'==-9 | `var'==-8 | `var'==-9 | `var'==-3
}
replace edqual=w3edqual if edqual==.
replace edqual=w4edqual if edqual==.
replace edqual=w5edqual if edqual==.
drop w3edqual w4edqual w5edqual
order edqual, last
/*merge the smoke variables - to carry answers forward from previous waves*/
gen smoke=.
replace smoke=smoke1 if smoke==. & smoke1!=.
replace smoke=smoke2 if smoke==. & smoke2!=.
replace smoke=smoke3 if smoke==. & smoke3!=.
replace smoke=smoke4 if smoke==. & smoke4!=.
replace smoke=smoke5 if smoke==. & smoke5!=.
tab smoke, mi
drop smoke1 smoke2 smoke3 smoke4 smoke5
/*recode some of the items that make up the socint vars so -8 -9 etc are .*/
foreach var of varlist scptr scchd scfam scfrd{
label list `var'
replace `var'=. if `var'==-9 | `var'==-1 | `var'==-2
tab `var', mi
} 
/*total social integration score - generate this after appending all files and imputing data for each component*/
/*rule is if missing for any item then set missing for overall score - could relax this rule??*/
egen socintscore = rowtotal (livsppt chicontact famcontact friecontact memorg memreg)
egen socintmiss = rowmiss (livsppt chicontact famcontact friecontact memorg memreg)
replace socintscore = . if socintmiss >=1
tab socintscore, mi
/*total social support score */
egen ssscore = rowtotal (scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2)
egen ssmiss = rowmiss (scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2)
replace ssscore = . if ssmiss >=1
tab ssscore, mi
/*also gen mean score for child, fam, friend ss - for looking at domain specific relationships*/
egen ptrscore = rowtotal (scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2)
egen ptrmiss = rowmiss (scptra2 scptrb2 scptrc2 scptrd2 scptre2 scptrf2)
replace ptrscore =. if ptrmiss>=1
egen childscore = rowtotal (scchda2 scchdb2 scchdc2 scchdd2 scchde2 scchdf2)
egen childmiss = rowmiss (scchda2 scchdb2 scchdc2 scchdd2 scchde2 scchdf2)
replace childscore =. if childmiss>=1
egen famscore = rowtotal (scfama2 scfamb2 scfamc2 scfamd2 scfame2 scfamf2)
egen fammiss = rowmiss (scfama2 scfamb2 scfamc2 scfamd2 scfame2 scfamf2)
replace famscore =. if fammiss>=1
egen friscore = rowtotal (scfrda2 scfrdb2 scfrdc2 scfrdd2 scfrde2 scfrdf2)
egen frimiss = rowmiss (scfrda2 scfrdb2 scfrdc2 scfrdd2 scfrde2 scfrdf2)
replace friscore = . if frimiss>=1
/*SSS in to high medium low*/
recode sclddr2 (10/30=1) (40/60=2) (70/100=3), gen(sclddr2_cats)
label define sclddr2_cats 1 low 2 medium 3 high
label values sclddr2_cats sclddr2_cats
tab sclddr2 sclddr2_cats, mi 
/*recode education var to numerical*/
gen edu_yearsof2=edu_yearsof
tab edu_yearsof2
sort idauniq wave
/*recode highest qual as in panos wealth paper - into 3 cats with higher=better*/ 
label list edqual
recode edqual (1/3=3) (4 5=2) (7 6=1) (-9 -8 -1 -3 =.), gen(edqual3)
label define edqual3 3 "A-level or higher" 2 "GCSE/O-level/other" 1 "no formal/other"
label values edqual3 edqual3
tab edqual edqual3, mi 
/*recode highest qual to give 5 cats that could be treated as numerical - higher is better*/
recode edqual (7 6 =1) (5 4=2) (2=4) (1=5) (. = .), gen(edqual5)
label define edqual5 1 "no formal" 2 "lower secondary" 3 "higher secondary" 4 "higher ed, below degree" 5 "degree"
label values edqual5 edqual5
tab edqual edqual5, mi
/*recode edqual5 but impute missing into no qual group*/
recode edqual (7 6 .=1) (5 4=2) (2=4) (1=5) (. = .), gen(edqual5imp)
label values edqual5imp edqual5
tab edqual5imp edqual5, mi
/*recode ns-sec to 5 cats, where higher is better*/
/*NB this is the same as nssec5 but groups 'other/long term unemployed' with routine because the number of 'other' is so small*/
label list nssec5lab
recode nssec5 (1 =5) (2 =4) (3 =3) (4 =2) (5 99 =1) (. =.), gen(nssec5rec)
label define nssec5rec 5 "Managerial and professional occupations" 4 "Intermediate occupations" ///
3 "Small employers and own account workers" 2 "Lower supervisory and technical occupations" 1 "Semi-routine, routine, other and unemployed" 
label values nssec5rec nssec5rec
tab nssec5 nssec5rec, mi
/*and impute missing into lowest cat*/
recode nssec5 (1 =5) (2 =4) (3 =3) (4 =2) (5 99 .=1), gen(nssec5imp)
label values nssec5imp nssec5rec
tab nssec5 nssec5imp, mi
/*recode nssec3 but impute other and missing into lower group And make higher better*/
label list nssec3lab
recode nssec3 (1 = 3) (3 = 1) (99 . =1), gen(nssec3imp)
label define nssec3imp 3 "managerial and professional" 2 "intermediate" 1 "routine and manual"
label values nssec3imp nssec3imp
tab nssec3 nssec3imp, mi
/*frailty index*/
/*create the deciles of word recall for the frailty index*/
/*may need ssc install egenmore*/
egen word_recall_delay2=xtile(word_recall_delay), n(5) by(wave)
egen word_recall_immed2=xtile(word_recall_immed), n(5) by(wave)
replace word_recall_delay2=0 if word_recall_delay2>1 & word_recall_delay2!=.
replace word_recall_immed2=0 if word_recall_immed2>1 & word_recall_immed2!=.
tab word_recall_delay word_recall_delay2, mi
tab word_recall_immed word_recall_immed2, mi
/*gen sum score for frailty*/
egen frailty_items=rownonmiss(M_walking-dayofweek word_recall_delay2 word_recall_immed2)
egen frailty_total=rowtotal (M_walking-dayofweek word_recall_delay2 word_recall_immed2)
gen frailty_score=frailty_total/frailty_items
replace frailty_score=. if frailty_items<=30 
/*gen frailty flag*/
gen frailty_flag=0
replace frailty_flag=1 if frailty_score>=0.25
sort idauniq wave
/*at least 1 long-standing chronic illness*/
gen chronic=0
foreach var of varlist chroniclung-dementia{
replace chronic=1 if `var'==1
}
replace chronic=. if chroniclung==. & asthma==. & arthritis==. & osteoporosis==. ///
& cancer==. & parkinsons==. & anyemotional==.  & alzheimers==. & dementia==.
/*at least 1 of three functional limitations*/
gen functlimit=0
foreach var of varlist M_walking M_stairs_one M_lifting{
replace functlimit=1 if `var'==1
}
replace functlimit=. if M_walking==. & M_stairs_one==. & M_lifting==.
save "$work\wave 1 to 5 pre imputation.dta", replace
/***************************************/
/*merge in the financial vars*/
clear
use "$work\wave 1 to 5 financial derived data net non pension wealth.dta"
sort idauniq wave
merge 1:1 idauniq wave using "$work\wave 1 to 5 pre imputation.dta"
drop _merge
save "$work\wave 1 to 5 pre imputation.dta", replace
/**************************************/
/*merge in the index file*/
clear 
use "$work\deceased cohort members only index and eol working prep file.dta"
sort idauniq
save "$work\deceased cohort members only index and eol working prep file.dta", replace
clear
use "$work\wave 1 to 5 pre imputation.dta"
sort idauniq
merge m:1 idauniq using "$work\deceased cohort members only index and eol working prep file.dta"
keep if _merge==3
/*gen 2rd, 3rd, 4th, 5th wave before death*/
gen predeath1=last_productive
bys idauniq: gen predeath2=last_productive-1
bys idauniq: gen predeath3=last_productive-2
bys idauniq: gen predeath4=last_productive-3
bys idauniq: gen predeath5=last_productive-4
foreach var of varlist predeath1-predeath5{
replace `var'=. if `var'<1
}
foreach var of varlist predeath1-predeath5{
replace `var'=. if `var'==1 & prodw1!=1
replace `var'=. if `var'==2 & prodw2!=1
replace `var'=. if `var'==3 & prodw3!=1
replace `var'=. if `var'==4 & prodw4!=1
replace `var'=. if `var'==5 & prodw5!=1
}
sort idauniq wave
gen wave_beforedeath=.
replace wave_beforedeath = 1 if predeath1==wave
replace wave_beforedeath = 2 if predeath2==wave
replace wave_beforedeath = 3 if predeath3==wave
replace wave_beforedeath = 4 if predeath4==wave
replace wave_beforedeath = 5 if predeath5==wave
/*gen cohort flags*/
gen cohort=.
replace cohort=1 if dobyear>=1916 & dobyear<=1917 | dobyear==-7
replace cohort=2 if dobyear>=1918 & dobyear<=1922
replace cohort=3 if dobyear>=1923 & dobyear<=1927
replace cohort=4 if dobyear>=1928 & dobyear<=1932
replace cohort=5 if dobyear>=1933 & dobyear<=1937
replace cohort=6 if dobyear>=1938 & dobyear<=1942
replace cohort=7 if dobyear>=1943 & dobyear<=1947
replace cohort=8 if dobyear>=1948 & dobyear<=1952
replace cohort=9 if dobyear>=1953 & dobyear<=1957
/*dobyear recode*/
gen dobyear3=dobyear
replace dobyear3=1914 if dobyear==-7 
/*gen wave year*/
gen waveyear=.
replace waveyear=2002 if wave==1
replace waveyear=2004 if wave==2
replace waveyear=2006 if wave==3
replace waveyear=2008 if wave==4
replace waveyear=2010 if wave==5
/*gen age at wave */
gen ageatwave=waveyear-dobyear3
/*gen mid age for cohort at wave x*/
gen midageatwave=.
replace midageatwave=87.5 if wave==1 & cohort==1 
replace midageatwave=82.5 if wave==1 & cohort==2
replace midageatwave=77.5 if wave==1 & cohort==3
replace midageatwave=72.5 if wave==1 & cohort==4
replace midageatwave=67.5 if wave==1 & cohort==5
replace midageatwave=62.5 if wave==1 & cohort==6
replace midageatwave=57.5 if wave==1 & cohort==7
replace midageatwave=52.5 if wave==1 & cohort==8
replace midageatwave=47.5 if wave==1 & cohort==9

replace midageatwave=89.5 if wave==2 & cohort==1 
replace midageatwave=84.5 if wave==2 & cohort==2
replace midageatwave=79.5 if wave==2 & cohort==3
replace midageatwave=74.5 if wave==2 & cohort==4
replace midageatwave=69.5 if wave==2 & cohort==5
replace midageatwave=64.5 if wave==2 & cohort==6
replace midageatwave=59.5 if wave==2 & cohort==7
replace midageatwave=54.5 if wave==2 & cohort==8
replace midageatwave=49.5 if wave==2 & cohort==9

replace midageatwave=91.5 if wave==3 & cohort==1 
replace midageatwave=86.5 if wave==3 & cohort==2
replace midageatwave=81.5 if wave==3 & cohort==3
replace midageatwave=76.5 if wave==3 & cohort==4
replace midageatwave=71.5 if wave==3 & cohort==5
replace midageatwave=66.5 if wave==3 & cohort==6
replace midageatwave=61.5 if wave==3 & cohort==7
replace midageatwave=56.5 if wave==3 & cohort==8
replace midageatwave=51.5 if wave==3 & cohort==9

replace midageatwave=93.5 if wave==4 & cohort==1 
replace midageatwave=88.5 if wave==4 & cohort==2
replace midageatwave=83.5 if wave==4 & cohort==3
replace midageatwave=78.5 if wave==4 & cohort==4
replace midageatwave=73.5 if wave==4 & cohort==5
replace midageatwave=68.5 if wave==4 & cohort==6
replace midageatwave=63.5 if wave==4 & cohort==7
replace midageatwave=58.5 if wave==4 & cohort==8
replace midageatwave=53.5 if wave==4 & cohort==9

replace midageatwave=95.5 if wave==5 & cohort==1 
replace midageatwave=90.5 if wave==5 & cohort==2
replace midageatwave=85.5 if wave==5 & cohort==3
replace midageatwave=80.5 if wave==5 & cohort==4
replace midageatwave=75.5 if wave==5 & cohort==5
replace midageatwave=70.5 if wave==5 & cohort==6
replace midageatwave=65.5 if wave==5 & cohort==7
replace midageatwave=60.5 if wave==5 & cohort==8
replace midageatwave=55.5 if wave==5 & cohort==9
/*flag members who contributed to all wave 'balanced cohort'*/
gen balanced_cohort=0
replace balanced_cohort=1 if (prodw2==1 & prodw3==1 & prodw4==1 & prodw5==1)
tab balanced_cohort, mi
/*create tertiles of wealth, frailty, ss and socint - based on baseline status*/
xtile frailty3_fp = frailty_score if first_productive==wave & frailty_score!=., nq(3)
xtile wealth3_fp = nettotw_bu_s if first_productive==wave & nettotw_bu_s!=., nq(3)
xtile ssscore3_fp = ssscore if first_productive==wave & ssscore!=., nq(3)
xtile socintscore3_fp = socintscore if first_productive==wave & socintscore!=., nq(3)
/*fill down these tertile classifications so they are applied to all longitudinal records for each person - NB this is NOT like the crude imputation!*/
sort idauniq wave 
foreach var of varlist frailty3_fp wealth3_fp ssscore3_fp socintscore3_fp {
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
/*save temp file to recall*/
save "$work\all deceased all waves PRE imputation for descriptives.dta", replace

/*******************************************************************************************************/
/*WITHIN WAVE MULTIPLE IMPUTATION ON SS AND SOCINT VARS*/
/*on eol cohort only*/
/*useful guidance : https://www.ssc.wisc.edu/sscc/pubs/stata_mi_impute.htm*/
/*CARRY OUT MI SEPERATELY FOR EACH WAVE BEFORE DEATH - using a wide structure to mi longitudinal data using cases as clusters doesnt work because the data is so unbalance - too much missing the further you get from death also issues with convergence*/
/*effectively with the crude imputation we have already taken the longitudinal data into consideration so i think this approach is sound BUT will need to check with stat*/
/*crude imputation seems justified based on the fact that the vars dont change longitudinally (excluding wealth and frailty) and no diff between pre and post crude sensitivity analysis*/
/*NB the default is to include variables on both side of the equation in each imputation - so we can mi frailty and wealth alongside the socint and ss vars - how clever*/

/*THIS WORKS*
mi impute chained (regress)nettotw_bu_s (regress) frailty_score (logit) livsppt (ologit) chicontact  ///
(ologit) famcontact (ologit) friecontact (ologit) memorg (logit) memreg  = sex ageatdeath, add(5) by(wave_beforedeath) rseed(88) burnin(100) augment

and this works..
mi impute chained (pmm)nettotw_bu_s (pmm) frailty_score (pmm) childscore (pmm) famscore (pmm) friscore ///
= sex ageatdeath, add(2) by(wave_beforedeath) rseed(88) burnin(100)

BUT when i put the models together they dont converge on wave 5! annoying but can omit some vars...

mi impute chained (pmm)nettotw_bu_s frailty_score (mlogit) edqual2 ///
(logit) livsppt (ologit, omit childscore famscore friscore) chicontact  famcontact friecontact memorg (logit) memreg  ///
(pmm, omit(i.livsppt i.chicontact i.famcontact i.friecontact i.memorg i.memreg)) childscore famscore friscore ///
= sex ageatdeath, add(2) by(wave_beforedeath) rseed(88) burnin(100) augment


mi impute chained (pmm)nettotw_bu_s frailty_score (mlogit) edqual2 ///
(logit, omit(childscore famscore friscore)) livsppt memreg (ologit, omit(childscore famscore friscore)) chicontact famcontact friecontact memorg  ///
(pmm) childscore famscore friscore ///
= sex ageatdeath, add(2) by(wave_beforedeath) rseed(88) burnin(100) augment

*/


/***********************************************************************************************************/
clear
use "$work\all deceased all waves post crude imputation for descriptives.dta"
keep if eol_flag==1
/*describe the vars to be imputed*/
misstable summ livsppt chicontact famcontact friecontact memorg memreg ///
nettotw_bu_s frailty_score ///
childscore famscore friscore, gen(miss_)
/*test missingness*/
logit miss_livsppt sex ageatdeath nettotw_bu_s frailty_score edqual2 wave_beforedeath
logit miss_chicontact sex ageatdeath nettotw_bu_s frailty_score edqual2 wave_beforedeath
logit miss_famcontact sex ageatdeath nettotw_bu_s frailty_score edqual2 wave_beforedeath
logit miss_friecontact sex ageatdeath nettotw_bu_s frailty_score edqual2 wave_beforedeath
logit miss_memorg sex ageatdeath nettotw_bu_s frailty_score edqual2 wave_beforedeath
logit miss_memreg sex ageatdeath nettotw_bu_s frailty_score edqual2 wave_beforedeath

/*STEP 1 - MI SET THE DATA - HAVE MESSED AROUND WITH THIS BUT STILL NEEDS REFINING RE WHICH VARS ARE BEING MI ETC*/
mi set wide
mi register imputed livsppt chicontact famcontact friecontact memorg memreg ///
	nettotw_bu_s frailty_score edqual2 ///
	childscore famscore friscore
mi register regular sex ageatdeath 
/*STEP 2 - DRYRUN THE MODEL*/
mi impute chained (regress)nettotw_bu_s (regress) frailty_score (mlogit) edqual2 (logit) livsppt (ologit) chicontact  (ologit) famcontact (ologit) friecontact (ologit) memorg (logit) memreg  ///
(regress) childscore famscore friscore ///
= sex ageatdeath, dryrun
/*STEP 3 - TEST EACH MODEL SEPERATELY */
/*checking for upper and lower bounds for the continuous vars*/
regress frailty_score i.edqual2 nettotw_bu_s i.livsppt i.famcontact i.friecontact ///
                     i.chicontact i.memorg i.memreg sex ageatdeath
rvfplot
graph export livsppt.png, replace
predict ests
predict resids, res
gen y=-ests
scatter resids ests || line y ests, legend(order(2 "Exp>=0 Constraint"))
graph export livsppt.png, replace
drop resids ests y
/*checking for upper and lower bounds for the continuous vars*/
regress nettotw_bu_s i.edqual2 frailty_score i.livsppt i.famcontact i.friecontact ///
                     i.chicontact i.memorg i.memreg sex ageatdeath
rvfplot
graph export livsppt.png, replace
predict ests
predict resids, res
gen y=-ests
scatter resids ests || line y ests, legend(order(2 "Exp>=0 Constraint"))
graph export livsppt.png, replace
drop resids ests y
/*checking for upper and lower bounds for the continuous vars*/
regress childscore i.edqual2 frailty_score sex ageatdeath
rvfplot
graph export childscore.png, replace
predict ests
predict resids, res
gen y=-ests
scatter resids ests || line y ests, legend(order(2 "Exp>=0 Constraint"))
graph export childscore.png, replace
drop resids ests y
/*checking for upper and lower bounds for the continuous vars*/
regress famscore i.edqual2 frailty_score sex ageatdeath
rvfplot
graph export famscore.png, replace
predict ests
predict resids, res
gen y=-ests
scatter resids ests || line y ests, legend(order(2 "Exp>=0 Constraint"))
graph export famscore.png, replace
drop resids ests y
/*checking for upper and lower bounds for the continuous vars*/
regress friscore i.edqual2 frailty_score sex ageatdeath
rvfplot
graph export friscore.png, replace
predict ests
predict resids, res
gen y=-ests
scatter resids ests || line y ests, legend(order(2 "Exp>=0 Constraint"))
graph export friscore.png, replace
drop resids ests y
//**STEP 4 - REFINE MODELS - AND RETEST for convergence and misspecification*/
//*work with the wave 1 before death only - look at each wave seperately (but if ok for wave 1 with most missing, then prob ok for others) - mainly because savetrace wont work with the by wave option specified*/
// refine models after reviewing results
// test convergence of imputation process
// since by() and savetrace() don't get along right now, we'll remove by() then throw away these imputations and do them with by() but no savetrace().
/*THIS ONLY RELEVENT FOR NUMERICAL VARS - HOW DO WE CHECK FOR CAT VARS?? - ask stat, keep this code as reminder to check*/
/*
preserve
keep if wave_beforedeath==1
mi impute chained (pmm)nettotw_bu_s (pmm) frailty_score (logit) livsppt (ologit) chicontact  (ologit) famcontact (ologit) friecontact (ologit) memorg (logit) memreg  = sex ageatdeath, add(5) savetrace(extrace, replace) rseed(88) burnin(100) augment
/*ERROR MSG ABOUT MEDIAN VC INVALID NAME - NOT SURE WHAT THIS IS ABOUT*/
use extrace, replace
reshape wide *mean *sd, i(iter) j(m)
tsset iter
/*socintscore*/
tsline socintscore_mean*, title("Mean of Imputed Values of socintscore") note("Each line is for one imputation") legend(off)
graph export conv1.png, replace
tsline socintscore_sd*, title("Standard Deviation of Imputed Values of socintscore") note("Each line is for one imputation") legend(off)
graph export conv2.png, replace
/*ssscore*/
tsline ssscore_mean*, title("Mean of Imputed Values of ssscore") note("Each line is for one imputation") legend(off)
graph export conv1.png, replace
tsline ssscore_sd*, title("Standard Deviation of Imputed Values of ssscore") note("Each line is for one imputation") legend(off)
graph export conv2.png, replace
restore*/
//**STEP 5: CARRY OUT THE REAL IMPUTATION**//
// "real" imputation
/*NB - WHEN I DO THIS FOR REAL - SET THE add() to 20 not 5 - to reflect the proportion of missing data**/
mi impute chained (pmm)nettotw_bu_s frailty_score (mlogit) edqual2 ///
(logit, omit(childscore famscore friscore)) livsppt memreg (ologit, omit(childscore famscore friscore)) chicontact famcontact friecontact memorg  ///
(pmm) childscore famscore friscore ///
= sex ageatdeath, add(20) by(wave_beforedeath) rseed(88) burnin(100) augment
//*POST IMPUTATION - check if imputed values match observed values*/
/*NEED TO CHECK WHAT IT IS THAT IM LOOKING FOR HERE - BUT I THINK IM CHECKING THAT THAT K-DENSITY PLOT IS ROUGHLY NORMAL*/
/*
foreach var of varlist socintscore ssscore {
	mi xeq 0: sum `var'
	mi xeq 1/5: sum `var' if miss_`var'
	mi xeq 0: kdensity `var'; graph export chk`var'0.png, replace
	forval i=1/5 {
		mi xeq `i': kdensity `var' if miss_`var'; graph export chk`var'`i'.png, replace
	}
}
*/

/*create new passive vars*/
mi passive: egen socintscoreimp = rowtotal(livsppt chicontact famcontact friecontact memorg memreg)
mi passive: egen ssscoreimp = rowtotal(childscore famscore friscore)
/*passive tertiles*/
drop frailty3_fp wealth3_fp ssscore3_fp socintscore3_fp 
mi passive: egen frailty3_implp = cut(frailty_score) if last_productive==wave, group(3) 
mi passive: egen wealth3_impfp = cut(nettotw_bu_s) if first_productive==wave, group(3)
mi passive: egen wealth10_impfp = cut(nettotw_bu_s) if first_productive==wave, group(10) 
mi passive: egen ssscore3_impfp = cut(ssscoreimp) if first_productive==wave, group(3) 
mi passive: egen socintscore3_impfp = cut(socintscoreimp) if first_productive==wave, group(3) 
/*also frailty score at lp*/
mi passive: gen frailtyscore_lp = frailty_score if last_productive==wave
/*fill down these tertile classifications so they are applied to all longitudinal records for each person - NB this is NOT like the crude imputation!*/
sort idauniq wave 
foreach var of varlist *wealth3_impfp *wealth10_impfp *ssscore3_impfp *socintscore3_impfp {
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}
gsort idauniq -wave 
foreach var of varlist *frailty3_implp *frailtyscore_lp{
replace `var'=`var'[_n-1] if `var'==. & idauniq==idauniq[_n-1] & `var'[_n-1]!=.
}


/*flip wave*/
recode wave_beforedeath (1=5) (2=4) (4=2) (5=1), gen(wave_bdflipped)
label define wave_bdflipped 5 "2 years" 4 "4 years" 3 "6 years" 2 "8 years" 1 "10 years"
label values wave_bdflipped wave_bdflipped

save "$work\eol cohort only all waves POST MULTIPLE IMPUTATION for descriptives.dta", replace
/**************************************************************************************************************/

/*DESCRIPTIVES of linear associations between vars - ON MI DATA*/
/*SSSCORE*/
/*mi estimate*/
clear
use "$work\all deceased all waves POST MULTIPLE IMPUTATION for descriptives.dta"
mi estimate: regress ssscore ageatdeath frailty_score nettotw_bu_s
/*sex*/
mi estimate, saving(sssmale, replace): regress ssscore ageatdeath if sex==1
mi predict male if sex==1 using sssmale
mi estimate, saving(sssfemale, replace): regress ssscore ageatdeath if sex==2
mi predict female if sex==2 using sssfemale
line male female ageatdeath, lpattern(dash solid) title("social support by age and sex") ///
ytitle(predicted social support score) xtitle(age at last wave) legend(order(2 "female" 1 "male") col(1) ring(0) pos(4)) sort
/*wealth*/
mi estimate, saving(one, replace): regress ssscore ageatdeath if wealth3==1
mi predict poorest if wealth3==1 using one
mi estimate, saving(two, replace): regress ssscore ageatdeath if wealth3==2
mi predict middle if wealth3==2 using two
mi estimate, saving(three, replace): regress ssscore ageatdeath if wealth3==3
mi predict richest if wealth3==3 using three
line poorest middle richest ageatdeath, lpattern(dash solid shortdash) title("social support by age and wealth tertiles") ///
ytitle(predicted social support score) xtitle(age at last wave) legend(order(1 "poorest" 2 "middle" 3 "richest") col(1) ring(0) pos(4)) sort
/*frailty*/
mi estimate, saving(one, replace): regress ssscore ageatdeath if frailty3==1
mi predict least_frail if frailty3==1 using one
mi estimate, saving(one, replace): regress ssscore ageatdeath if frailty3==2
mi predict mid_frail if frailty3==2 using two
mi estimate, saving(one, replace): regress ssscore ageatdeath if frailty3==3
mi predict most_frail if frailty3==3 using three
line least_frail mid_frail most_frail ageatdeath, lpattern(dash solid shortdash) title("social support by age and frailty tertiles") ///
ytitle(predicted social support score) xtitle(age at last wave) legend(order(1 "least frail" 2 "middle" 3 "most frail") col(1) ring(0) pos(4)) sort
/*SOCINTSCORE*/
clear
use "$work\all deceased all waves POST MULTIPLE IMPUTATION for descriptives.dta"
mi estimate: regress socintscore ageatdeath frailty_score nettotw_bu_s
/*sex*/
mi estimate, saving(one, replace): regress socintscore ageatdeath if sex==1
mi predict male if sex==1 using one
mi estimate, saving(two, replace): regress socintscore ageatdeath if sex==2
mi predict female if sex==2 using two
line male female ageatdeath, lpattern(dash solid) title("social integration by age and sex") ///
ytitle(predicted social integration score) xtitle(age at last wave) legend(order(2 "female" 1 "male") col(1) ring(0) pos(1)) sort
/*wealth*/
mi estimate, saving(one, replace): regress socintscore ageatdeath if wealth3==1
mi predict poorest if wealth3==1 using one
mi estimate, saving(two, replace): regress socintscore ageatdeath if wealth3==2
mi predict middle if wealth3==2 using two
mi estimate, saving(three, replace): regress socintscore ageatdeath if wealth3==3
mi predict richest if wealth3==3 using three
line poorest middle richest ageatdeath, lpattern(dash solid shortdash) title("social integration by age and wealth tertiles") ///
ytitle(predicted social integration score) xtitle(age at last wave) legend(order(1 "poorest" 2 "middle" 3 "richest") col(1) ring(0) pos(1)) sort
/*frailty*/
mi estimate, saving(one, replace): regress socintscore ageatdeath if frailty3==1
mi predict least_frail if frailty3==1 using one
mi estimate, saving(two, replace): regress socintscore ageatdeath if frailty3==2
mi predict mid_frail if frailty3==2 using two
mi estimate, saving(three, replace): regress socintscore ageatdeath if frailty3==3
mi predict most_frail if frailty3==3 using three
line least_frail mid_frail most_frail ageatdeath, lpattern(dash solid shortdash) title("social integration by age and frailty tertiles") ///
ytitle(predicted social integratiomn score) xtitle(age at last wave) legend(order(1 "least frail" 2 "middle" 3 "most frail") col(1) ring(0) pos(1)) sort
/*FRAILTY*/
clear
use "$work\all deceased all waves POST MULTIPLE IMPUTATION for descriptives.dta"
mi estimate: regress frailty_score ageatdeath nettotw_bu_s socintscore ssscore
/*sex*/
mi estimate, saving(one, replace): regress frailty_score ageatdeath if sex==1
mi predict male if sex==1 using one
mi estimate, saving(two, replace): regress frailty_score ageatdeath if sex==2
mi predict female if sex==2 using two
line male female ageatdeath, lpattern(dash solid) title("frailty score by age and sex") ///
ytitle(predicted frailty score) xtitle(age at last wave) legend(order(2 "female" 1 "male") col(1) ring(0) pos(4)) sort
/*wealth*/
mi estimate, saving(one, replace): regress frailty_score ageatdeath if wealth3==1
mi predict poorest if wealth3==1 using one
mi estimate, saving(two, replace): regress frailty_score ageatdeath if wealth3==2
mi predict middle if wealth3==2 using two
mi estimate, saving(three, replace): regress frailty_score ageatdeath if wealth3==3
mi predict richest if wealth3==3 using three
line poorest middle richest ageatdeath, lpattern(dash solid shortdash) title("frailty score by age and wealth tertiles") ///
ytitle(predicted frailty score) xtitle(age at last wave) legend(order(1 "poorest" 2 "middle" 3 "richest") col(1) ring(0) pos(4)) sort
/*social support*/
clear
use "$work\all deceased all waves POST MULTIPLE IMPUTATION for descriptives.dta"
xtile ssscore3 = ssscore, nq(3)
mi estimate, saving(one, replace): regress frailty_score ageatdeath if ssscore3==1
mi predict lowest if wealth3==1 using one
mi estimate, saving(two, replace): regress frailty_score ageatdeath if ssscore3==2
mi predict middle if wealth3==2 using two
mi estimate, saving(three, replace): regress frailty_score ageatdeath if ssscore3==3
mi predict highest if wealth3==3 using three
line lowest middle highest ageatdeath, lpattern(dash solid shortdash) title("frailty score by age and social support tertiles") ///
ytitle(predicted frailty score) xtitle(age at last wave) legend(order(1 "poorest" 2 "middle" 3 "richest") col(1) ring(0) pos(4)) sort
/*social integration*/
clear
use "$work\all deceased all waves POST MULTIPLE IMPUTATION for descriptives.dta"
xtile socintscore3 = socintscore, nq(3)
mi estimate, saving(one, replace): regress frailty_score ageatdeath if socintscore3==1
mi predict lowest if wealth3==1 using one
mi estimate, saving(two, replace): regress frailty_score ageatdeath if socintscore3==2
mi predict middle if wealth3==2 using two
mi estimate, saving(three, replace): regress frailty_score ageatdeath if socintscore3==3
mi predict highest if wealth3==3 using three
line lowest middle highest ageatdeath, lpattern(dash solid shortdash) title("frailty score by age and social integration tertiles") ///
ytitle(predicted frailty score) xtitle(age at last wave) legend(order(1 "poorest" 2 "middle" 3 "richest") col(1) ring(0) pos(4)) sort
/***********************************************************************************/
/*DESCRIPTIVES of linear associations between vars - ONLY ON CRUDE IMPUTED*/
clear
use "$work\all deceased all waves POST MULTIPLE IMPUTATION for descriptives.dta"
regress ssscore ageatdeath sex frailty_score nettotw_bu_s
/*SSSCORE*/
/*sex*/
regress ssscore ageatdeath if sex==1
predict male if sex==1
regress ssscore ageatdeath if sex==2
predict female if sex==2
line male female ageatdeath, lpattern(dash solid) title("social support by age and sex") ///
ytitle(predicted social support score) xtitle(age at last wave) legend(order(2 "female" 1 "male") col(1) ring(0) pos(1)) sort
/*wealth*/
regress ssscore ageatdeath if wealth3==1
predict poorest if wealth3==1
regress ssscore ageatdeath if wealth3==2
predict middle if wealth3==2
regress ssscore ageatdeath if wealth3==3
predict richest if wealth3==3
line poorest middle richest ageatdeath, lpattern(dash solid shortdash) title("social support by age and wealth tertiles") ///
ytitle(predicted social support score) xtitle(age at last wave) legend(order(1 "poorest" 2 "middle" 3 "richest") col(1) ring(0) pos(1)) sort
/*frailty*/
regress ssscore ageatdeath if frailty3==1
predict least_frail if frailty3==1
regress ssscore ageatdeath if frailty3==2
predict mid_frail if frailty3==2
regress ssscore ageatdeath if frailty3==3
predict most_frail if frailty3==3
line least_frail mid_frail most_frail ageatdeath, lpattern(dash solid shortdash) title("social support by age and frailty tertiles") ///
ytitle(predicted social support score) xtitle(age at last wave) legend(order(1 "least frail" 2 "middle" 3 "most frail") col(1) ring(0) pos(1)) sort
/*SOCINTSCORE*/
clear
use "$work\all deceased all waves POST MULTIPLE IMPUTATION for descriptives.dta"
regress socintscore ageatdeath frailty_score nettotw_bu_s
/*sex*/
regress socintscore ageatdeath if sex==1
predict male if sex==1
regress socintscore ageatdeath if sex==2
predict female if sex==2
line male female ageatdeath, lpattern(dash solid) title("social integration by age and sex") ///
ytitle(predicted social integration score) xtitle(age at last wave) legend(order(2 "female" 1 "male") col(1) ring(0) pos(1)) sort
/*wealth*/
regress socintscore ageatdeath if wealth3==1
predict poorest if wealth3==1
regress socintscore ageatdeath if wealth3==2
predict middle if wealth3==2
regress socintscore ageatdeath if wealth3==3
predict richest if wealth3==3
line poorest middle richest ageatdeath, lpattern(dash solid shortdash) title("social integration by age and wealth tertiles") ///
ytitle(predicted social integration score) xtitle(age at last wave) legend(order(1 "poorest" 2 "middle" 3 "richest") col(1) ring(0) pos(1)) sort
/*frailty*/
regress socintscore ageatdeath if frailty3==1
predict least_frail if frailty3==1
regress socintscore ageatdeath if frailty3==2
predict mid_frail if frailty3==2
regress socintscore ageatdeath if frailty3==3
predict most_frail if frailty3==3
line least_frail mid_frail most_frail ageatdeath, lpattern(dash solid shortdash) title("social integration by age and frailty tertiles") ///
ytitle(predicted social integratiomn score) xtitle(age at last wave) legend(order(1 "least frail" 2 "middle" 3 "most frail") col(1) ring(0) pos(1)) sort
/*********************************************************************/
/*LONGITUDINAL SUMMARY OF frailty, ss, socint, wealth*/
/*COMPLETE CASE*/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"
anova frailty_score wave_beforedeath
anova nettotw_bu_s wave_beforedeath
anova socintscore wave_beforedeath
anova ssscore wave_beforedeath
gen frailty_score2=frailty_score
gen nettotw_bu_s2=nettotw_bu_s
gen ssscore2=ssscore
gen socintscore2=socintscore
collapse (mean)frailty_score (mean)nettotw_bu_s (mean)ssscore (mean)socintscore (count)frailty_score2 (count)nettotw_bu_s2 (count)ssscore2 (count)socintscore2, by(wave_beforedeath) 
twoway connected frailty_score wave_beforedeath, connect(L)
twoway connected nettotw_bu_s wave_beforedeath, connect(L)
twoway connected ssscore wave_beforedeath, connect(L)
twoway connected socintscore wave_beforedeath, connect(L)
/*POST CRUDE IMPUTATION*/
clear
use "$work\all deceased all waves post crude imputation for descriptives.dta"
anova frailty_score wave_beforedeath
anova nettotw_bu_s wave_beforedeath
anova socintscore wave_beforedeath
anova ssscore wave_beforedeath
gen frailty_score2=frailty_score
gen nettotw_bu_s2=nettotw_bu_s
gen ssscore2=ssscore
gen socintscore2=socintscore
collapse (mean)frailty_score (mean)nettotw_bu_s (mean)ssscore (mean)socintscore (count)frailty_score2 (count)nettotw_bu_s2 (count)ssscore2 (count)socintscore2, by(wave_beforedeath) 
/*AGE/COHORT EFFECTS on frailty, ss, socint, wealth - POST CRUDE IMP*/
clear
use "$work\all deceased all waves post crude imputation for descriptives.dta"
collapse (mean)frailty_score, by(wave_beforedeath cohort wealth3_fp)
drop if wealth3_fp==.
reshape wide frailty_score, i(wave_beforedeath cohort) j(wealth3_fp)
sort cohort wave_before
clear
use "$work\all deceased all waves post crude imputation for descriptives.dta"
collapse (count)frailty_score, by(wave_beforedeath cohort wealth3_fp)
drop if wealth3_fp==.
reshape wide frailty_score, i(wave_beforedeath cohort) j(wealth3_fp)
sort cohort wave_before


/***DESCRIPTIVES ON THE MISSING SOCIAL SUPPOR/SOCIAL INTEGRATION VARS - PRE IMPUTED DATA***/
/*******************************************************************************************/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"
/*t1 describe the % of missing by wave*/
collapse (count)idauniq (sum)miss_*, by(wave_beforedeath)
/*t2 describe the vars by wave*/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"
tab scptr wave_beforedeath, col chi
tab scchd wave_beforedeath, col chi
tab scfam wave_beforedeath, col chi
tab scfrd wave_beforedeath, col chi
bys wave_beforedeath: sum chicontact, detail
anova chicontact wave_beforedeath
bys wave_beforedeath: sum famcontact, detail
anova famcontact wave_beforedeath
bys wave_beforedeath: sum friecontact, detail
anova friecontact wave_beforedeath
bys wave_beforedeath: sum memorg, detail
anova memorg wave_beforedeath
tab memreg wave_beforedeath, col chi
/*sum mean score for child, fam, friend ss*/
bys wave_beforedeath: sum childscore, detail
anova childscore wave_beforedeath
kwallis childscore, by(wave_beforedeath)
bys wave_beforedeath: sum famscore, detail
anova famscore wave_beforedeath
kwallis famscore, by(wave_beforedeath)
bys wave_beforedeath: sum friscore, detail
anova friscore wave_beforedeath
kwallis friscore, by(wave_beforedeath)
/*overall socint score*/
bys wave_beforedeath: sum socintscore, detail
anova socintscore wave_beforedeath
kwallis socintscore, by(wave_beforedeath)
/*overall ss score*/
bys wave_beforedeath: sum ssscore, detail
anova ssscore wave_beforedeath
kwallis ssscore, by(wave_beforedeath)
/*****************************************************************/
/*describe missing for last productive by key characteristics*/
/*NB - i actually think i should re-do this using tertiles derived for last productive only*/
/*sex*/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"
keep if last_productive==wave
foreach var of varlist miss_*{
tab `var' sex, chi
return li 
}
collapse (count)idauniq (sum)miss_*, by(sex) 
/*age*/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"
keep if last_productive==wave
foreach var of varlist miss_*{
tab `var' agecats80, chi
return li 
}
collapse (count)idauniq (sum)miss_*, by(agecats80) 
/*wealth tertiles*/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"
keep if last_productive==wave
xtile wealth3 = nettotw_bu_s, nq(3)
foreach var of varlist miss_*{
tab `var' wealth3, chi
return li 
}
collapse (count)idauniq (sum)miss_*, by(wealth3) 
/*frailty tertiles*/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"
keep if last_productive==wave
xtile frailty3 = frailty_score, nq(3)
foreach var of varlist miss_*{
tab `var' frailty3, chi
return li 
}
collapse (count)idauniq (sum)miss_*, by(frailty3) 
/*predict the missingness by sex, age, wealth and frailty - to demonstrate MAR (not MCAR)*/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"
keep if last_productive==wave
xtile wealth3 = nettotw_bu_s, nq(3)
xtile frailty3 = frailty_score, nq(3)
foreach var of varlist miss_* {
logit `var' sex agecats80 wealth3 frailty3
}
/*linear associations between vars*/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"
keep if last_productive==wave
xtile wealth3 = nettotw_bu_s, nq(3)
xtile frailty3 = frailty_score, nq(3)
regress ssscore ageatdeath i.wealth3 i.frailty3
/*SSSCORE*/
/*sex*/
regress ssscore ageatdeath if sex==1
predict male
regress ssscore ageatdeath if sex==2
predict female
line male female ageatdeath, lpattern(dash solid) title("social support by age and sex") ///
ytitle(predicted social support score) xtitle(age at last wave) legend(order(2 "female" 1 "male") col(1) ring(0) pos(1)) sort
/*wealth*/
regress ssscore ageatdeath if wealth3==1
predict poorest
regress ssscore ageatdeath if wealth3==2
predict middle
regress ssscore ageatdeath if wealth3==3
predict richest
line poorest middle richest ageatdeath, lpattern(dash solid shortdash) title("social support by age and wealth tertiles") ///
ytitle(predicted social support score) xtitle(age at last wave) legend(order(1 "poorest" 2 "middle" 3 "richest") col(1) ring(0) pos(1)) sort
/*frailty*/
regress ssscore ageatdeath if frailty3==1
predict least_frail
regress ssscore ageatdeath if frailty3==2
predict mid_frail
regress ssscore ageatdeath if frailty3==3
predict most_frail
line least_frail mid_frail most_frail ageatdeath, lpattern(dash solid shortdash) title("social support by age and frailty tertiles") ///
ytitle(predicted social support score) xtitle(age at last wave) legend(order(1 "least frail" 2 "middle" 3 "most frail") col(1) ring(0) pos(1)) sort
/*SOCINTSCORE*/
clear
use "$work\all deceased all waves PRE imputation for descriptives.dta"
keep if last_productive==wave
xtile wealth3 = nettotw_bu_s, nq(3)
xtile frailty3 = frailty_score, nq(3)
regress socintscore ageatdeath i.wealth3 i.frailty3
/*sex*/
regress socintscore ageatdeath if sex==1
predict male
regress socintscore ageatdeath if sex==2
predict female
line male female ageatdeath, lpattern(dash solid) title("social integration by age and sex") ///
ytitle(predicted social integration score) xtitle(age at last wave) legend(order(2 "female" 1 "male") col(1) ring(0) pos(1)) sort
/*wealth*/
regress socintscore ageatdeath if wealth3==1
predict poorest
regress socintscore ageatdeath if wealth3==2
predict middle
regress socintscore ageatdeath if wealth3==3
predict richest
line poorest middle richest ageatdeath, lpattern(dash solid shortdash) title("social integration by age and wealth tertiles") ///
ytitle(predicted social integration score) xtitle(age at last wave) legend(order(1 "poorest" 2 "middle" 3 "richest") col(1) ring(0) pos(1)) sort
/*frailty*/
regress socintscore ageatdeath if frailty3==1
predict least_frail
regress socintscore ageatdeath if frailty3==2
predict mid_frail
regress socintscore ageatdeath if frailty3==3
predict most_frail
line least_frail mid_frail most_frail ageatdeath, lpattern(dash solid shortdash) title("social integration by age and frailty tertiles") ///
ytitle(predicted social integratiomn score) xtitle(age at last wave) legend(order(1 "least frail" 2 "middle" 3 "most frail") col(1) ring(0) pos(1)) sort



/****************************************************************************/
/*Comparative descriptives on the CRUDE IMPUTED DATA*/
clear
use "$work\all deceased all waves post crude imputation for descriptives.dta"
/*describe % of missing by wave*/
collapse (count)idauniq (sum)miss_*, by(wave_beforedeath)
/*describe the vars by wave*/
clear
use "$work\all deceased all waves post crude imputation for descriptives.dta"
tab scptr wave_beforedeath, col chi
tab scchd wave_beforedeath, col chi
tab scfam wave_beforedeath, col chi
tab scfrd wave_beforedeath, col chi
bys wave_beforedeath: sum chicontact, detail
anova chicontact wave_beforedeath
bys wave_beforedeath: sum famcontact, detail
anova famcontact wave_beforedeath
bys wave_beforedeath: sum friecontact, detail
anova friecontact wave_beforedeath
bys wave_beforedeath: sum memorg, detail
anova memorg wave_beforedeath
tab memreg wave_beforedeath, col chi
/*sum mean score for child, fam, friend ss*/
bys wave_beforedeath: sum childscore, detail
anova childscore wave_beforedeath
kwallis childscore, by(wave_beforedeath)
bys wave_beforedeath: sum famscore, detail
anova famscore wave_beforedeath
kwallis famscore, by(wave_beforedeath)
bys wave_beforedeath: sum friscore, detail
anova friscore wave_beforedeath
kwallis friscore, by(wave_beforedeath)
/*overall socint score*/
bys wave_beforedeath: sum socintscore, detail
anova socintscore wave_beforedeath
kwallis socintscore, by(wave_beforedeath)
/*overall ss score*/
bys wave_beforedeath: sum ssscore, detail
anova ssscore wave_beforedeath
kwallis ssscore, by(wave_beforedeath)
/*****************************************************************/
/*describe missing for last productive by key characteristics*/
/*sex*/
clear
use "$work\all deceased all waves post crude imputation for descriptives.dta"
keep if last_productive==wave
foreach var of varlist miss_*{
tab `var' sex, chi
return li 
}
collapse (count)idauniq (sum)miss_*, by(sex) 
/*age*/
clear
use "$work\all deceased all waves post crude imputation for descriptives.dta"
keep if last_productive==wave
foreach var of varlist miss_*{
tab `var' agecats80, chi
return li 
}
collapse (count)idauniq (sum)miss_*, by(agecats80) 
/*wealth tertiles*/
clear
use "$work\all deceased all waves post crude imputation for descriptives.dta"
keep if last_productive==wave
xtile wealth3 = nettotw_bu_s, nq(3)
foreach var of varlist miss_*{
tab `var' wealth3, chi
return li 
}
collapse (count)idauniq (sum)miss_*, by(wealth3) 
/*frailty tertiles*/
clear
use "$work\all deceased all waves post crude imputation for descriptives.dta"
keep if last_productive==wave
xtile frailty3 = frailty_score, nq(3)
foreach var of varlist miss_*{
tab `var' frailty3, chi
return li 
}
collapse (count)idauniq (sum)miss_*, by(frailty3) 



/*tabout */ /*
tabout scptr scchd scfam scfrd ///
chicontact scchdg2 scchdh2 scchdi2 famcontact scfamg2 scfamh2 scfami2 friecontact scfrdg2 scfrdh2 scfrdi2 memorg scorg012 scorg022 scorg042 scorg052 scorg062 scorg072 scorg082 memreg ///
scchda2 scchdb2 scchdc2 scfama2 scfamb2 scfamc2 scfrda2 scfrdb2 scfrdc2 scchdd2 scchde2 scchdf2 scfamd2 scfame2 scfamf2 scfrdd2 scfrde2 scfrdf2 sex using table_sex.xls, mi cell(row freq) ///
format (0p 0) clab(_) layout(row) ptotal(single) stats(chi2) replace 

keep if last_productive==wave
tabout miss_scptr miss_scchd miss_scfam miss_scfrd miss_chicontact sex using misstable_sex.xls, cell(col freq) ///
format (0p 0) clab(_) layout(row) ptotal(single) stats(chi2) replace 

collapse (count)idauniq (sum)miss_*, by(sex) 


tab miss_scptr sex, chi
return li

tabout sex ageatdeath3 frailty_score3 social_isolation difjob2 edqual2 nssec3 wealth5 sclddr2_cats ///
tenure2 housing_probscats material_depcats transport_deprived peace3 using table_peace.xls, mi cell(row freq) ///
format (0p 0) clab(_) layout(row) ptotal(single) replace */



/**************************************************************************************/

/*GENERATE DATASETS FOR ANALYSIS(and USE IN MPLUS)*/
/**************************************************************************************/
/*PAPER 1 - descriptives and looking at interrelationhsips between frailty, age and ss sep*/
/*imputed data*/
/*last time point*/
clear 
use "$work\deceased cohort members only index and eol working prep file.dta"
sort idauniq last_productive
save "$work\deceased cohort members only index and eol working prep file.dta", replace
clear
use "$work\wave_1_5_elsa_data_prepped incl financial.dta"
rename wave last_productive
sort idauniq last_productive
merge 1:1 idauniq last_productive using "$work\deceased cohort members only index and eol working prep file.dta"
keep if _merge==3
/*gen age cats for descriptives*/
recode ageatdeath (50/79 = 1) (80/100 = 2), gen(agecats80)
label define agecats80 1 "below 80" 2 "80 and above"
label values agecats80 agecats80
tab ageatdeath agecats80, mi
/*********************************************/
/*descriptives table 1*/
sum ageatdeath, detail
hist ageatdeath
bys agecats80: sum ageatdeath, detail
bys sex: sum ageatdeath, detail
tab sex, mi
bys agecats80: tab sex, mi
/*for eol cohort only*/
preserve 
keep if eol_flag==1
/*duration of illness*/
tab howlongill2, mi
bys sex: tab howlongill2, mi
bys agecats80: tab howlongill2, mi
/*depressed*/
tab depresslastyear, mi
bys sex: tab depresslastyear, mi
bys agecats80: tab depresslastyear, mi
/*adl/iadl*/
sum adl_iadlscore, detail
bys sex: sum adl_iadlscore, detail
bys agecats80: sum adl_iadlscore, detail
/*peace*/
tab peace3, mi
bys sex: tab peace3, mi
bys agecats80: tab peace3, mi
restore
/*SEP vars*/
tab edqual2, mi
bys sex: tab edqual2, mi
bys agecats80: tab edqual2, mi
sum nettotw_bu_s, detail
bys sex: sum nettotw_bu_s, detail
bys agecats80: sum nettotw_bu_s, detail
sum ssscore, detail
bys sex: sum ssscore, detail
bys agecats80: sum ssscore, detail
tab sclddr2_cats, mi
bys sex: tab sclddr2_cats, mi
bys agecats80: tab sclddr2_cats, mi
tab tenure2, mi
bys sex: tab tenure2, mi
bys agecats80: tab tenure2, mi
tab housing_probscats, mi
bys sex: tab housing_probscats, mi
bys agecats80: tab housing_probscats, mi
/*ss and social int*/
sum socintscore, detail
bys sex: sum socintscore, detail
bys agecats80: sum socintscore, detail
sum ssscore, detail
bys sex: sum ssscore, detail
bys agecats80: sum ssscore, detail
/*outcomes*/
tab placeofdeath
bys sex: tab placeofdeath
bys agecats80: tab placeofdeath
tab hospital_stays
bys sex: tab hospital_stays
bys agecats80: tab hospital_stays
tab timein_hospital3
bys sex: tab timein_hospital3
bys agecats80: tab timein_hospital3
/*********************************************************/
/*gen wave year*/
gen waveyear=.
replace waveyear=2002 if last_productive==1
replace waveyear=2004 if last_productive==2
replace waveyear=2006 if last_productive==3
replace waveyear=2008 if last_productive==4
replace waveyear=2010 if last_productive==5
/*dobyear recode*/
gen dobyear3=dobyear
replace dobyear3=1914 if dobyear==-7 
/*gen age at last productive wave*/
gen ageatlastwave=waveyear-dobyear3
/*gen tertiles*/ 
xtile wealth3 = nettotw_bu_s, nq(3)
xtile socint3 = socintscore, nq(3)
xtile ss3 = ssscore, nq(3)
xtile sss3 = sclddr2, nq(3)
tab wealth3, mi
tab socint3, mi
tab ss3, mi
tab sss3, mi
/*gen frailty by sex*/
gen frailty_fem=frailty_score if sex==2
gen frailty_male=frailty_score if sex==1
/*gen frailty by wealth*/
gen frailty_richest=frailty_score if wealth3==3
gen frailty_poorest=frailty_score if wealth3==1
gen frailty_midwealth=frailty_score if wealth3==2
/*gen frailty by ss and socint*/
gen frailty_highestsocint=frailty_score if socint3==3
gen frailty_middlesocint=frailty_score if socint3==2
gen frailty_lowestsocint=frailty_score if socint3==1
gen frailty_misocint=frailty_score if socint3==.
/**/
gen frailty_highestss=frailty_score if ss3==3
gen frailty_middless=frailty_score if ss3==2
gen frailty_lowestss=frailty_score if ss3==1
gen frailty_miss=frailty_score if ss3==.
/*gen frailty by tenure*/
gen frailty_owner=frailty_score if tenure2==1
gen frailty_renter=frailty_score if tenure2==2
/*gen frailty by education*/
gen frailty_top=frailty_score if edqual2==1
gen frailty_middle=frailty_score if edqual2==2
gen frailty_bottom=frailty_score if edqual2==3
/*gen frailty by sss*/
gen frailty_lowsss=frailty_score if sss3==1
gen frailty_midsss=frailty_score if sss3==2
gen frailty_highsss=frailty_score if sss3==3
gen frailty_misss=frailty_score if sss3==.

/*scatter*/
/*education*/
twoway (lfit frailty_top ageatlastwave) (lfit frailty_middle ageatlastwave, clpattern(dash)) (lfit frailty_bottom ageatlastwave, clpattern(shortdash)) , ///
ytitle(frailty score) xtitle(age at last wave) legend(order(1 "highest" 2 "middle" 3 "lowest")) ///
title("frailty by age and education")

/*gender*/
twoway (lfitci frailty_fem ageatlastwave) (lfitci frailty_male ageatlastwave, clpattern(dash)), ///
ytitle(frailty score) xtitle(age at last wave) legend(order(2 "linear fit females" 4 "linear fit males" 1 - )) ///
title("frailty by age and gender")

/*wealth*/
twoway (lfit frailty_richest ageatlastwave) (lfit frailty_midwealth ageatlastwave, clpattern(dash)) (lfit frailty_poorest ageatlastwave, clpattern(shortdash)) , ///
ytitle(frailty score) xtitle(age at last wave) legend(order(1 "richest" 2 "middle" 3 "poorest")) ///
title("frailty by age and wealth tertiles")

/*social integration*/
twoway (lfit frailty_highestsocint ageatlastwave) (lfit frailty_middlesocint ageatlastwave, clpattern(dash)) (lfit frailty_lowestsocint ageatlastwave, clpattern(shortdash)) (lfit frailty_misocint ageatlastwave, clpattern(longdash)), ///
ytitle(frailty score) xtitle(age at last wave) legend(order(1 "richest" 2 "middle" 3 "poorest" 4 "missing")) ///
title("frailty by age and social integration tertiles")

/*social support*/
twoway (lfit frailty_highestss ageatlastwave) (lfit frailty_middless ageatlastwave, clpattern(dash)) (lfit frailty_lowestss ageatlastwave, clpattern(shortdash)) (lfit frailty_miss ageatlastwave, clpattern(longdash)), ///
ytitle(frailty score) xtitle(age at last wave) legend(order(1 "richest" 2 "middle" 3 "poorest" 4 "missing")) ///
title("frailty by age and social support tertiles")

/*tenure*/
twoway (lfit frailty_owner ageatlastwave) (lfit frailty_renter ageatlastwave, clpattern(dash)), ///
ytitle(frailty score) xtitle(age at last wave) legend(order(1 "owner occupier" 2 "renter")) ///
title("frailty by age and tenure")

/*sss*/
twoway (lfit frailty_highsss ageatlastwave) (lfit frailty_midsss ageatlastwave, clpattern(dash)) (lfit frailty_lowsss ageatlastwave, clpattern(shortdash)) (lfit frailty_misss ageatlastwave, clpattern(longdash)), ///
ytitle(frailty score) xtitle(age at last wave) legend(order(1 "high" 2 "mid" 3 "low" 4 "missing")) ///
title("frailty by age and subjective social status")


regress frailty_score ageatlastwave i.sex nettotw_bu_s ssscore socintscore

regress n_hospital frailty_score ageatlastwave i.sex nettotw_bu_s ssscore socintscore

/*correlations*/
pwcorr frailty_score nettotw_bu_s socintscore ssscore, sig

pwcorr frailty_score ssscore, sig



/***************************************************************************************/
/*LONGITUDINAL DATA FOR ALL DECEASED WHO JOINED AT WAVE 1*/
/*?? CHECK - i cant see where i keep only those who joined at wave 1 - i may have overlooked this*/

clear 
use "$work\deceased cohort members only index and eol working prep file.dta"
sort idauniq
save "$work\deceased cohort members only index and eol working prep file.dta", replace
clear
use "$work\wave_1_5_elsa_data_prepped incl financial.dta"
sort idauniq
merge m:1 idauniq using "$work\deceased cohort members only index and eol working prep file.dta"
keep if _merge==3



/*TEST TRAJECTORIES ON ENTIRE ELSA COHORT - NOT JUST THOSE WHO ARE DECEASED*/
/*
/*merge eol to index data*/
clear 
use "$raw\index_file_wave_0-wave_5_v2.dta"
/*but first keep only core members - may need to link partner iformation back in later but for now only interested in core members because this is the representative sample and///
only core members were eligible for an eol questionnaire - NB: the index file contains info on everyone sampled from HSE plus others living in the household - core members are sample (excluding partners) who responded when initially asked*/
keep if finstatw1==1 | finstatw2==1 | finstatw3==1 | finstatw4==1 | finstatw5==1 ///
| finstatw3==7 | finstatw4==7 | finstatw5==7 ///
| finstatw4==14 | finstatw5==14  
sort idauniq
save "$work\index_file_wave_0-wave_5_v2.dta", replace
clear
use "$work\wave_1_5_elsa_data_prepped incl financial.dta"
sort idauniq
merge m:1 idauniq using "$work\index_file_wave_0-wave_5_v2.dta"

drop if dobyear>1952 */

/*descriptive data for paper 1*/
/*gen age cats for descriptives*/
recode ageatdeath (50/79 = 1) (80/100 = 2), gen(agecats80)
label define agecats80 1 "below 80" 2 "80 and above"
label values agecats80 agecats80
tab ageatdeath agecats80, mi
/*gen 2rd, 3rd, 4th, 5th wave before death*/
bys idauniq: gen predeath2=last_productive-1
bys idauniq: gen predeath3=last_productive-2
bys idauniq: gen predeath4=last_productive-3
bys idauniq: gen predeath5=last_productive-4
foreach var of varlist predeath2-predeath5{
replace `var'=. if `var'<1
}
preserve
keep if wave==last_productive
sum frailty_score, detail
bys sex: sum frailty_score, detail
bys agecats80: sum frailty_score, detail
restore

preserve
keep if wave==predeath2
tab sex
tab agecats80
sum frailty_score, detail
bys sex: sum frailty_score, detail
bys agecats80: sum frailty_score, detail
restore

preserve
keep if wave==predeath3
tab sex
tab agecats80
sum frailty_score, detail
bys sex: sum frailty_score, detail
bys agecats80: sum frailty_score, detail
restore

preserve
keep if wave==predeath4
tab sex
tab agecats80
sum frailty_score, detail
bys sex: sum frailty_score, detail
bys agecats80: sum frailty_score, detail
restore

preserve
keep if wave==predeath5
tab sex
tab agecats80
sum frailty_score, detail
bys sex: sum frailty_score, detail
bys agecats80: sum frailty_score, detail
restore


/*keep only if productive at wave 1*/
keep if prodw1==1
/*gen cohort flags*/
gen cohort=.
replace cohort=1 if dobyear>=1916 & dobyear<=1917 | dobyear==-7
replace cohort=2 if dobyear>=1918 & dobyear<=1922
replace cohort=3 if dobyear>=1923 & dobyear<=1927
replace cohort=4 if dobyear>=1928 & dobyear<=1932
replace cohort=5 if dobyear>=1933 & dobyear<=1937
replace cohort=6 if dobyear>=1938 & dobyear<=1942
replace cohort=7 if dobyear>=1943 & dobyear<=1947
replace cohort=8 if dobyear>=1948 & dobyear<=1952
/*dobyear recode*/
gen dobyear3=dobyear
replace dobyear3=1914 if dobyear==-7 
/*gen wave year*/
gen waveyear=.
replace waveyear=2002 if wave==1
replace waveyear=2004 if wave==2
replace waveyear=2006 if wave==3
replace waveyear=2008 if wave==4
replace waveyear=2010 if wave==5
/*gen age at wave */
gen ageatwave=waveyear-dobyear3
/*gen mid age for cohort at wave x*/
gen midageatwave=.
replace midageatwave=87.5 if wave==1 & cohort==1 
replace midageatwave=82.5 if wave==1 & cohort==2
replace midageatwave=77.5 if wave==1 & cohort==3
replace midageatwave=72.5 if wave==1 & cohort==4
replace midageatwave=67.5 if wave==1 & cohort==5
replace midageatwave=62.5 if wave==1 & cohort==6
replace midageatwave=57.5 if wave==1 & cohort==7
replace midageatwave=52.5 if wave==1 & cohort==8

replace midageatwave=89.5 if wave==2 & cohort==1 
replace midageatwave=84.5 if wave==2 & cohort==2
replace midageatwave=79.5 if wave==2 & cohort==3
replace midageatwave=74.5 if wave==2 & cohort==4
replace midageatwave=69.5 if wave==2 & cohort==5
replace midageatwave=64.5 if wave==2 & cohort==6
replace midageatwave=59.5 if wave==2 & cohort==7
replace midageatwave=54.5 if wave==2 & cohort==8

replace midageatwave=91.5 if wave==3 & cohort==1 
replace midageatwave=86.5 if wave==3 & cohort==2
replace midageatwave=81.5 if wave==3 & cohort==3
replace midageatwave=76.5 if wave==3 & cohort==4
replace midageatwave=71.5 if wave==3 & cohort==5
replace midageatwave=66.5 if wave==3 & cohort==6
replace midageatwave=61.5 if wave==3 & cohort==7
replace midageatwave=56.5 if wave==3 & cohort==8

replace midageatwave=93.5 if wave==4 & cohort==1 
replace midageatwave=88.5 if wave==4 & cohort==2
replace midageatwave=83.5 if wave==4 & cohort==3
replace midageatwave=78.5 if wave==4 & cohort==4
replace midageatwave=73.5 if wave==4 & cohort==5
replace midageatwave=68.5 if wave==4 & cohort==6
replace midageatwave=63.5 if wave==4 & cohort==7
replace midageatwave=58.5 if wave==4 & cohort==8

replace midageatwave=95.5 if wave==5 & cohort==1 
replace midageatwave=90.5 if wave==5 & cohort==2
replace midageatwave=85.5 if wave==5 & cohort==3
replace midageatwave=80.5 if wave==5 & cohort==4
replace midageatwave=75.5 if wave==5 & cohort==5
replace midageatwave=70.5 if wave==5 & cohort==6
replace midageatwave=65.5 if wave==5 & cohort==7
replace midageatwave=60.5 if wave==5 & cohort==8
/*flag members who contributed to all wave 'balanced cohort'*/
gen balanced_cohort=0
replace balanced_cohort=1 if (prodw2==1 & prodw3==1 & prodw4==1 & prodw5==1)
tab balanced_cohort, mi
save "work\temp for longitudinal analysis.dta", replace

/*collapse*/
clear
use "work\temp for longitudinal analysis.dta"
collapse (mean)frailty_score (firstnm)midageatwave (count)idauniq, by(cohort wave)
gen cohort1=frailty_score if cohort==1
gen cohort2=frailty_score if cohort==2
gen cohort3=frailty_score if cohort==3
gen cohort4=frailty_score if cohort==4
gen cohort5=frailty_score if cohort==5
gen cohort6=frailty_score if cohort==6
gen cohort7=frailty_score if cohort==7
gen cohort8=frailty_score if cohort==8
twoway connected frailty_score midageatwave if cohort<=8, connect(L)


/*frailty score without age grouping*/
collapse (mean)frailty_score (count)idauniq, by(cohort wave ageatwave)
gen cohort1=frailty_score if cohort==1
gen cohort2=frailty_score if cohort==2
gen cohort3=frailty_score if cohort==3
gen cohort4=frailty_score if cohort==4
#delimit ;
line cohort1 ageatwave
|| line cohort2 ageatwave
|| line cohort3 ageatwave
|| line cohort4 ageatwave
||,
ytitle("mean frailty score")  xtitle("mean age at wave") subtitle("Mean frailty score by age and cohort") 
;
#delimit cr

/*prop frail*/
collapse (sum)frailty_flag (mean)ageatwave (count)idauniq, by(cohort wave)
gen prop_frail = frailty_flag/idauniq*100
gen cohort1=prop_frail if cohort==1
gen cohort2=prop_frail if cohort==2
gen cohort3=prop_frail if cohort==3
gen cohort4=prop_frail if cohort==4
#delimit ;
line cohort1 ageatwave
|| line cohort2 ageatwave
|| line cohort3 ageatwave
|| line cohort4 ageatwave
||,
ytitle("proportion frail")  xtitle("mean age at wave") subtitle("Proportion frail by age and cohort") 
;
#delimit cr


keep if balanced_cohort==1
/*frailty score*/
collapse (p50)frailty_score (p50)ageatwave (count)idauniq, by(cohort wave)
gen cohort1=frailty_score if cohort==1
gen cohort2=frailty_score if cohort==2
gen cohort3=frailty_score if cohort==3
gen cohort4=frailty_score if cohort==4
#delimit ;
line cohort1 ageatwave
|| line cohort2 ageatwave
|| line cohort3 ageatwave
|| line cohort4 ageatwave
||,
ytitle("mean frailty score")  xtitle("mean age at wave") subtitle("Mean frailty score by age and cohort") 
;
#delimit cr


twoway connected frailty_score ageatwave if cohort<=4, connect(L)




/*wealth*/
collapse (p50)nettotw_bu_s (mean)ageatwave (count)idauniq, by(cohort wave)
gen cohort1=nettotw_bu_s if cohort==1
gen cohort2=nettotw_bu_s if cohort==2
gen cohort3=nettotw_bu_s if cohort==3
gen cohort4=nettotw_bu_s if cohort==4
#delimit ;
line cohort1 ageatwave
|| line cohort2 ageatwave
|| line cohort3 ageatwave
|| line cohort4 ageatwave
||,
ytitle("median wealth")  xtitle("mean age at wave") subtitle("Median wealth by age and cohort") 
;
#delimit cr


















/*
gen meanageatwave1=.
replace meanageatwave1=83 if prodw1==1 & cohort==1 | dobyear==-7
replace meanageatwave1=73 if prodw1==1 & cohort==2
replace meanageatwave1=63 if prodw1==1 & cohort==3
replace meanageatwave1=53 if prodw1==1 & cohort==4

gen meanageatwave2=.
replace meanageatwave2=85 if prodw2==1 & cohort==1 | dobyear==-7
replace meanageatwave2=75 if prodw2==1 & cohort==2
replace meanageatwave2=65 if prodw2==1 & cohort==3
replace meanageatwave2=55 if prodw2==1 & cohort==4

gen meanageatwave3=.
replace meanageatwave3=87 if prodw3==1 & cohort==1 | dobyear==-7
replace meanageatwave3=77 if prodw3==1 & cohort==2
replace meanageatwave3=67 if prodw3==1 & cohort==3
replace meanageatwave3=57 if prodw3==1 & cohort==4

gen meanageatwave4=.
replace meanageatwave4=89 if prodw4==1 & cohort==1 | dobyear==-7
replace meanageatwave4=79 if prodw4==1 & cohort==2
replace meanageatwave4=69 if prodw4==1 & cohort==3
replace meanageatwave4=59 if prodw4==1 & cohort==4

gen meanageatwave5=.
replace meanageatwave5=91 if prodw5==1 & cohort==1 | dobyear==-7
replace meanageatwave5=81 if prodw5==1 & cohort==2
replace meanageatwave5=71 if prodw5==1 & cohort==3
replace meanageatwave5=61 if prodw5==1 & cohort==4 */
/*gen summary table of n of cohot at each wave*/
/*tab meanageatwave1
tab meanageatwave2
tab meanageatwave3
tab meanageatwave4
tab meanageatwave5 */
/*gen some line graphs showing age and cohort effect*/
/*median wealth*/
collapse (p50)nettotw_bu_s (firstnm)midageatwave (count)idauniq, by(cohort wave)
gen cohort1=nettotw_bu_s if cohort==1
gen cohort2=nettotw_bu_s if cohort==2
gen cohort3=nettotw_bu_s if cohort==3
gen cohort4=nettotw_bu_s if cohort==4
#delimit ;
line cohort1 midageatwave
|| line cohort2 midageatwave
|| line cohort3 midageatwave
|| line cohort4 midageatwave
||,
ytitle("median wealth")  xtitle("age") subtitle("Median wealth by age and cohort") 
;
#delimit cr



/*length of time in phase - line graph*/
collapse (p50)phase_length, by (phase3 contact_month)
gen stable=phase_length if phase3==1
gen unstable=phase_length if phase3==2
gen deteriorating=phase_length if phase3==3
gen dying=phase_length if phase3==4
#delimit ;
line stable contact_month
|| line unstable contact_month
|| line deteriorating contact_month
|| line dying contact_month
||,
ytitle("days")  xtitle("month of contact") subtitle("Median length of Phase of Illness in days by month") note("community")
;
#delimit cr


/************************************************************************************/
/*FIRST AND LAST PRODUCTIVE WAVE DATA*/
/*baseline*/
clear 
use "$work\deceased cohort members only index and eol working prep file.dta"
sort idauniq first_productive
save "$work\deceased cohort members only index and eol working prep file.dta", replace
clear
use "$work\wave_1_5_elsa_data_prepped.dta"
rename wave first_productive
sort idauniq first_productive
merge 1:1 idauniq first_productive using "$work\deceased cohort members only index and eol working prep file.dta"
drop if _merge==1
drop _merge
/*keep eol only*/
