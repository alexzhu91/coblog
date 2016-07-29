*after discuss with YUkun,introduce lots of new measures;
data p5w;set p5w.v;ym=mdy(month(date_ask),1,year(date_ask));keep stkcd user_ask ym;
where user_ask not contains 'ä¯ÀÀÓÃ»§';run; 
/*For data month_com_liulan;

data p5w;set p5w.v;ym=mdy(month(date_ask),1,year(date_ask));keep stkcd user_ask ym;
run; 
*/
option mprint;
%let data=p5w;
%let time=ym;
%let user=user_ask;

proc sql;
create table stk_&data as
select &time,stkcd,count(distinct &user) as num_user_&data,count(&user) as num_cmt_&data
from &data
group by &time, stkcd 
order by &time, stkcd;

*discuss one stk only count one time per ym;
create table distinct_user as
select distinct &time, &user,stkcd
from &data;
/*proc sort data=&data out=distinct_user nodupkey; by ym stkcd user_ask; run;*/

/*how many stk per user dist_stk, co_i is a property of investor, but still not consider if the 
stks are the same compared with previous, how this rotates
simply summ up the diverse wrong, */
create table user_stk as
select &time,&user,count(distinct stkcd) as dist_stk,(count(distinct stkcd)>1) as co,
(count(distinct stkcd)>2) as co2,(count(distinct stkcd)>3) as co3
from &data
group by &time, &user ;

create table user_stk_yr as
select year(&time) as year,&user,count(distinct stkcd) as dist_stk_yr
from &data
group by &user,calculated year;
*theory shld use distinct stk per year, 0726version use yr t-1, but now I use current year to be more
comparable;
create table user_stk_final as
select a.*,b.dist_stk_yr
from  user_stk a left join user_stk_yr b on a.&user=b.&user and year(a.&time)=b.year
order by &time, &user ;
/*
create table t as
select year(&time) as year,&user,count(distinct month(&time)) as dist_month_user
from &data
group by &user,calculated year
order by &user,calculated year;
proc means   n mean p50 std min p10  p90 max;
var dist_month_user;
run;
proc means data=user_stk_yr  n mean p50 std min p10  p90 max;
var dist_stk_yr;
run;
*/

proc sort data=distinct_user;
by &time &user ;
run;
*this differ from last version v1, since user_stk_final (join) requires at least one year before that, 
so left join!
join cut obs by 2/3;
data v1;
merge distinct_user user_stk_final(in=a);
by &time &user ;if a;
run;
*lots of diverse missing in this sample;
proc sql;
create table v1_sum as
select &time, stkcd,sum(dist_stk/dist_stk_yr) as diverse, 
avg(dist_stk/dist_stk_yr) as diverse_avg, sum(co) as co_&data, sum(co2) as co2_&data,
 sum(co3) as co3_&data,avg(dist_stk) as dist_stk_&data label="avg #distinct stk per stk@t" 
from v1
group by &time, stkcd ;
/*try EW & VW of #links;
create table link_m as
select &time, stkcd,sum(num) as link_sum  label="Total#links per stk" , 
avg(num) as link_avg  label="avg # links per stk" , count(connect) as link_stk label="#distinct stk per stk" 
from p5w.cc_sum
group by &time, stkcd 
order by &time, stkcd ;

proc means  n mean p50 std min p10 p90 max ;
var _numeric_;
run;
proc means data=v1_sum n mean p50 std min p10 p90 max ;
var diverse;
format diverse 5.2;
run;
*/

data stk1_&data;
merge v1_sum stk_&data link_m;
by &time stkcd ;
where &time ne .;
run;
proc sort data=stk1_p5w;by stkcd ym;
proc sort data=coblog.temp0720;by stkcd ym;
data month_com;
*data month_com_liulan;
merge stk1_p5w coblog.temp0720(in=c drop=co_p_r co_p5w ) ;
by stkcd ym;if c;
nodiverse=(diverse=.);
*stk_p5w has all positive discussion, so need to replace all 0s;
if year(ym)>2009;
	array CO diverse: link: dist_stk_p5w co_p5w co2_p5w co3_p5w num_user_p5w ;
	do over CO;
	if CO=. then CO=0;
	end;
	if num_user_p5w ne 0 then do;
		co_p_r=co_p5w/num_user_p5w;co2_p_r=co2_p5w/num_user_p5w;co3_p_r=co3_p5w/num_user_p5w;
		one=1-co_p_r;two=co_p_r-co2_p_r;three=co2_p_r-co3_p_r;
	end;
	else do;
		co_p_r=0;co2_p_r=0;co3_p_r=0;one=0;two=0;three=0;
	end;
	single=num_user_p5w-co_p5w;two_num=co_p5w-co2_p5w;three_num=co2_p5w-co3_p5w;
	two_three=two_num+three_num;*original # is right;
nodiverse=(diverse=.);
lndiverse=log(1+diverse);
dist_stk_p=log(1+dist_stk_p5w);
run;
proc means  n mean std min max;
var diverse diverse_avg link:;
run;

proc sort nodupkey;by stkcd ym;
*since monthly, only lag 3 month to see the trend=8 weeks
real trend is not obvious, only impulse;
proc expand data=month_com  out=month_com1 method = none; 
  by stkcd;
  id ym; 
	convert beta = beta_lag / transformout=(lag 1); 
	convert ret = ret_led / transformout=(lead 1); 
	convert num_user_p5w = max  / transformout=(MOVMax  4 trimleft 3);
	convert num_user_p5w = med0   / transformout=(MOVMed  4 trimleft 3);
	convert dist_stk_p = med1   / transformout=(MOVMed  4 trimleft 3);
	convert link_stk = med2   / transformout=(MOVMed  4 trimleft 3);
	convert link_sum = med3   / transformout=(MOVMed  4 trimleft 3);
	convert diverse_avg = med4   / transformout=(MOVMed  4 trimleft 3);
run;
data coblog.month_com;set month_com1;
num_user_p5w=log(1+num_user_p5w)-log(1+med0);
dist_stk_p=log(1+dist_stk_p)-log(1+med1);
link_stk=log(1+link_stk)-log(1+med2);
link_sum=log(1+link_sum)-log(1+med3);
diverse_avg=log(1+diverse_avg)-log(1+med4);
run;
PROC exPORT data=coblog.month_com
outfile= "H:\crash\input\month_com.dta"
DBMS= stata REPLACE;
Run;

   /*-- Durbin-Watson test for autocorrelation , all have a stong 1st order
we see adjusting really reduce autocor and Rsq--*/
   proc autoreg data=coblog.month_com;
      *model diverse_avg = ym / dw=1 dwprob;
      model link_stk = ym / dw=1 dwprob;
      *model num_user_p5w = ym / dw=1 dwprob;
	  where stkcd='000002';
   run;



*coblog.month_com;
*restricted;
proc reg data=coblog.month_com ;
 model beta = beta_lag nodiverse lndiverse lnsize turnover bm;
 *add noq will lower diverse;
run;


/*FMB no result for diverse*/
proc sort data=liulan;by ym;
proc reg outest=est  noprint edf ;;
by ym;
 model beta = beta_lag lndiverse lnsize turnover bm;
run;
proc means data=est mean std t probt;
var lndiverse ;
run;



*********************************test return, not much prediciton even for diverse icld 0;

data delay1;set coblog.month_com;if max;
*if rep_month ne .;
*if rep_month=.;
*if rep_month ne 1;*sample control!!!;
lnsize=log(size);
if bm>0 then bm=log(bm+1);
else delete;
run;
proc sort data=delay1; by ym; run;
proc reg data=delay1 outest=est_beta  noprint edf ;
by ym;
 model ret_led = diverse lnsize turnover bm;
run;

proc means data=est_beta mean std t probt;
var diverse ;
*var nodiverse ;
run;
************compare how this measure is in the main sample vs the diluted;
proc means data=coblog.month_com n mean p50 std min p10 p90 max ;
var dist_stk_p5w ;
run;
***H:\crash\input\month_com_res is main sample with max you can choose how to limit the sample;
proc means data=p5w.stk_link14 n mean p50 std min p10 p90 max ;
var _numeric_;
run;
*potential fault:data update wrong;
