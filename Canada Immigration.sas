/* Access Data */
%let path=/home/u49347396/IMM_CA/data;
libname imm "&path";
options validvarname=v7;

proc import datafile="&path/CRS_Score.csv" dbms=csv out=imm.crs replace;
	guessingrows=max;
run;

proc import datafile="&path/Study_cleaned.xlsx" dbms=xlsx out=imm.study replace;
run;

proc import datafile="&path/Study_NA.xlsx" dbms=xlsx out=imm.study_na replace;
run;

proc import datafile="&path/IRCC_Origincleaned.xls" dbms=xls out=imm.origin 
		replace;
run;

/* Explore Data */
proc contents data=imm.crs;
run;

proc contents data=imm.study;
run;

proc contents data=imm.study_na;
run;

proc contents data=imm.origin;
run;

/* Preparing Data_1*/
data imm.crs_new;
	set imm.crs;
	rename 'CRS_score_of_lowest_ranked_candi'n=crs_lowest;
	Immigration_program=propcase(Immigration_program);
run;

/* Preparing Data_2 */
/* Convert Character variables into Numeric variables to operate the culculation */
data imm.study_new;
	set imm.study;
	Secon_less=input(Secondary_or_less, 20.);
	Post=input(Post_Secondary, 20.);
	Others=input(Other_Studies, 20.);
	N_stated=input(Study_level_not_stated, 20.);
	Total_new=input(Total, 20.);
	keep Secon_less Post Others N_Stated Province_territory Year Total_new;
run;

/* Preparing Data_3 */
data imm.new_origin (keep=Y2019_new Country);
	set imm.origin (rename=(U=Y2019));

	if Country_of_Citizenship="Total unique persons" then
		delete;
	Country=scan(Country_of_Citizenship, 1, ",");
	Y2019_new=input(Y2019, 20.);
run;

/* Create a plot to show the total number of invitations for each program since 2015 */
proc freq data=imm.crs_new (rename=(Immigration_program=Programs));
	tables Programs*Year / nocol nocum norow nopercent 
		plots=freqplot (twoway=stacked orient=horizontal);
run;

/* Create a connect plot data points to present the score trend of each program since 2015 */
options orientation=landscape;

/* Set the graphics environment */
goptions border cback=aliceblue htitle=15pt;

/* Define title and footnote */
title 'Trend of CRS score since 2015';
footnote '';

/* Define symbol characteristics */
symbol1 color=bippk interpol=join value=squarefilled width=1.5;
symbol2 color=gold interpol=join value=squarefilled width=1.5;
symbol3 color=limegreen interpol=join value=squarefilled width=1.5;
symbol4 color=dodgerblue interpol=join value=squarefilled width=1.5;

/* Define axis characteristics */
axis1 value=('2015' '2016' '2017' '2018' '2019' '2020' '2021') 
	label=("Date of Invitation") offset=(3, 3);
axis2 order=(200 to 1000 by 100) label=("CRS Score") offset=(2, 0);

/* Generate plot */
proc gplot data=imm.crs_new;
	plot crs_lowest*month_year=Immigration_program/ haxis=axis1 vaxis=axis2 
		hminor=0 vminor=0 vref=200 300 400 500 600 700 800 900 lvref=25 cvref=black;
	run;
quit;

/* Analysis Total Study Permit Holders and the Secondary Study Level */
proc sort data=imm.study_new out=imm.sorted_study;
	by Year;
run;

proc means data=imm.sorted_study sum;
	var Secon_less;
	class Year;
	output sum=out=imm.Second;
run;

proc means data=imm.sorted_study sum;
	var Post;
	class Year;
	output sum=out=imm.Post;
run;

proc means data=imm.sorted_study sum;
	var Others;
	class Year;
	output sum=out=imm.Others;
run;

proc means data=imm.sorted_study sum;
	var N_stated;
	class Year;
	output sum=out=imm.N_stated;
run;

data imm.combined_study;
	merge imm.Second imm.Post imm.Others imm.N_stated;
	by Year;

	if missing(Year) then
		delete;
	keep Year Secon_less Post Others N_Stated;
run;

/* Sum permits for all study levels by Year */
data imm.totalnew;
	set imm.sorted_study;
	by Year;

	if first.Year then
		Yeartotal=0;
	Yeartotal + Total_new;

	if last.Year;
	keep Year Yeartotal;
run;

/* Culculate the total permits PLUS province not stated */
proc sort data=imm.study_na out=imm.sorted_NA (drop=C D);
	by Year;
run;

data imm.study_total (rename=(Province___Territory_not_stated=Not_stated));
	merge imm.totalnew imm.sorted_NA imm.combined_study;
	by Year;

	if missing(Year) then
		delete;
run;

/* Calculate the ratio of Post Secondary in total permits by Year */
data imm.year_total;
	set imm.study_total;
	by Year;
	Y_total=Not_stated+Yeartotal;
	Post_rate=Post/Y_total;
	format Y_total Secon_less Post Others comma8.;
	keep Year Y_total Post_rate;
	format Post_rate Sec_rate Other_rate N_rate percent8.;
run;

/* Create a bar chart to present the trend of the total study permits since 2000 */
options orientation=landscape;

/* Set the graphics environment */
goptions border cback=lightskyblue htitle=15pt htext=10pt;

/* Define title and footnote */
title 'Total Study Permits and Post Secondary Ratio';
footnote '';

/* Generate plot */
proc sgplot data=imm.year_total (rename=(Y_total=Study_Permit_Numbers 
		Post_rate=Post_Secondary_Ratio)) noborder;
	vbar Year / response=Study_Permit_Numbers stat=sum clusterwidth=1 datalabel 
		dataskin=matte barwidth=0.6;
	vline Year / response=Post_Secondary_Ratio y2axis nostatlabel;
	xaxis display=all;
	yaxis display=all values=(100000 200000 300000 400000 500000 600000 700000);
	format Study_Permit_Numbers comma8.;
run;

/* Find out top 3 provinces with study level of Post Secondary since 2010 */
proc sort data=imm.sorted_study;
	by Year descending Post;
run;

data imm.top3_byYear;
	do i=1 by 1 until (last.Year);
		set imm.sorted_study (where=(Year in (2010, 2011, 2012, 2013, 2014, 2015, 
			2016, 2017, 2018, 2019)));
		by Year descending Post;

		if i<=3 then
			output;
		format Post comma20.;
		keep Province_territory Year Post;
	end;
run;

/* Create a plot with subgroup for the top 3 province with the study level of Post Secondary by Year */
goptions reset=all cback=aliceblue border htitle=12pt htext=10pt;
title 'Top 3 Provinces with most Post Secondary Permit since 2010' height=9pt 
	justify=center;
axis1 value=none label=none offset=(2, 2);
axis2 label=(angle=90 "Study Permits") order=(10000 to 250000 by 20000) 
	minor=none;
axis3 label=none;
legend1 order=('Ontario' 'British Columbia' 'Quebec')frame;

proc gchart data=imm.top3_byyear;
	vbar Province_territory / descending subgroup=Province_territory group=Year 
		sumvar=Post legend=legend1 space=0.4 gspace=1 maxis=axis1 raxis=axis2 
		gaxis=axis3 width=2;
	run;
quit;

/* Explore the top 5 origin countries for Canadian Immigrants */
proc print data=imm.origin (keep=U Country_of_Citizenship);
	where Country_of_Citizenship="Total unique persons";
run;

proc sort data=imm.new_origin out=imm.sorted_origin;
	by descending Y2019_new;
run;

data imm.sorted5;
	set imm.sorted_origin (obs=221);

	if missing(Country) or missing(Y2019_new) then
		delete;
	percent=Y2019_new/642480;
run;

proc format;
	picture perfmt 0-high='000.00%';
run;

goptions cback=aliceblue border htitle=12pt htext=10pt;
title 'Canada Study Permit Holders by Country of Citizenship in 2019';

proc gchart data=imm.sorted5;
	format Y2019_new comma20.;
	pie Country / sumvar=percent coutline=black explode='India' other=3.7 
		othercolor=antiquewhite woutline=1 value=arrow cfill=cornflowerblue noheading;
	format percent perfmt.;
	run;
quit;