/*calc china earnings announce ret, similar to M&A 
but details may differ
400£¬200 natural day will be [-225,+120] trading day
runup markup need <60 to avoid overlap of 2nd and annual report
can incorporate many seasons, but half year report will be mingled with annual triggered discussions?*/
data repar;
set p5w.repdt;
format date date9.;
rename date=ym repdt_ar=repdt4_;keep stkcd date repdt:;
run;
option mprint;
%macro rep;
%do i=1 %to 4;
data rep&i;
set repar;
rename repdt&i._=repdt&i;
keep stkcd repdt&i._;
if ym ne .;
run;
%end;
%mend rep;
%rep;
*2nd and annual report;
data rep4;set rep4 rep2(rename=(repdt2=repdt4));run;
*********************************;
data roll ;
set xueqiu.day_ret ;
ex_ret=dretwd-rf/100;
ex_mktret=Dretwdos-rf/100;
year=year(date);
ym=mdy(month(date),1,year);
rename dretwd=ret Dretwdos=mktret;
if (markettype=1) then exchg=1;
else if markettype=4 or markettype=16 then exchg=2;
else delete;
keep stkcd ym year date ex_ret dretwd ex_mktret Dretwdos exchg;
run;
data ff_daily;set xueqiu.FF3_daily;exchg=input(exchflg,3.);drop exchflg;
where exchflg ne '0' & mktflg='A';run;
proc sort; by exchg date;
proc sort data=roll; by exchg date;
data roll;merge roll(in=a) ff_daily;by exchg date;if a ;drop mktflg;run;

proc sort data=rep4;
by stkcd;
proc sql;
create table est
   as select a.*,b.*
    from roll as a join rep4 as b
   on a.stkcd=b.stkcd and intnx('day',b.repdt4,-400)<=a.date<=intnx('day',b.repdt4,200);
proc sort data=est out=temp1;
where date lt repdt4;
by stkcd repdt4 descending date; *descending order for date is intentional;
run;
data temp1; 
set temp1;
by stkcd repdt4;
if first.repdt4=1 then td_count=0;
td_count=td_count-1; *increments in negative direction;
retain td_count;
run;

*proc print data= temp1;
*run;

*Next count trading days after event;
proc sort data=est out=temp2;
where date ge repdt4;
by stkcd repdt4 date; *ascending order as default;
run;
data temp2; 
set temp2;
by stkcd repdt4;
if first.repdt4=1 then td_count=0;
td_count=td_count+1; *increments in positive direction;
if date = repdt4 then td_count=0; *special case for even date;
retain td_count;
run;

*Rejoin the before and after days (concatenating) then sort;
data est1; 
set temp1 temp2;
run;
proc sort;
by stkcd repdt4 td_count;
run;

options errors=1 noprint ;

proc reg data=est1 outest=capm  noprint edf ;*tableout gets the full regression table;
by stkcd repdt4;
    model ex_ret=ex_mktret;
    model ex_ret=rmrf_tmv smb_tmv hml_tmv;
    *model ex_ret=smb_tmv hml_tmv mkt_lag1 mkt_lag2 mktret mkt_led1 mkt_led2;
where td_count between -236 and -36 ;
run;
dm ' cle log';
data capm1;set capm;where _model_='MODEL1' & _EDF_+_P_>60;
keep stkcd repdt4 Intercept ex_mktret;
rename Intercept=a0 ex_mktret=a1;
run;
data capm2;set capm;where _model_='MODEL2' & _EDF_+_P_>60;
keep stkcd repdt4 Intercept rmrf_tmv smb_tmv hml_tmv;
rename Intercept=b0 rmrf_tmv=b1 smb_tmv=b2 hml_tmv=b3;
run;
**********************************;
data capm_full;merge capm1 capm2 ;by stkcd repdt4;
run;

data ret;set est1;where td_count between -21 and 61;run;

proc sort data=ret; 	by stkcd repdt4;
/*don't force it to have capm below*/
data ar;merge ret capm_full ;by stkcd repdt4;
ar1=ex_ret-(a1*ex_mktret+a0); 
ar2=ex_ret-(b1*rmrf_tmv+b2 *smb_tmv+b3*hml_tmv+b0); 
keep ar: stkcd repdt4 td_count ret ex_ret;
run;
/*data clean, lots of missing ar1 from the most recent year*/
proc sort data=ar out=ar1;
by stkcd repdt4;where ar1>-1 & ar2>-1;run;

%macro car(x);
proc sql;
create table car1(drop=max min)
	as select stkcd, repdt4,max(td_count) as max,min(td_count) as min,
	exp(sum(log(ret+1)))-1 as car1_0,
	exp(sum(log(ar1+1)))-1 as car1_1,exp(sum(log(ar2+1)))-1 as car1_2
	from &x
	where -1<=td_count<=1
	group by stkcd, repdt4
	having min=-1 & max=1;

create table car2(drop=max min)
	as select stkcd, repdt4,max(td_count) as max,min(td_count) as min,
	exp(sum(log(ret+1)))-1 as car5_0,
	exp(sum(log(ar1+1)))-1 as car5_1,exp(sum(log(ar2+1)))-1 as car5_2
	from &x
	where -5<=td_count<=5
	group by stkcd, repdt4
	having min=-5 & max=5;

create table car3(drop=max min)
	as select stkcd, repdt4,max(td_count) as max,min(td_count) as min,
	exp(sum(log(ret+1)))-1 as carbef_0,
	exp(sum(log(ar1+1)))-1 as carbef_1,exp(sum(log(ar2+1)))-1 as carbef_2
	from &x
	where -5<=td_count<=1
	group by stkcd, repdt4
	having min=-5 & max=1;
create table car4(drop=max min)
	as select stkcd, repdt4,max(td_count) as max,min(td_count) as min,
	exp(sum(log(ret+1)))-1 as caraft_0,
	exp(sum(log(ar1+1)))-1 as caraft_1,exp(sum(log(ar2+1)))-1 as caraft_2
	from &x
	where -1<=td_count<=20
	group by stkcd, repdt4
	having min=-1 & max=20;

   create table runup(drop=max min)
   as select stkcd, repdt4,max(td_count) as max,min(td_count) as min,
exp(sum(log(ret+1)))-1 as runup_0,
exp(sum(log(ar1+1)))-1 as runup_1,exp(sum(log(ar2+1)))-1 as runup_2
    from &x 
   where -20<=td_count<=-1
group by stkcd, repdt4
having min=-20 & max=-1;
   create table markup(drop=max min)
   as select stkcd, repdt4,max(td_count) as max,min(td_count) as min,
exp(sum(log(ret+1)))-1 as markup_0,
exp(sum(log(ar1+1)))-1 as markup_1,exp(sum(log(ar2+1)))-1 as markup_2
   from &x 
   where 0<=td_count<=60
group by stkcd, repdt4
having min=0 & max=60;
*select avg(max) from markup1;
quit;
%mend;
%car(ar1);
data Car;merge car1-car4 runup markup;by stkcd repdt4;
run;

*************for reg, can get multiple month controls, but watch for silent period;
proc sql;
create table analysis
   as select a.*,b.*
    from car as a join coblog.temp0720 as b
   on a.stkcd=b.stkcd and intck('month',a.repdt4,b.ym)=-2;
proc export data=analysis
outfile= "H:\crash\input\anc_full.dta"
DBMS= stata REPLACE;
Run;

data anc;set xueqiu.day_ret;

coblog.temp0720;
