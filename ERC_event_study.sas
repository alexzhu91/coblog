libname myLib3 "D:\_examples\sasdata3";

/* retrieve all earnings announcement dates in 2008 */
%let wrds = wrds.wharton.upenn.edu 4016;options comamid = TCP remote=WRDS;
signon username=_prompt_;


rsubmit;
libname comp '/wrds/comp/sasdata/naa';
			 
/*
gvkey: Global Company Key 
rdq: Report Date of Quarterly Earnings
datadate: Data Date 
prccq: Price Close - Quarter 
*/

PROC SQL;
  create table rdq(keep = gvkey rdq datadate prccq) as
  select a.* 
  from comp.fundq a
  	where year(rdq) = 2008
		and indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C' ;
  quit;

proc download data=rdq out=myLib3.a_rdq;run;

endrsubmit;
	
/* unique gvkeys */
proc sql;
	create table myLib3.b_unique as
	select distinct gvkey 
	from
		myLib3.a_rdq
	;
quit;

/* match with compustat-crsp merged to retrieve PERMNO 

CC merged has a linkdt and linkenddt for which the record is valid 
linkdt: First Effective Date of Link 
linkenddt: Last Effective Date of Link 

announcement date (rdq) must be between linkdt and linkenddt: a.linkdt <= b.rdq <= linkenddt
usually linkdt and linkenddt is a date, but linkdt can be 'B' (beginning) and linkenddt 
can be 'E' (end).
*/

rsubmit;
libname crsp '/wrds/crsp/sasdata/cc';
			
proc upload data=myLib3.a_rdq out=getThese;
 
PROC SQL;
  create table ccMerged as
  select a.*, b.*
  from crsp.ccmxpf_linktable a, getThese b
  	where a.gvkey = b.gvkey
	and a.lpermno ne .
	and a.linktype in ("LC" "LN" "LU" "LX" "LD" "LS")
	and ((b.rdq >= a.LINKDT) or a.LINKDT = .B) and 
       ((b.rdq <= a.LINKENDDT) or a.LINKENDDT = .E)	 ;
  quit;

proc download data=ccMerged out=myLib3.c_ccMerged;

run;
endrsubmit;

proc sort data = myLib3.c_ccMerged; by gvkey rdq lpermno;run;

/* if for one gvkey - rdq - lpermno there are multiple observations, then take one 
(in this case, the last, which is arbitrary)
hence: it is possible that one observation (gvkey - rdq combination) has multiple permnos
after matching with CRSP decide which permno to keep (i.e. drop the permno with no match)
*/


data myLib3.c_ccMerged2 (keep = key gvkey lpermno linkdt linkenddt datadate rdq  prccq);
set  myLib3.c_ccMerged;
by gvkey rdq lpermno;

/* create own key: ultimately for each gvkey there needs to be one earnings surprise and 
stock return,hence the key needs to be unique at the level of gvkey and the quarter */
key = gvkey || "_" || datadate;

if last.lpermno then output;
run;

/* match with dsenames for historic cusip (NCUSIP) */

%let wrds = wrds.wharton.upenn.edu 4016;options comamid = TCP remote=WRDS;
signon username=_prompt_;

rsubmit;
libname crsp '/wrds/crsp/sasdata/sd';
			 
PROC SQL;
  create table dsenames(keep = PERMNO NAMEDT NAMEENDT NCUSIP) as
  select a.*
  from crsp.dsenames a
  where ncusip ne "";
  quit;

proc download data=dsenames out=myLib3.d_dsenames;run;
endrsubmit;

/* match with ibes: Company Identification (idsum)*/
rsubmit;
libname ibes '/wrds/ibes/sasdata';

proc upload data=myLib3.d_dsenames out=getIbes;

PROC SQL;
  create table ibesdata as
  select distinct a.ticker, b.*
  from ibes.idsum a, getIbes b
  where 
  		a.CUSIP = b.NCUSIP
;
quit;
proc download data=ibesdata out=myLib3.e_withIbes;
run;
endrsubmit;

proc sort data=myLib3.e_withIbes;by ticker permno NAMEDT;run;

/* join the c_ccmerged set with the IBES ticker */

proc sql;
	create table myLib3.f_allKeys as
	select a.*, b.ticker as ibesticker, b.ncusip as ibesncusip
	from myLib3.c_ccMerged2 a, myLib3.e_withIbes b
	where
		a.lpermno = b.permno
	and b.NAMEDT <= a.datadate <= b.NAMEENDT;
		
quit;

/*
IBES estimates:
STATPERS: I/B/E/S Statistical Period (date of the forecast)
FPEDATS: Forecast Period End Date (needs to equal datadate; the end of the quarter)
meanest: Mean Estimate
ACTUAL: Actual Value, from the Detail Actuals File 
FPI: Forecast Period Indicator (is 6 for the coming quarter)
*/

rsubmit;
libname ibes '/wrds/ibes/sasdata';

proc upload data=myLib3.f_allKeys out=getIbes;

PROC SQL;
  create table ibesdata as
  select distinct a.STATPERS, a.MEANEST, b.key, b.rdq, b.datadate
  from ibes.statsumu a, getIbes b
  where 
  		a.ticker = b.ibesticker
	and a.MEASURE="EPS"
	and a.FISCALP="QTR"
	and a.FPI = "6"
	and a.STATPERS < b.rdq
	and b.datadate -5 <= a.FPEDATS <= b.datadate +5
;
quit;
proc download data=ibesdata out=myLib3.g_ibesEstimate;
run;
endrsubmit;

proc sort data = myLib3.g_ibesEstimate; by key STATPERS;run;

data myLib3.h_ibesEstimateMostRecent;
set  myLib3.g_ibesEstimate;
by key;
if last.key then output;run;

/*
IBES actuals:
INT0A: Interim 0 Actual Value of the Measure (actual eps)
INT0DATS: Interim 0 Date, SAS Format
*/
data myLib3.i_ibesPrep (keep = key ibesticker datadate rdq) ;
set  myLib3.f_allKeys ;
run;


rsubmit;
libname ibes '/wrds/ibes/sasdata';

proc upload data=myLib3.i_ibesPrep out=getIbes;

PROC SQL;
  create table ibesdata as
  select distinct a.INT0A, b.key, b.rdq, b.datadate, a.INT0DATS, 
	a.ticker, a.STATPERS
  from ibes.actpsumu a, getIbes b
  where 
  		a.ticker = b.ibesticker
	and	a.INT0DATS = b.datadate
	and a.MEASURE="EPS"
;
quit;

proc download data=ibesdata out=myLib3.j_ibesActuals;
run;
endrsubmit;


proc sort data =  myLib3.j_ibesActuals ;by key STATPERS ;run;

/* keep the first actual eps. in case of multiple actual earnings per 
share, the number has been updated later as a result of stock splits, etc */

data myLib3.k_ibesActuals (drop = STATPERS);
set myLib3.j_ibesActuals;
by key;
if first.key then output;run;


proc sql;
	create table myLib3.z_test as
	select distinct *, count(key) as numberObs
	from myLib3.k_ibesActuals
	group by key;
quit;


/* join datasets so that it contains the various identifiers (gvkey, cusip, ticker, permno)
information from Compustat (rdq), and the forecast and actual from IBES;
There are still some double observations in this dataset, since the original cc-merge set
has doubles. */

proc sql;
	create table myLib3.l_Comp_and_Ibes as
	select a.*, b.MEANEST, b.STATPERS, c.INT0A as actual
	from myLib3.f_allkeys a, myLib3.h_ibesEstimateMostRecent b, myLib3.k_ibesActuals c
	where
		a.key = b.key
	and b.key = c.key;
quit;


/*
get stock return and size portfolio return for days -1 through +1 around the earning 
announcement (rdq)
dataset:  Year-end Cap. Deciles with Daily Returns - NYSE/AMEX/NASDAQ (erdport1);
PERMNO: PERMNO 
RET: Returns 
date: Calendar Date 
capn: Year End Capitalization Portfolio Assignment 
decret: Decile Return 

*/

data myLib3.m_prepDeciles (keep = key lpermno rdq);
set  myLib3.l_Comp_and_Ibes;run;

rsubmit;
libname crsp '/wrds/crspq/sasdata/ix' ;

proc upload data=myLib3.m_prepDeciles out=getDecile;run;

PROC SQL;
  create table decileData (keep = key lpermno rdq date ret capn decret) as
  select a.*, b.*
  from 
	crsp.erdport1 a, getDecile b
  where 
		a.date-1 <= b.rdq <= a.date+1
	and a.permno = b.lpermno;
  quit;

proc download data=decileData out=myLib3.n_decileData;
run;
endrsubmit;

proc sort data = myLib3.n_decileData; by key date;run;


/* compute cumulative abnormal return (car), computed as size adjusted abnormal returns;
i.e. the firm's return over the three days minus the return of firms with a similar size 
over the same period */

data myLib3.o_CAR (keep = key car capn  );
set myLib3.n_decileData;
by key;
/* retain means that the contents of these variables will be remembered over the observations 
(as every observations is the return for 1 day, and it is needed to sum these over 3 days)
*/
retain car;
if first.key then car=1;

car = car + ret - decret;

/* we are only interested in keeping the cumulative 3 day return (and not 
cumulative 1 and 2 day) */
if last.key then output;
run;


/* compute return between the IBES date and two days before earnings announcement
this is the period in which new information affect the stock price before the event window,
while it is not reflected in the analyst earnings expectation
*/


rsubmit;
libname crsp '/wrds/crspq/sasdata/sd';
			 
proc upload data=myLib3.l_Comp_and_Ibes out=getReturns;run;

PROC SQL;
  create table returnData
	(keep = key permno rdq STATPERS date ret) as
  select a.*, b.*
  from crsp.dsf a, getReturns b
  where  
		b.STATPERS+1 <= a.date <= b.rdq -2
	and a.permno = b.lpermno;
  quit;

proc sort data = returnData nodup;by key date;
proc download data=returnData out=myLib3.p_returnData;
run;
endrsubmit;

data myLib3.p_returnData;
set myLib3.p_returnData;
if RET gt -55;		* missing: -66, -77, -88 etc;
if (1*RET eq RET) ;	* must be numeric;
run;

proc sort data = myLib3.p_returnData; by key date;

data myLib3.q_preAnnounceRet;
set  myLib3.p_returnData;
by key;
retain preAnnRet;
if first.key then preAnnRet = 1;
preAnnRet = preAnnRet* (1+ret);
if last.key then output;
run;


/* join datasets */
proc sql;
	create table myLib3.r_fullSet as
	select a.*, b.capn, b.car, c.preAnnRet
	from
		myLib3.l_Comp_and_Ibes a, 
		myLib3.o_CAR b,
		myLib3.q_preAnnounceRet c
	where
		a.key = b.key
	and	b.key = c.key;
quit;


/* stock price as scalar */
data myLib3.s_vars;
set  myLib3.r_fullset;
if actual ne .;
if MEANEST ne .;
if prccq ne .;
if car ne .;
if preAnnRet ne .;

unex = (actual - MEANEST) / prccq;
loss = 0;
if unex < 0 then loss = 1;
loss_unex = loss * unex;
car_ln = log(car);
preAnnRet_ln = log(preAnnRet);
run;


proc sort data = myLib3.s_vars; by key ;run;

/* there are 120 observations with the same key, this is because CCmerged has double 
entries for some gvkeys. the first observation is taken (arbitrary) */

data myLib3.t_singleObs;
set myLib3.s_vars;
by key;
if first.key then output;run;



/*****************************************
Trim or winsorize macro
* byvar = none for no byvar;
* type  = delete/winsor (delete will trim, winsor will winsorize;
*dsetin = dataset to winsorize/trim;
*dsetout = dataset to output with winsorized/trimmed values;
*byvar = subsetting variables to winsorize/trim on;
****************************************/

%macro winsor(dsetin=, dsetout=, byvar=none, vars=, type=winsor, pctl=1 99);

%if &dsetout = %then %let dsetout = &dsetin;
    
%let varL=;
%let varH=;
%let xn=1;

%do %until ( %scan(&vars,&xn)= );
    %let token = %scan(&vars,&xn);
    %let varL = &varL &token.L;
    %let varH = &varH &token.H;
    %let xn=%EVAL(&xn + 1);
%end;

%let xn=%eval(&xn-1);

data xtemp;
    set &dsetin;
    run;

%if &byvar = none %then %do;

    data xtemp;
        set xtemp;
        xbyvar = 1;
        run;

    %let byvar = xbyvar;

%end;

proc sort data = xtemp;
    by &byvar;
    run;

proc univariate data = xtemp noprint;
    by &byvar;
    var &vars;
    output out = xtemp_pctl PCTLPTS = &pctl PCTLPRE = &vars PCTLNAME = L H;
    run;

data &dsetout;
    merge xtemp xtemp_pctl;
    by &byvar;
    array trimvars{&xn} &vars;
    array trimvarl{&xn} &varL;
    array trimvarh{&xn} &varH;

    do xi = 1 to dim(trimvars);

        %if &type = winsor %then %do;
            if not missing(trimvars{xi}) then do;
              if (trimvars{xi} < trimvarl{xi}) then trimvars{xi} = trimvarl{xi};
              if (trimvars{xi} > trimvarh{xi}) then trimvars{xi} = trimvarh{xi};
            end;
        %end;

        %else %do;
            if not missing(trimvars{xi}) then do;
              if (trimvars{xi} < trimvarl{xi}) then delete;
              if (trimvars{xi} > trimvarh{xi}) then delete;
            end;
        %end;

    end;
    drop &varL &varH xbyvar xi;
    run;

%mend winsor;

/* invoke macro to winsorize */
%winsor(dsetin=myLib3.t_singleObs, dsetout=myLib3.u_finalWinsorized, byvar=none, 
vars= car_ln preAnnRet_ln unex loss_unex, type=winsor, pctl=1 99);


proc sort data = myLib3.u_finalWinsorized; by capn;

/* regression by size decile */
PROC REG OUTEST = myLib3.v_regOutput data=myLib3.u_finalWinsorized;
   ID capn;
   MODEL  car_ln = preAnnRet_ln unex loss loss_unex/ NOPRINT;
   by capn;
RUN ;
