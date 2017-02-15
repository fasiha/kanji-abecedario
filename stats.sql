-- Some SQL for numbers in help.html.
select count(*) from targets where primitive=1 and kanji=0;
select count(*) from targets where primitive=1;
select count(*) from targets ;
