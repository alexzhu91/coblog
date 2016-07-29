dm 'odsresults; clear';
dm 'cle log;';
dm 'cle out;';
ods _all_ close;
ods trace on;
ods html;
ods graphics on;

libname out "C:\Users\lenovo\Desktop\Raw";

/* STEP1: to build the index of the spirit of investors */
/* Import Data */
proc import datafile="C:\Users\lenovo\Desktop\Raw\SP500.csv"
out=out.sp500   
dbms=csv
replace;
getnames=yes;
run;


proc import datafile="C:\Users\lenovo\Desktop\Raw\Investor_Sentiment_Data_USA.


xls"

out=out.economics
dbms=xls
replace;
getnames=yes;
run;

/* Get the data out the effect of macroeconomic factors */
%macro regression (ind= );
proc reg data=out.economics noprint;
var &ind indpro constot consdur consnon consserv employ;
model &ind= indpro constot consdur consnon consserv employ;
output out= out.&ind  r=res;
run;
quit;

data out.&ind;
set out.&ind;
keep res yearmo;
label res="&ind";


rename res=&ind;
run;


%mend; 

%regression (ind=pdnd);
%regression (ind=nipo);
%regression (ind=ripo);
%regression (ind=turn);
%regression (ind=cefd);
%regression (ind=se);

/* Output data in the sas */
%macro out_data(dataname=);
proc export data=out.&dataname
outfile="C:\Users\lenovo\Desktop\Raw\&dataname" 
dbms=xls
replace;
run;quit;
%mend;


%out_data(dataname=pdnd);
%out_data(dataname=nipo);
%out_data(dataname=ripo);
%out_data(dataname=turn);
%out_data(dataname=cefd);
%out_data(dataname=se);
/* Put all of the data together */
proc sql;
create table out.economics_post
as select  
a.yearmo,a.cefd,b.turn,c.nipo,d.ripo,e.se,f.pdnd 
from out.cefd as a, out.turn as b, out.nipo as c,out.ripo as  
d,out.pdnd as f,out.se as e
where a.yearmo=b.yearmo=c.yearmo=d.yearmo=e.yearmo=f.yearmo;
run;quit;

ods listing;
ods html;

/* Just do two princomp procedure and compare results */
proc princomp data=out.economics;
   var cefd turn nipo ripo se pdnd;
run;

proc princomp data=out.economics_post;
   var cefd turn nipo ripo se pdnd;
run;

/*proc princomp data=out.economics_post_changes;*/
/*   var cefd turn nipo ripo se pdnd;*/
/*run;*/
/* STEP2: to test the sentiment of investors using VAR method and graphs*/
data out.sp500;
set out.sp500;
year=int(caldt/10000);
month=int(caldt/100-year*100);
pearmo=year*100+month;
run;

data out.economics;
set  out.economics;
year=int(yearmo/100);
month=int(yearmo-year*100);
day=25;
sentiment=(-.459489)*cefd+0.473805*turn+0.311910*nipo+0.206224*ripo+0.452860*se+(-.468488)*pdnd;
run;

data out.economics;
set out.economics;
date=mdy(month,day,year);
format date yymm.;
run;

data out.economics_post;
set out.economics_post;
year=int(yearmo/100);
month=int(yearmo-year*100);
day=25;
sentiment=(-.436973)*cefd+0.228026*turn+0.493202*nipo+0.357164*ripo+0.205040*se+(-.586688)*pdnd;
run;

data out.economics_post;
set out.economics_post;
date=mdy(month,day,year);
format date yymm.;
run;
data out.economics_post;
set out.economics_post;
sentiment1=sentiment -lag(sentiment);
run;
ods listing;

proc gplot data= out.economics;
plot sentiment*date/haxis=axis2 vaxis=axis1 legend = legend1;
symbol1  value=none interpol=join line=1 w=2;
axis1 label=none;
axis2 label=none order=('31JUL1965'd to '31DEC2010'd by year4); ;
title height=1"Index of sentiment levels";
format date  yymm.;
run;
quit;
proc gplot data= out.economics_post;
plot sentiment*date /  haxis=axis2 vaxis=axis1 legend = legend1;
symbol1  value=none interpol=join line=1 w=2;
axis1 label=none;
axis2 label=none order=('31JUL1965'd to '31DEC2010'd by year4); ;
title height=1"Index of sentiment changes";
format permno yymm.;
run;
quit;

proc gplot data= out.economics_post;
plot sentiment1*date /  haxis=axis2 vaxis=axis1 legend = legend1;
symbol1  value=none interpol=join line=1 w=2;
axis1 label=none;
axis2 label=none order=('31JUL1965'd to '31DEC2010'd by year4); ;
title height=1"Index of sentiment changes";
format permno yymm.;
run;
quit;

data out.sp500;
set out.sp500;
year=int(caldt/10000);
month=int(caldt/100-year*100);
day=mod(caldt,100);
date=mdy(month,day,year);
run;

data out.sp500; 
set out.sp500; 
drop day ;
format date date9.;
run;

symbol1 value=none interpol=join line=1 w=2;
axis1 label=none;
axis2 label=none order=('31DEC1925'd to '31DEC2012'd by year5); 
title height=2 "S&P 500";
proc gplot data=out.sp500;
plot spind*date /vaxis=axis1 haxis=axis2 legend=legend1;
format date year4.;
run;
quit;

proc export data=out.economics_post
outfile = "C:\Users\lenovo\Desktop\Raw\economics_post.xls" 
dbms=excel5 replace;
run;
proc export data=out.economics
outfile = "C:\Users\lenovo\Desktop\Raw\economics.xls" 
dbms=excel5 replace;
run;

/*var model*/
/*The following statements estimate a VAR(3) model and use the ROOTS option to compute the characteristic polynomial roots:*/

proc sql;	create table out.cover as select a.*, b.caldt as caldlt, b.sprtrn as rindx, b.spind as spind
from out.economics as a left join out.Sp500 as b 
on a.yearmo=b.pearmo;
quit;

data out.cover;
set out.cover;
where sentiment;
run;

data out.sp500;
set out.sp500;
where pearmo>= 196507 and pearmo<= 201012;
run;

proc varmax data=out.cover;
   model spind / p=1 noint print=(roots);
run;
/*third-order lagged regression and Granger causality test */
   proc varmax data=out.cover;
      model spind = sentiment / xlag=3;
   run;
   proc varmax data=out.cover;
      model sentiment = spind / xlag=3;
   run;
proc varmax data=out.cover;
   model spind = sentiment / p=3 noprint;
   causal group1=(spind)  group2=(sentiment);
   causal group1=(sentiment)  group2=(spind);
run;


/*Transport the format of the date*/
data out.Monthly;
set out.Monthly;
format date yymmn11.;
y=put(date, yymmddn.); *numerical;
yearmo = int(y/100);
run; 

data out.Monthly;
set out.Monthly;
drop SHRCD EXCHCD SICCD PRC VOL SHROUT;
run;

/* Calculate the stdev by permno and output the data*/
proc univariate data=out.Monthly noprint;	
by permno;	
var ret;
output out=out.statistics std=stdev n=count;	
run;   

proc sort data=out.statistics;
by count;
run;

data out.statistics;
set out.statistics;
where stdev;
run;

/* Sort stocks according to their recent return volatility*/
proc univariate data=out.statistics noprint;
var  stdev;
output out=quantile1 pctlpts=10 to 90 by 10 pctlpre=stdev; 
run;

proc sql;	create table out.statistics as select a.*, b.stdev10, b.stdev20, b.stdev30, b.stdev40, b.stdev50, b.stdev60, b.stdev70, b.stdev80, b.stdev90
from out.statistics as a, quantile1 as b ;
quit; 
data out.statistics;
set out.statistics;
if stdev<=stdev10  then rank=1;
if stdev>stdev10 and stdev<=stdev20 then rank=2;
if stdev>stdev20 and stdev<=stdev30 then rank=3;
if stdev>stdev30 and stdev<=stdev40 then rank=4;
if stdev>stdev40 and stdev<=stdev50 then rank=5;
if stdev>stdev50 and stdev<=stdev60 then rank=6;
if stdev>stdev60 and stdev<=stdev70 then rank=7;
if stdev>stdev70 and stdev<=stdev80 then rank=8;
if stdev>stdev80 and stdev<=stdev90 then rank=9;
if stdev>stdev90 then rank=10;
run;

proc sort data=out.statistics;
by rank;
run;


proc sql; 
create table out.stdev as select
distinct a.*, b.rank as rank,b.count as count
from out.Monthly as a left join out.statistics as b
on a.permno=b.permno;
quit;

data out.stdev;
set out.stdev;
where rank;
run;

proc sort data=out.stdev;
by rank;
run;

proc sql; 
create table out.sstdev as select
distinct a.*, b.sentiment1 as sentiment1, b.sentiment as sentiment
from out.stdev as a left join out.economics_post as b
on a.yearmo=b.yearmo;
quit;

proc sql; 
create table out.ssstdev as select
distinct a.*, b.sprtrn as makret
from out.sstdev as a left join out.sp500 as b
on a.yearmo=b.pearmo;
quit;

data out.ssstdev;
set out.ssstdev;
sentimentt=lag3(sentiment1);
sentimentt1=lag(sentiment);
rett=ret-sprtrn;
run;

proc sort data=out.ssstdev;
by rank;
run;


data out.ssstdev;
set out.ssstdev;
where rank;
run;
/* The monthly returns of volatility sorted portfolios are regressed on a sentiment index*/
proc reg data=out.ssstdev;
model ret=sentimentt sprtrn;
by rank;
where yearmo>= 196507 and yearmo<= 201012;
run;quit;

proc univariate data=out.ssstdev noprint;
var  sentimentt1;
output out=out.quantile pctlpts=10 to 90 by 10 pctlpre=stdev; 
run;

/* Calcultate monthly returns of ten sorted portfolios when sentiment is low or high*/

proc means data=out.ssstdev mean;
var rett;
by rank;
where sentimentt1>=-0.049845784 and yearmo>= 196507 and yearmo<= 201012 ;
run;
proc means data=out.ssstdev mean;
var rett;
by rank;
where sentimentt1<-0.049845784 and yearmo>= 196507 and yearmo<= 201012;
run;
proc means data=out.ssstdev mean;
var rett;
by rank;
where yearmo>= 196507 and yearmo<= 201012;
run;




