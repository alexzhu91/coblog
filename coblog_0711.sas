/*most recent and correct for the co_num> user_num problem*/
option mprint;
%macro coblog(data,time,user);
proc sql;
create table stk_&data as
select &time,stkcd,count(distinct &user) as num_user_&data,count(&user) as num_cmt_&data
from &data
group by &time, stkcd ;

create table distinct_user as
select distinct &time,stkcd, &user
from &data;
/*proc sort data=&data out=distinct_user nodupkey; by ym stkcd user_ask; run;*/

/*how many stk per user dist_stk*/
create table user_stk as
select &time,&user,count(distinct stkcd) as dist_stk,(count(distinct stkcd)>1) as co
from &data
group by &time, &user ;
*下面不一定取得那一天co_blog的人，只要该人曾经co_blog了就算;
/*create table stk_coblog as*/
/*select &time, stkcd, count(&user) as co_blog*/
/*from &data where &user in (select &user from user_stk)*/
/*group by &time, stkcd ;*/
proc sort data=distinct_user;
by &time &user ;
run;

data v1;
merge distinct_user user_stk;
by &time &user ;
run;

*co: user is co_blogger or not,v1 contains 浏览用户;
proc sql;
create table v1_sum as
select &time, stkcd,sum(co) as co_&data, avg(dist_stk) as dist_stk_&data label="avg #distinct stk per stk@t" 
from v1
group by &time, stkcd ;

data stk_&data;
merge v1_sum stk_&data;
by &time stkcd ;
if &time ne .;
run;
%mend;
%coblog(p5w,ym,user_ask);
data p5w;set p5w.v;ym=mdy(month(date_ask),1,year(date_ask));keep stkcd user_ask ym;where user_ask not contains '浏览用户';run; 

data;set stk;if co_num>num_user_p5w;run;

proc sort data=v1 nodupkey; by ym stkcd user_ask; run;

proc sql;
create table distinct_user as
select distinct ym,stkcd, user_ask
from p5w;

********************additional for hot num;


proc means data=user_stk mean noprint;
var dist_stk;
class &time  ;
output out=t mean=mean; 
run;

*above is avg #cmts for all stk per month,mean is 1 per day,same as co_blog num calc;
data user_stk;
merge user_stk t;
by &time ;
hot=(dist_stk>mean);run;
data v1;
merge v1 user_stk(keep=&time &user hot);
by &time &user ;
run;

*hot: user is above median,v1 contains 浏览用户;
proc sql;
create table v1_sum_hot as
select &time, stkcd,sum(hot) as hot_num from v1
group by &time, stkcd ;	
