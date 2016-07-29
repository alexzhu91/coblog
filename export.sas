libname restrict "B:\rollbeta\result\restricted" ;
libname  full "B:\rollbeta\result\full";

libname printlib 'SAS-data-library';
libname proclib 'SAS-data-library';
proc datasets library=proclib memtype=data nolist;
   copy out=printlib;
      select delay internat;
run;
options nodate pageno=1 linesize=80 pagesize=60;

%macro printall(libname,worklib=work);

   %local num i;

   proc datasets library=&libname memtype=data nodetails;
      contents out=&worklib..temp1(keep=memname) data=_all_ noprint;
   run;

   data _null_;
      set &worklib..temp1 end=final;
      by memname notsorted;
      if last.memname;
      n+1;
      call symput('ds'||left(put(n,8.)),trim(memname));
      if final then call symput('num',put(n,8.));

   run;

   %do i=1 %to &num;
PROC exPORT data=&libname..&&ds&i(keep=parameter estimate probt)
outfile= "B:\Dropbox\strat\rollbeta\fmb\&libname.\&&ds&i."
DBMS= EXCEL REPLACE;
sheet="&&ds&i";
Run;

   %end;
%mend printall;

options nodate pageno=1 linesize=70 pagesize=60;
%printall(restrict);
%printall(full);

PROC exPORT data=restrict.beta(keep=parameter estimate probt)
outfile= "B:\Dropbox\strat\rollbeta\full\beta"
DBMS= EXCEL REPLACE;
Run;
