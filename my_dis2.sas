dm "out;clear;log;clear;";
proc sort data=xueqiu.analyst nodupkey out=analyst;
by stkcd fenddt BROKERCD descending rptdt;
run;

data analyst;
set analyst;
if feps ne .;
repdate=input(rptdt,yymmdd10.);
month=month(repdate);
year=year(repdate);
reportdt=mdy(month,'1',year);
format repdate yymmdd10. reportdt yymmn.;;
keep stkcd BROKERCD reportdt rptdt date feps meps;

proc sort data = analyst;
  by stkcd BROKERCD reportdt;
  where year(date)>2007 & intnx('month',date,-8,'E')<=reportdt<intnx('month',date,4,'E');;
run;
*ABOVE NODUP ONLY DELETE RECORDS ON THE SAME REPDATE, NOT MONTH;
Proc Sort data=analyst nodupkey out=single dupout=f; by stkcd BROKERCD reportdt descending date;run;
*this prove no dup anymore;
Proc Sort data=single nodupkey dupout=g; by stkcd BROKERCD reportdt ;run;
*every forecast of each broker forms a time series,expand disregard the fiscal date;
Proc Sql;
create table Base
  as select *, count(distinct reportdt) as num 
from single 
group by stkcd, BROKERCD
having calculated num>2
order by stkcd, BROKERCD,reportdt;
*but how does date expand itself? It's easy to get wrong;
proc expand data=base(keep=stkcd BROKERCD reportdt date  feps) out=feps to=month method=step ; 
  by stkcd BROKERCD;
  *convert feps=feps;
  id reportdt; 
run; 
/*still needs to judge,since there're jumps from 08-10, if certain month no issue,then treat as not 
updating their estimates;but this cuts estimate a lot
-8 meant to ge the latest estimate of the year, but wrong: Feb can be est of this year;*/
data x;set feps;where intnx('month',date,-8,'E')<=reportdt<intnx('month',date,4,'E');run;

PROC IMPORT OUT= per_share
DATAFILE= "H:\GTA\Ratio\FI_T9"
DBMS= dbf REPLACE;
Run;
data eps;
set per_share;
date=input(accper,yymmdd10.);
        format date  yymmdd10.;
if month(date)=12 & typrep='A';
keep stkcd date F090301B;
rename F090301B=eps;
run;
*forecast only after;
proc sql;
create table anal as
select a.*,b.*,a.feps-b.eps as forecast_error,abs(a.feps-b.eps) as abs_forecast_error
from x a left join eps b
on a.date=b.date & a.stkcd=b.stkcd;
/*MEPS=每股收益=归属于母公司所有者的净利润/对应期末普通股股数=F090301B */
proc means ;
var forecast_error;
run;
/*ensure you match the exact fiscal date for each reporting month
since in 201001 can establish 2010 eps, it can be error if next month eps is missing and for 2009 FY*/
Proc Sort data=anal; by stkcd reportdt  ;run;

proc means data = ANAL mean median maxdec=3 std N noprint;
OUTPUT OUT = forec_summary N(feps)= coverage mean(feps)= avgforecast 
std(feps)= dispersionforecast median(feps)= medianofforecast mean(forecast_error) = aveforecasterror ; 
var feps forecast_error; /*calculate average forecast error for a perticular firm and perticular quarter*/
by stkcd reportdt;
run;
data forec_summary;set forec_summary;month=month(reportdt);
proc means mean;
var coverage;
class month;
run;

/*this shows that can't establish monthly, since it's dif*/
data y;set analyst;month=month(reportdt);
proc means mean n;
var feps;
class month;
run;

/*annual version of dispersion,keep latest estimates,but don't be the t+1 year, can be Feb forecast of this year*/
data anal_yr;set anal;report_year=year(reportdt);where reportdt<intnx('month',date,3,'E');
Proc Sort data=anal_yr ; by stkcd BROKERCD date report_year descending reportdt  ;run;
Proc Sort data=anal_yr nodupkey; by stkcd BROKERCD date report_year  ;run;
Proc Sort data=anal_yr ; by stkcd  date report_year  ;run;
/*calculate average forecast error for a perticular firm and perticular quarter
on avg, two report_year forec for 1 FY, and coverage is same
date=FY, report_year=report_report_year*/
proc means data = anal_yr mean median maxdec=3 std N noprint;
OUTPUT OUT = forec_yr N(feps)= coverage mean(feps)= avgforecast 
std(feps)= dispersionforecast median(feps)= medianofforecast 
mean(forecast_error) = aveforecasterror  
mean(abs_forecast_error) = aveabsforecasterror ; 
var feps forecast_error abs_forecast_error; 
by stkcd date report_year ;
run;
data out;set forec_yr;
where report_year=year(date);drop _type_ _freq_;
PROC exPORT data=out
outfile= "H:\crash\input\anal_yr.dta"
DBMS= stata REPLACE;
Run;
