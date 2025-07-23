--PROJECT NAME  - IPL STRATERGY 
--SKILL USED    - SQL 
--TOOL 		    - MySQL Workbench 
--SUBMISSION BY - SUHAS J 

--TABLES 

select * from ball_by_ball;
select * from batting_style;
select * from bowling_style;
select * from city;
select * from country;
select * from extra_runs;
select * from extra_type;
select * from matches;
select * from out_type;
select * from outcome;
select * from player;
select * from player_match;
select * from rolee;
select * from season;
select * from team;
select * from toss_decision;
select * from umpire;
select * from venue;
select * from wicket_taken;
select * from win_by;


--OBJECTIVE QUESTIONS 

--1. Datatype in  “ball_by_ball” (using information schema)

select 
	column_name,
    data_type
from 
	information_schema.columns
where 
	table_name = 'ball_by_ball' 
    and 
    table_schema = 'ipl';

--2. Runs Scored by RCB in initial season (Includes extra runs)

select 
	'RCB' as Team_Name,
    m.Season_Id,
    s.Season_Year,
    sum(b.Runs_Scored) as Runs_Scored,
    sum(er.Extra_Runs) as Extra_Runs,
    (sum(b.Runs_Scored) + sum(er.Extra_Runs)) as Total_Runs -- summing total runs and extra runs
from 
	ball_by_ball b left join matches m 
    on b.match_id = m.match_id 
    left join extra_runs er 
    on b.match_id = er.Match_Id
    and b.Innings_No = er.Innings_No
    and b.Over_Id = er.Over_Id
    and b.Ball_Id = er.Ball_Id
    left join season s 
    on m.Season_Id = s.Season_Id 
where 
	s.season_id  = (select min(Season_Id) from matches) -- Filtering Required Season 
    and 
    b.team_batting = 2-- Team ID for Royal Challengers Bengaluru
group by 
	m.Season_Id,
    s.Season_Year;
	

--3.Players above 25 years in 2014 season

select 
	count(distinct pm.player_id) as Players_Above_25_Years
from 
	season s join matches m 
    on s.season_id = m.season_id
    join player_match pm 
    on pm.match_id = m.match_id 
    join player p 
    on p.player_id = pm.player_id
where 
	s.season_year = 2014 -- filtering for required season
    and 
    (2014 - year(Dob)) > 25 ;-- players above 25 years
	
--4. matches won by RCB in 2013 season

select 
	t.Team_Name,
    s.Season_Year,
    count(Match_Id) as Total_Matches,
    sum(case when Match_Winner = 2 then 1 
		     else 0 end) as Matches_Won,
    round(sum(case when Match_Winner = 2 then 1 
				   else 0 end)*100/count(Match_Id),2) as Win_Percentage,
    sum(case when team_1 = 2 and team_1 = Match_Winner then 1   -- 2 represents RCB team_id
			 else 0 end) as Home_Wins,   
    sum(case when team_2 = 2 and team_1 != Match_Winner then 1 -- 2 represents RCB team_id
			else 0 end) as Away_Wins 
from 
	team t join matches m 
    on t.Team_Id = m.Team_1 
    or t.Team_Id = m.Team_2
    left join season s 
    on m.Season_Id = s.Season_Id
where 
	s.Season_Year = 2013
    and 
    t.Team_Name = 'Royal Challengers Bangalore';
	

--5. Top 10 players according to their strike rate in the last 4 seasons

with  strike_rate_dt as (
select 
	p.Player_Name,
    round(sum(b.Runs_Scored)/count(b.Ball_Id)*100,2) as Strike_Rate,
    dense_Rank() over(order by round(sum(b.Runs_Scored)/count(b.Ball_Id)*100,2) desc) as dnk
from 
	player p join player_match pm 
    on p.player_id = pm.player_id 
    join ball_by_ball b 
    on b.match_id = pm.Match_Id
    and b.Striker = p.Player_Id
    left join matches m 
    on m.Match_Id = b.Match_Id
    left join season s 
    on s.Season_Id = m.Season_Id
where 
	s.season_year between (select max(season_year)-3 from season) and (select max(season_year) from season)
    -- filtering for 4 years from the latest edition wrt to data 
group by 
	p.Player_Name
having 
    count(b.Ball_Id) >= 60) -- players played atleast 60 balls 

select 
	Player_Name,
    Strike_Rate,
    dnk as 'Rank'
from 
	strike_rate_dt 
where 
	dnk <= 10; -- filtering players with top 10 strike rate


--6. Average runs scored by each batsman considering all the seasons

select 
	p.Player_Name,
    round(sum(b.runs_scored)/count(wc.Player_Out),2) as Avg_Runs
from 
	player p join ball_by_ball b 
    on p.Player_Id = b.Striker
    left join wicket_taken wc 
    on p.Player_Id = wc.Player_Out
    and wc.Match_Id = b.Match_Id
    and wc.Innings_No = b.Innings_No
    and wc.over_id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
group by 
    p.Player_Name
having 
	count(distinct b.match_id) >= 25  -- played at least 25 matches
order by 
	avg_runs desc;


--7. Average wickets taken by each bowler considering all the seasons 

--# Match wise average 
select 
	p.Player_Name,
    round(sum(case when wc.player_out is null then 0 else 1 end)/count(distinct b.match_id),2) as Avg_Wickets
from 
	ball_by_ball b join player p 
    on b.bowler = p.player_id
	left join wicket_taken wc 
    on wc.Match_Id = b.Match_Id
    and wc.Over_Id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
    and wc.Innings_No = b.Innings_No
    left join matches m 
    on m.Match_Id = b.Match_Id
    left join out_type o 
    on o.Out_Id = wc.Kind_Out
where 
	o.Out_Name not in ('run out', 'retired hurt', 'hit wicket', 'obstructing the field')
group by 
	p.Player_Name
having 
	count(distinct b.match_id) >= 10
order by 
	avg_wickets desc;
	
	
--#Season Wise average

with wickets_dt as (select 
	p.player_name,
	m.season_id,
    sum(case when wc.player_out is null then 0 else 1 end) as ttl_wickets
from 
	ball_by_ball b join player p 
    on b.bowler = p.player_id
	left join wicket_taken wc 
    on wc.Match_Id = b.Match_Id
    and wc.Over_Id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
    and wc.Innings_No = b.Innings_No
    left join matches m 
    on m.Match_Id = b.Match_Id
    left join out_type o 
    on o.Out_Id = wc.Kind_Out
where 
	o.Out_Name not in ('run out', 'retired hurt', 'hit wicket', 'obstructing the field')
group by 
	p.player_name,
    m.Season_Id)
select 
	Player_Name,
    round(avg(ttl_wickets),2) as Avg_Wickets
from 
	wickets_dt 
group by 
	player_name 
order by 
	Avg_wickets desc;
	

--8.List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average

with avg_run_dt as ( -- Average runs scored by each player 
select 
	p.Player_Id,
    round(sum(b.runs_scored)/count(wc.Player_Out),2) as avg_runs
from 
	player p join ball_by_ball b 
    on p.Player_Id = b.Striker
    left join wicket_taken wc 
    on p.Player_Id = wc.Player_Out
    and wc.Match_Id = b.Match_Id
    and wc.Innings_No = b.Innings_No
    and wc.over_id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
group by 
    p.Player_Id
order by 
	avg_runs desc
),
wk_dt as ( -- wickets taken by rach player 
select 
	p.player_id,
    count(wc.player_out) as wickets
from 
	ball_by_ball b join player p 
    on b.bowler = p.player_id
	left join wicket_taken wc 
    on wc.Match_Id = b.Match_Id
    and wc.Over_Id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
    and wc.Innings_No = b.Innings_No
group by 
	p.player_id
),
overall_avg as -- calculating the entire data Average of runs and wickets
(select 
	round(avg(avg_runs),2) as aoa_runs,
    round(avg(wickets),2) aoa_wk
from 	
	avg_run_dt a join wk_dt b 
    on a.player_id = b.player_id)

-- Displaying the final results 
select 
	p.player_name as Player_Name,
    ard.avg_runs as Avg_Runs,
    wd.wickets as Wickets
from 
	avg_run_dt ard join wk_dt wd 
    on ard.player_id = wd.player_id 
    join player p 
    on p.player_id = ard.player_id
    cross join overall_avg oa
where 
	ard.avg_runs > oa.aoa_runs
    and 
    wd.wickets > oa.aoa_wk
order by 
	Player_Name,
    Wickets desc,
    Avg_Runs desc;
	

--9.Creating a table rcb_record table that shows the wins and losses of RCB in an individual venue.

DROP TABLE IF EXISTS rcb_record; -- Dropping table if already exists 
-- Creating table
CREATE TABLE rcb_record (
	Venue_Name varchar(75) PRIMARY KEY,
    Total_Matches int,
    Wins int,
    Loss int,
    Win_Percentage decimal(5,2),
    Loss_Percentage decimal(5,2)
);
-- Inserting Records through query
insert into rcb_record 
(select 
	v.venue_name as Venue_Name,
    count(*) as Total_Matches,
    sum(case when m.Match_Winner = 2 then 1 else 0 end) as Wins,
    sum(case when m.Match_Winner !=2 then 1 else 0 end) as Loss,
    round(sum(case when m.Match_Winner = 2 then 1 else 0 end)*100/count(*),2) as Win_Percentage,
    round(sum(case when m.Match_Winner !=2 then 1 else 0 end)*100/count(*),2) as Loss_Percentage
from 
	matches m join venue v 
    on m.venue_id = v.venue_id
    join team t 
    on t.team_id = m.team_1
    or t.team_id = m.team_2 
where 
	t.team_name = 'Royal Challengers Bangalore'
group by 
	v.venue_name);
select * from rcb_record; -- Querying the records from table created 



--10. Analyzing the impact of bowling style on wickets taken
select 
	bs.bowling_skill as Bowling_Style,
    count(wc.player_out) as Wickets
from 
	ball_by_ball b join player p 
    on b.bowler = p.player_id
	left join wicket_taken wc 
    on wc.Match_Id = b.Match_Id
    and wc.Over_Id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
    and wc.Innings_No = b.Innings_No
    join bowling_style bs 
    on bs.bowling_id = p.bowling_skill
    join out_type ot
    on wc.kind_out = ot.out_id
where 
	ot.out_name not in ('run out', 'retired hurt', 'hit wicket', 'obstructing the field')
group by 
	bs.bowling_skill
order by 
	wickets desc;


--11. Performance of RCB in the last 5 seasons

with runs_dt as ( -- Calculating the team runs 
select 
	t.Team_Name,
    s.Season_Id,
    s.Season_Year, 
    sum(Runs_Scored) as Total_Runs
from 
	team t join ball_by_ball b 
    on b.Team_Batting = t.Team_Id
    join matches m 
    on m.Match_Id = b.Match_Id
    join season s 
    on s.Season_Id = m.Season_Id
where 
	t.Team_Name = 'Royal Challengers Bangalore'
group by 
	t.Team_Name,
    s.Season_Id,
    s.Season_Year)
,wickets_dt as ( -- Calculating the team wickets 
select 
	t.Team_Name,
    s.Season_Id,
    s.Season_Year, 
    count(wt.Player_Out) as Total_Wickets
from 
	team t join ball_by_ball b 
    on b.Team_Bowling = t.Team_Id
    join matches m 
    on m.Match_Id = b.Match_Id
    left join wicket_taken wt 
    on b.match_id = wt.match_id 
    and b.Innings_No = wt.Innings_No
    and b.Over_Id = wt.Over_Id
    and b.Ball_Id = wt.Ball_Id
    join season s 
    on s.Season_Id = m.Season_Id
where 
	t.Team_Name = 'Royal Challengers Bangalore'
group by 
	t.Team_Name,
    s.Season_Id,
    s.Season_Year),
final_dt as -- combining all the records 
(select 
	rd.Team_Name,
    rd.Season_Id,
    rd.Season_Year,
    rd.Total_Runs,
    wd.Total_Wickets
from
	runs_dt rd join wickets_dt wd
	on rd.Season_Id = wd.Season_Id)
    
select 
	f.Team_Name,
    f.Season_Id,
    f.Season_Year,
    f.Total_Runs,
    f.Total_Wickets,
    coalesce((case when f.total_runs > f2.total_runs and f.total_wickets > f2.total_wickets then 'Better at both'
		 when f.total_runs > f2.total_runs and f.total_wickets < f2.total_wickets then 'Better at runs, worse at wicktes'
         when f.total_runs < f2.total_runs and f.total_wickets > f2.total_wickets then 'Worse at runs, Better at wicktes'
         when f.total_runs < f2.total_runs and f.total_wickets < f2.total_wickets then 'Worse at both'
		end),'') as 'Comment'
from 
	final_dt f left join  final_dt f2 
	on f2.Season_Id = f.Season_Id - 1 -- joining with previuos year 
    and f2.Season_Year = f.Season_Year-1; -- joining with previuos season 
	

--12.KPIs for the team strategy

--# Team KPI 
select 
	count(*) as Total_Matches_Played,
    sum(case when Match_Winner = 2 then 1 else 0 end) as Total_Matches_Won,
    round(sum(case when Match_Winner = 2 then 1 else 0 end)*100/count(*),2) as Total_Match_Won_Percentage,
    sum(case when Toss_Winner = 2 then 1 else 0 end) as Total_Toss_Won,
    round(sum(case when Toss_Winner = 2 then 1 else 0 end)*100/count(*),2) as Total_Toss_Won_Percentage,
    sum(case 
		when toss_winner = 2 and Match_Winner = 2 
		then 1 else 0 end) as Matches_Won_By_Toss_Decision,
    round(sum(case 
		when toss_winner = 2 and Match_Winner = 2 
		then 1 else 0 end)*100/sum(case when Toss_Winner = 2 then 1 else 0 end),2) as Matches_Won_By_Toss_Decision_Percentage
from 
	matches
where 
	team_1 = 2 -- RCB team_id 
    or 
    team_2 = 2; -- RCB team_id 


--# Scoring Composition Summary

select 
	round(sum(case when b.Runs_Scored = 0  then 1 else 0 end)*100/(count(*)),2) as Dot_Ball_Percentage,
	round(sum(case when b.Runs_Scored >=4  then 1 else 0 end)*100/(count(*)),2) as Boundary_Ball_Percentage,
    round(sum(case when b.Runs_Scored between 1 and 3  then 1 else 0 end)*100/(count(*)),2) as Run_Ball_Percentage
from 
	Ball_by_Ball b left join team t 
    on b.Team_Batting = t.Team_Id
where 
	t.Team_Name = 'Royal Challengers Bangalore';

--# Batting KPI
with cte as ( -- Calculating necesaary aggregation wrt to over and each match 
select
	b.match_id, 
	b.over_id,
	(case when b.over_id between 1 and 6 then 'Power Play'
		 when b.over_id between 7 and 15 then 'Middle Overs'
         when b.over_id between 16 and 20 then 'Slog Overs'
         end) as Overs ,
    sum(b.runs_scored) as ttl_runs,
    count(wc.player_out) as wickets,
    count(b.ball_id) as balls,
    sum(case when b.Runs_Scored = 0  then 1 else 0 end) as Dot_Ball,
    sum(case when b.Runs_Scored >= 4  then 1 else 0 end) as Boundary_Ball
from 
	ball_by_ball b join matches m 
    on b.Match_Id = m.Match_Id
	left join wicket_taken wc 
    on wc.Match_Id = b.Match_Id
    and wc.Innings_No = b.Innings_No
    and wc.over_id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
where 
	b.Team_Batting = (select team_id from team where team_name = 'Royal Challengers Bangalore')
group by 
	b.match_id,
    b.Over_Id),
entire_dt as ( -- aggregating the entire data agrregation 
	select 	   -- wrt to RCB Team 
		count(distinct match_id) as total_matches,
		sum(ttl_runs) as team_runs_scored,
        sum(wickets) as team_wickets_lost
	from 
		cte 
),
power_play_dt as ( -- Power Play Calculations (Overs between 1 and 6)
select 
	Overs as Over_Type,
    round(avg(rr),2) as Avg_Run_Rate,
    round(max(ttl_dot_ball)*100/max(ttl_pp_balls),2) as Dot_Ball_Percentage,
    round(max(ttl_bb_ball)*100/max(ttl_pp_balls),2) as Boundary_Ball_Percentage,
	round(max(ttl_pp_runs)*100/max(ttl_pp_balls),2) as Batting_Strike_Rate,
    round(max(ttl_pp_runs)*100/(select team_runs_scored from entire_dt),2) as Run_Scored_Percentage,
	round(sum(wickets)*100/(select team_wickets_lost from entire_dt),2) as Wickets_Lost_Percentage
from(
	select 
		over_id,
		overs,
		wickets,
        sum(Dot_Ball) over() as ttl_dot_ball,
		sum(Boundary_Ball) over() as ttl_bb_ball,
		sum(ttl_runs) over() as ttl_pp_runs,
		sum(balls) over() as ttl_pp_balls,
		(case when over_id = 6 then sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
													rows between unbounded preceding and current row)/6
			 else null end) as rr
	from 
		cte 
	where 
		over_id <= 6)a
group by 	
	overs),
middle_overs_dt as ( -- Middle overs Calculations for Overs between 7 and 15 
select 
	Overs as Over_Type,
    round(avg(rr),2) as Avg_Run_Rate,
    round(max(ttl_dot_ball)*100/max(ttl_mo_balls),2) as Dot_Ball_Percentage,
    round(max(ttl_bb_ball)*100/max(ttl_mo_balls),2) as Boundary_Ball_Percentage,
	round(max(ttl_mo_runs)*100/max(ttl_mo_balls),2) as Batting_Strike_Rate,
    round(max(ttl_mo_runs)*100/(select team_runs_scored from entire_dt),2) as Run_Scored_Percentage,
	round(sum(wickets)*100/(select team_wickets_lost from entire_dt),2) as Wickets_Lost_Percentage

from(
	select 
		over_id,
		overs,
		wickets,
        sum(Dot_Ball) over() as ttl_dot_ball,
		sum(Boundary_Ball) over() as ttl_bb_ball,        
		sum(ttl_runs) over() as ttl_mo_runs,
		sum(balls) over() as ttl_mo_balls,
		(case when over_id = 15 then sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
														rows between unbounded preceding and current row)/9
			 else null end) as rr
	from 
		cte 
	where 
		over_id between 7 and 15)a
group by 	
	overs),
slog_overs_dt as ( -- solg over calculation for overs between 16 - 20 
select 
	Overs as Over_Type,
    round(avg(rr),2) as Avg_Run_Rate,
    round(max(ttl_dot_ball)*100/max(ttl_so_balls),2) as Dot_Ball_Percentage,
    round(max(ttl_bb_ball)*100/max(ttl_so_balls),2) as Boundary_Ball_Percentage,
    round(max(ttl_so_runs)*100/max(ttl_so_balls),2) as Batting_Strike_Rate,
    round(max(ttl_so_runs)*100/(select team_runs_scored from entire_dt),2) as Run_Scored_Percentage,
	round(sum(wickets)*100/(select team_wickets_lost from entire_dt),2) as Wickets_Lost_Percentage    
from(
	select 
		over_id,
		overs,
		wickets,
        sum(Dot_Ball) over() as ttl_dot_ball,
		sum(Boundary_Ball) over() as ttl_bb_ball,          
		sum(ttl_runs) over() as ttl_so_runs,
		sum(balls) over() as ttl_so_balls,
		(case when over_id = 20 then sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
													  rows between unbounded preceding and current row)/5
			 else null end) as rr
	from 
		cte 
	where 
		over_id between 16 and 20)a
group by 	
	overs)

select * from power_play_dt
union 
select * from middle_overs_dt
union 
select * from slog_overs_dt

--# Bowling KPI 
with cte as ( -- Calculating aggregation wrt to over and each match 
select
	b.match_id, 
	b.over_id,
	(case when b.over_id between 1 and 6 then 'Power Play'
		 when b.over_id between 7 and 15 then 'Middle Overs'
         when b.over_id between 16 and 20 then 'Slog Overs'
         end) as Overs ,
    sum(b.runs_scored) as ttl_runs,
    count(wc.player_out) as wickets,
    count(b.Ball_Id) as balls,
	sum(case when b.Runs_Scored = 0  then 1 else 0 end) as Dot_Ball,
    sum(case when b.Runs_Scored >= 4  then 1 else 0 end) as Boundary_Ball
from 
	ball_by_ball b left join matches m 
    on b.Match_Id = m.Match_Id
	left join wicket_taken wc 
    on wc.Match_Id = b.Match_Id
    and wc.Innings_No = b.Innings_No
    and wc.over_id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
where 
	b.Team_Bowling = (select team_id from team where team_name = 'Royal Challengers Bangalore')
group by 
	b.match_id,
    b.Over_Id),
entire_dt as (  -- aggregating the entire data agrregation 
	select 		-- wrt to RCB team 
		sum(ttl_runs) as team_runs_conceded,
        sum(wickets) as team_wickets_taken
	from 
		cte
),
power_play_dt as -- Power Play Calculations for Overs between 1 and 6
(select 
	overs as Over_Type,
    round(avg(rr),2) as Avg_Economy,
	round(max(ttl_dot_ball)*100/max(ttl_pp_balls),2) as Dot_Ball_Percentage,
    round(max(ttl_bb_ball)*100/max(ttl_pp_balls),2) as Boundary_Ball_Percentage,
    round(max(ttl_pp_balls)/(sum(wickets)),2) as Bowling_Strike_Rate,
	round(sum(wickets)*100/(select team_wickets_taken from entire_dt),2) as Wickets_taken_percentage,
    round(max(ttl_pp_rc)*100/(select team_runs_conceded from entire_dt),2) as Runs_conceded_percentage
from(
	select 
		over_id,
		overs,
		wickets,
		sum(Dot_Ball) over() as ttl_dot_ball,
		sum(Boundary_Ball) over() as ttl_bb_ball,
		sum(ttl_runs) over () as ttl_pp_rc,
		sum(balls) over() as ttl_pp_balls,
		(case when over_id = 6 then sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
													rows between unbounded preceding and current row)/6
			 else null end) as rr
	from 
		cte 
	where 
		over_id <= 6)a
group by 	
	overs),
middle_overs_dt as -- Middle overs Calculations for Overs between 7 and 15 
(select 
	overs as Over_Type,
    round(avg(rr),2) as Avg_Economy,
	round(max(ttl_dot_ball)*100/max(ttl_mo_balls),2) as Dot_Ball_Percentage,
    round(max(ttl_bb_ball)*100/max(ttl_mo_balls),2) as Boundary_Ball_Percentage,
    round(max(ttl_mo_balls)/(sum(wickets)),2) as Bowling_Strike_Rate,
	round(sum(wickets)*100/(select team_wickets_taken from entire_dt),2) as Wickets_taken_percentage,
    round(max(ttl_mo_rc)*100/(select team_runs_conceded from entire_dt),2) as Runs_conceded_percentage
from(
	select 
		over_id,
		overs,
		wickets,
        sum(Dot_Ball) over() as ttl_dot_ball,
		sum(Boundary_Ball) over() as ttl_bb_ball,  
		sum(ttl_runs) over () as ttl_mo_rc,
		sum(balls) over() as ttl_mo_balls,
		(case when over_id = 15 then sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
													 rows between unbounded preceding and current row)/9
			 else null end) as rr
	from 
		cte 
	where 
		over_id between 7 and 15)a
group by 	
	overs),
slog_overs_dt as -- slog over calculation for overs between 16 - 20 
(select 
	overs as Over_Type,
    round(avg(rr),2) as Avg_Economy,
	round(max(ttl_dot_ball)*100/max(ttl_so_balls),2) as Dot_Ball_Percentage,
    round(max(ttl_bb_ball)*100/max(ttl_so_balls),2) as Boundary_Ball_Percentage,
    round(max(ttl_so_balls)/(sum(wickets)),2) as Bowling_Strike_Rate,
	round(sum(wickets)*100/(select team_wickets_taken from entire_dt),2) as Wickets_taken_percentage,
    round(max(ttl_so_rc)*100/(select team_runs_conceded from entire_dt),2) as Runs_conceded_percentage
from(
	select 
		over_id,
		overs,
		wickets,
		sum(Dot_Ball) over() as ttl_dot_ball,
		sum(Boundary_Ball) over() as ttl_bb_ball,  
		sum(ttl_runs) over () as ttl_so_rc,
		sum(balls) over() as ttl_so_balls,
		(case when over_id = 20 then sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
														rows between unbounded preceding and current row)/5
			 else null end) as rr
	from 
		cte 
	where 
		over_id between 16 and 20)a
group by 	
	overs)
select * from power_play_dt	
union
select * from middle_overs_dt
union
select * from slog_overs_dt;




--13.Average wickets taken by each bowler in each venue and also ranking it

with wickets_data as (select 
	p.Player_Name,
    v.Venue_Name,
    count(wt.player_out) as Wickets,
    count( distinct m.Match_Id) as Matches,
    round(count(wt.player_out)/count( distinct m.Match_Id),2) as Avg_wicket
from 
	player p join ball_by_ball b 
    on p.player_id = b.bowler
	left join wicket_taken wt 
    on b.match_id = wt.match_id 
    and b.ball_id = wt.ball_id
    and b.over_id = wt.over_id 
    and b.innings_no = wt.innings_no 
    left join matches m 
    on m.Match_Id = b.Match_Id
    join venue v 
    on v.Venue_Id = m.Venue_Id
    join out_type ot
    on wt.kind_out = ot.out_id
where 
	ot.out_name not in ('run out', 'retired hurt', 'hit wicket', 'obstructing the field')
group by 
	p.player_name,
    v.Venue_Name)
select 
	Player_Name,
    Venue_Name,
    Wickets,
    Matches,
    Avg_Wicket,
    dense_rank() over(partition by player_name order by avg_wicket desc) as Ranking
from 
	wickets_data


--14. players consistently performed well in past seasons

--# CONSISTANT TOP 5 BATSMEN 
with batsmen_stat as (
    select 
        p.Player_Name, 
        s.Season_Year, 
        SUM(b.Runs_Scored) AS Total_Runs
    from 
		player p join  Ball_by_Ball b 
        ON p.Player_Id = b.Striker
		join Matches m 
        on b.Match_Id = m.Match_Id
		join Season s 
        on m.Season_Id = s.Season_Id
    group by 
		p.Player_Name, 
        s.Season_Year
)
select 
    Player_Name, 
    round(avg(Total_Runs),2) as Avg_Runs_per_Season
from 
	batsmen_stat
group by 
	Player_Name
having
	count(Season_Year) >= 3
order by 
	Avg_Runs_per_Season desc
limit 5;


--#CONSISTANT Top 5 BOWLERS 

with bowler_stat as (
    select 
        p.Player_Name, 
        s.Season_Year, 
        count(wt.player_out) as Total_Wickets,
        round(SUM(b.Runs_Scored)/(count(b.ball_id)/6),2) AS Economy
    from 
		player p join  Ball_by_Ball b 
        ON p.Player_Id = b.bowler
		join Matches m 
        on b.Match_Id = m.Match_Id
		join Season s 
        on m.Season_Id = s.Season_Id
		left join Wicket_Taken wt 
        on  b.Match_Id = wt.Match_Id
		and b.Innings_No = wt.Innings_No
		and b.Over_Id = wt.Over_Id 
		and b.Ball_Id = wt.Ball_Id 
    group by 
		p.Player_Name, 
        s.Season_Year
)
select 
    Player_Name, 
    round(avg(Total_Wickets),2) as Avg_Wickets_per_Season,
    round(avg(Economy),2) as Avg_Economy
from 
	bowler_stat
group by 
	Player_Name
having
	count(Season_Year) >= 3
	and 
	avg(Economy) < 8
order by 
	Avg_Wickets_per_Season desc, Avg_Wickets_per_Season asc
limit 5;



--15. Top players in each venue based on their performance

--#Batsmen Stats
with players_stats as (
select 
	p.Player_Name, 
    v.Venue_Name, 
	sum(b.Runs_Scored) as Total_Runs, 
    round(sum(b.Runs_Scored)/count(wt.player_out), 2) as Average,
	round(sum(b.Runs_Scored) / count(b.Ball_Id), 2) * 100 AS Strike_Rate
from 
	Ball_by_Ball b join Matches m 
    on m.Match_Id = b.Match_Id
	left join Wicket_Taken wt 
	on  b.Match_Id = wt.Match_Id
	and b.Innings_No = wt.Innings_No
	and b.Over_Id = wt.Over_Id 
	and b.Ball_Id = wt.Ball_Id 
	join Player p 
    on p.Player_Id = b.Striker
	join Venue v 
	on m.Venue_Id = v.Venue_Id
group by 
	p.Player_Name,
    v.Venue_Name
having
    count(b.Ball_Id) > 120)
select 
	Player_Name,
    Venue_Name,
    Total_runs,
    Average,
    Strike_Rate
from 
(select 
	Player_Name,
    Venue_Name,
    Total_runs,
    Average,
    Strike_Rate,
    dense_rank() over(partition by player_name order by Total_runs desc, average desc ) as dnk 
from 
	players_stats) a 
where 
	dnk = 1
order by 
	total_runs desc; 
	
--#Bowler Stats 

with players_stats as (
select 
	p.Player_Name, 
    v.Venue_Name,
    count(wt.player_out) as Total_Wickets,
    round(sum(b.Runs_Scored)/(count(b.ball_id)/6), 2) as Economy
from 
	Ball_by_Ball b join Matches m 
    on m.Match_Id = b.Match_Id
	left join Wicket_Taken wt 
	on  b.Match_Id = wt.Match_Id
	and b.Innings_No = wt.Innings_No
	and b.Over_Id = wt.Over_Id 
	and b.Ball_Id = wt.Ball_Id 
	join Player p 
    on p.Player_Id = b.Bowler
	join Venue v 
	on m.Venue_Id = v.Venue_Id
group by 
	p.Player_Name,
    v.Venue_Name
having
	count(b.ball_id)  > 60)
select 
	Player_Name,
    Venue_Name,
    Total_Wickets,
    Economy
from 
(select 
	Player_Name,
    Venue_Name,
    Total_Wickets,
    Economy,
    dense_rank() over(partition by player_name order by Total_Wickets desc, Economy desc ) as dnk 
from 
	players_stats) a 
where 
	dnk = 1
order by 
	Total_Wickets desc;    



--In-Depth Analysis

--1. Toss decision analysis

--# Toss decision
select 
	concat(td.toss_name,'_first') as Toss_Decision,
    round(count(*)*100/(select count(*) from matches),2) as Desicion_Percentage,
    round((sum(case when m.toss_winner = m.match_winner then 1 else 0 end)/count(*)*100),2) as Match_Won_Percentage,
    round((sum(case when m.toss_winner != m.match_winner then 1 else 0 end)/count(*)*100),2) as Match_Lost_Percentage
from 
	matches m join toss_decision td 
    on m.toss_decide = td.toss_id
group by 
	td.toss_name;


--#Venue wise toss decision 
select 
	v.venue_name as Venue_Name,
	concat(td.toss_name,'_first') as Toss_Decision,
    count(*) as Total_Matches,
    round(sum(case when m.toss_winner = m.match_winner then 1 else 0 end),2) as Matches_Won,
    round(sum(case when m.toss_winner != m.match_winner then 1 else 0 end),2) as Matches_Lost,
    round((sum(case when m.toss_winner = m.match_winner then 1 else 0 end)/count(*)*100),2) as Win_Percentage,
    round((sum(case when m.toss_winner != m.match_winner then 1 else 0 end)/count(*)*100),2) as Loss_Percentage
from 
	matches m join toss_decision td 
    on m.toss_decide = td.toss_id
    join venue v 
    on m.venue_id = v.venue_id
group by 
	td.toss_name,
    v.venue_name
order by 
	v.venue_name;
	

--2. Players who would be best fit for the team.

--#Good Batsmen with experience, StrikeRate and Average_Runs 
select 
	p.Player_Name,
    round(sum(b.runs_scored)/sum(case when wc.Player_Out is null then 0 else 1 end),2) as Avg_Runs,
    round(((sum(b.runs_scored)/count(b.Ball_Id)) *100),2) as Strike_Rate
from 
	player p join ball_by_ball b 
    on  p.Player_Id = b.Striker
    left join wicket_taken wc 
    on p.Player_Id = wc.Player_Out
    and wc.Match_Id = b.Match_Id
    and wc.Innings_No = b.Innings_No
    and wc.over_id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
group by 
    p.Player_Name
having 
	count(distinct b.match_id) >= 30
    and 
    round(sum(b.runs_scored)/sum(case when wc.Player_Out is null then 0 else 1 end),2) >= 25 
    and 
    round(((sum(b.runs_scored)/count(b.Ball_Id)) *100),2) >= 130;

--#Good Bowler with experience, Wickets and economy
select 
	p.Player_Name,
    sum(case when wc.player_out is null then 0 else 1 end) as Wickets,
    round(sum(b.Runs_Scored)/(count(b.Ball_Id)/6),2) as Economy 
from 
	player p join ball_by_ball b 
    on  p.Player_Id = b.bowler
    left join wicket_taken wc 
    on wc.Match_Id = b.Match_Id
    and wc.Innings_No = b.Innings_No
    and wc.over_id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
group by 
    p.Player_Name
having 
	count(distinct b.match_id) >= 20
    and 
    sum(case when wc.player_out is null then 0 else 1 end) >= 30
    and 
    round(sum(b.Runs_Scored)/(count(b.Ball_Id)/6),2) <= 8
order by 
	Wickets desc, Economy;

--#Good All-rounder with experience, Wickets and runs

with avg_run_dt as ( -- average runs for each player 
select 
	p.Player_Id,
    round(sum(b.runs_scored)/count(wc.Player_Out),2) as avg_runs
from 
	player p join ball_by_ball b 
    on p.Player_Id = b.Striker
    left join wicket_taken wc 
    on p.Player_Id = wc.Player_Out
    and wc.Match_Id = b.Match_Id
    and wc.Innings_No = b.Innings_No
    and wc.over_id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
group by 
    p.Player_Id
having 
	count(b.Match_Id) >=20
),
wk_dt as ( -- wickets taken by each player
select 
	p.player_id,
    count(wc.player_out) as wickets
from 
	ball_by_ball b join player p 
    on b.bowler = p.player_id
	left join wicket_taken wc 
    on wc.Match_Id = b.Match_Id
    and wc.Over_Id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
    and wc.Innings_No = b.Innings_No
group by 
	p.player_id
having
	count(b.Match_Id) >= 20
),
overall_avg as  -- calculateting the overall average 
(select 
	round(avg(avg_runs),2) as aoa_runs,
    round(avg(wickets),2) aoa_wk
from 	
	avg_run_dt a join wk_dt b 
    on a.player_id = b.player_id)
	
-- selecting allrounders 
select 
	p.player_name as Player_Name,
    ard.avg_runs as Avg_Runs,
    wd.wickets as Wickets
from 
	avg_run_dt ard join wk_dt wd 
    on ard.player_id = wd.player_id 
    join player p 
    on p.player_id = ard.player_id
    cross join overall_avg oa
where 
	ard.avg_runs > oa.aoa_runs
    and 
    wd.wickets > oa.aoa_wk
order by 
	Player_Name,
    Wickets desc,
    Avg_Runs desc;
	
--3. Parameters that should be focused on while selecting the players

--# Batting Suggestion
with cte as ( -- calculating match wise runs per over 
select
	b.match_id, 
	b.over_id,
	(case when b.over_id between 1 and 6 then 'Power Play'
		 when b.over_id between 7 and 15 then 'Middle Overs'
         when b.over_id between 16 and 20 then 'Slog Overs'
         end) as Overs ,
    sum(b.runs_scored) as ttl_runs,
    count(wc.player_out) as wickets
from 
	ball_by_ball b join matches m 
    on b.Match_Id = m.Match_Id
    join player p 
    on p.Player_Id = b.Striker
	left join wicket_taken wc 
    on p.Player_Id = wc.Player_Out
    and wc.Match_Id = b.Match_Id
    and wc.Innings_No = b.Innings_No
    and wc.over_id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
where 
	b.Team_Batting = (select team_id from team where team_name = 'Royal Challengers Bangalore')
    and 
    m.season_id	= (select max(season_id) from season)
group by 
	b.match_id,
    b.Over_Id),
power_play as  -- powerplay calculation OVER 1-6  
(select 
	Overs,
    round(avg(rr),2) as Avg_Run_Rate,
	sum(wickets) as Total_Wickets_Lost
from(
	select 
		over_id,
		overs,
		wickets,
		sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
						   rows between unbounded preceding and current row) as runs,
		(case when over_id = 6 then sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
						  rows between unbounded preceding and current row)/6
			 else null end) as rr
	from
		cte 
	where 
		over_id <= 6)a
group by 	
	overs),
middle_overs as  -- Middle Over calculation OVER 7-15
(select 
	Overs,
    round(avg(rr),2) as Avg_Run_Rate,
	sum(wickets) as Total_Wickets_Lost
from(
	select 
		over_id,
		overs,
		wickets,
		sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
						rows between unbounded preceding and current row) as runs,
		(case when over_id = 15 then sum(ttl_runs) over(partition by  match_id 
				order by match_id,over_id rows between unbounded preceding and current row)/9
			 else null end) as rr
	from 
		cte 
	where 
		over_id between 7 and 15)a
group by 	
	overs),
slog_overs as -- Slog/Death Over calculation OVER 16-20
(select 
	Overs,
    round(avg(rr),2) as Avg_Run_Rate,
	sum(wickets) as Total_Wickets_Lost
from(
	select 
		over_id,
		overs,
		wickets,
		sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
						rows between unbounded preceding and current row) as runs,
		(case when over_id = 20 then sum(ttl_runs) over(partition by  match_id 
				order by match_id,over_id rows between unbounded preceding and current row)/5
			 else null end) as rr
	from 
		cte 
	where 
		over_id between 16 and 20)a
group by 	
	overs)
select * from power_play
union
select * from middle_overs
union
select * from slog_overs;


--# Bowling Suggestion

with cte as (select -- Match wise calculations
	b.match_id, 
	b.over_id,
	(case when b.over_id between 1 and 6 then 'Power Play'
		 when b.over_id between 7 and 15 then 'Middle Overs'
         when b.over_id between 16 and 20 then 'Slog Overs'
         end) as Overs ,
    sum(b.runs_scored) as ttl_runs,
    count(wc.player_out) as wickets
from 
	ball_by_ball b join matches m 
    on b.Match_Id = m.Match_Id
    join player p 
    on p.Player_Id = b.Striker
	left join wicket_taken wc 
    on p.Player_Id = wc.Player_Out
    and wc.Match_Id = b.Match_Id
    and wc.Innings_No = b.Innings_No
    and wc.over_id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
where 
	b.Team_Bowling = (select team_id from team where team_name = 'Royal Challengers Bangalore')
    and 
    m.season_id	= (select max(season_id) from season)
group by 
	b.match_id,
    b.Over_Id),
power_play as  -- PowerPlay Calculation Over 1-6 
(select 
	Overs,
    round(avg(rr),2) as Avg_Run_Rate,
	sum(wickets) as Total_Wickets_Taken
from(
	select 
		over_id,
		overs,
		wickets,
		sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
					rows between unbounded preceding and current row) as runs,
		(case when over_id = 6 then sum(ttl_runs) over(partition by  match_id 
		order by match_id,over_id rows between unbounded preceding and current row)/6
			 else null end) as rr
	from 
		cte 
	where 
		over_id <= 6)a
group by 	
	overs),
middle_overs as  -- middle over Calculation Over 7-15 
(select 
	Overs,
    round(avg(rr),2) as Avg_Run_Rate,
	sum(wickets) as Total_Wickets_Taken
from(
	select 
		over_id,
		overs,
		wickets,
		sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
				rows between unbounded preceding and current row) as runs,
		(case when over_id = 15 then sum(ttl_runs) over(partition by  match_id 
        order by match_id,over_id rows between unbounded preceding and current row)/9
			 else null end) as rr
	from 
		cte 
	where 
		over_id between 7 and 15)a
group by 	
	overs),
slog_overs as  -- Solg over Calculation 16-20
(select 
	Overs,
    round(avg(rr),2) as Avg_Run_Rate,
	sum(wickets) as Total_Wickets_Taken
from(
	select 
		over_id,
		overs,
		wickets,
		sum(ttl_runs) over(partition by  match_id order by match_id,over_id 
				rows between unbounded preceding and current row) as runs,
		(case when over_id = 20 then sum(ttl_runs) over(partition by  match_id 
        order by match_id,over_id rows between unbounded preceding and current row)/5
			 else null end) as rr
	from 
		cte 
	where 
		over_id between 16 and 20)a
group by 	
	overs)
select * from power_play
union
select * from middle_overs
union
select * from slog_overs; 



--#4. All Rounders

with avg_run_dt as ( -- Average runs Scored
select 
	p.Player_Id,
    round(sum(b.runs_scored)/count(wc.Player_Out),2) as avg_runs
from 
	player p join ball_by_ball b 
    on p.Player_Id = b.Striker
    left join wicket_taken wc 
    on p.Player_Id = wc.Player_Out
    and wc.Match_Id = b.Match_Id
    and wc.Innings_No = b.Innings_No
    and wc.over_id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
group by 
    p.Player_Id
having 
	count(b.Match_Id) >=30
),
wk_dt as ( -- Wickets Taken
select 
	p.player_id,
    count(wc.player_out) as wickets,
    round(sum(b.runs_scored)/(count(b.ball_id)/6),2) as economy
from 
	ball_by_ball b join player p 
    on b.bowler = p.player_id
	left join wicket_taken wc 
    on wc.Match_Id = b.Match_Id
    and wc.Over_Id = b.Over_Id
    and wc.Ball_Id = b.Ball_Id
    and wc.Innings_No = b.Innings_No
group by 
	p.player_id
having
	count(b.Match_Id) >= 20
)
-- Selecting the Players
select 
	p.player_name as Player_Name,
    ard.avg_runs as Avg_Runs,
    wd.wickets as Wickets,
    wd.economy as Economy
from 
	avg_run_dt ard join wk_dt wd 
    on ard.player_id = wd.player_id 
    join player p 
    on p.player_id = ard.player_id
where 
	ard.avg_runs >= 17
    and
    wd.wickets >= 20
order by 
	Player_Name,
    Wickets desc,
    Avg_Runs desc;


--#5 . Match winners

-- Man of the Matches Awards Won
select 
	p.player_name, 
    count(m.Man_of_the_Match) as MOM_Trophies
from 
	player p left join matches m 
    on p.player_id = m.Man_of_the_Match
group by 
	p.player_name 
having 
	count(m.Man_of_the_Match) >0
order by 
	MOM_Trophies desc 
limit 10;

-- Man Of the Series Awards
select 
	p.player_name,
	sum(case when p.player_id = s.Man_of_the_Series then 1 else 0 end) as MOS_Trophies
from 
	player p left join season s 
	on p.player_id = s.Man_of_the_Series
    or p.player_id	= s.Orange_Cap
    or p.Player_Id  = s.Purple_Cap
group by 
	p.player_name
having 
	sum(case when p.player_id = s.Man_of_the_Series then 1 else 0 end) >0
Order by 
	MOS_trophies desc; 
	
-- Orange Cap Winners 
select 
	p.player_name,
    sum(case when p.player_id = s.Orange_Cap then 1 else 0 end) as OrangeCap_Winner
from 
	player p left join season s 
	on p.player_id = s.Man_of_the_Series
    or p.player_id	= s.Orange_Cap
    or p.Player_Id  = s.Purple_Cap
group by 
	p.player_name
having 
    sum(case when p.player_id = s.Orange_Cap then 1 else 0 end) > 0
order by 
	OrangeCap_Winner desc; 

-- Purple Cap Winners 
select 
	p.player_name,
    sum(case when p.player_id = s.Purple_Cap then 1 else 0 end) as PurpleCap_Winner
from 
	player p left join season s 
	on p.player_id = s.Man_of_the_Series
    or p.player_id	= s.Orange_Cap
    or p.Player_Id  = s.Purple_Cap
group by 
	p.player_name
having 
	sum(case when p.player_id = s.Purple_Cap then 1 else 0 end) > 0
order by 
	PurpleCap_Winner desc; 


--#7. Factors contributing to the high-scoring matches and the impact on viewership and team strategies

with match_dt as (
select 
	b.match_id,
    sum(b.runs_scored) as ttl_runs,
    count(wt.Player_Out) as ttl_wickets,
    round(sum(case when b.over_id between 1 and 6 then b.runs_scored else 0 end)*100/sum(b.runs_scored),2) as power_play,
    round(sum(case when b.over_id between 7 and 15 then b.runs_scored else 0 end)*100/sum(b.runs_scored),2)  as middle_overs,
    round(sum(case when b.over_id between 16 and 20 then b.runs_scored else 0 end)*100/sum(b.runs_scored),2)  as slog_overs
from 
	ball_by_ball b 
    left join wicket_taken wt 
    on b.match_id = wt.Match_Id
    and b.Innings_No = wt.Innings_No
    and b.Over_Id = wt.Over_Id
    and b.Ball_Id = wt.Ball_Id
group by 
	b.match_id)
select 
	v.Venue_Name,
    count(m.match_id) as Total_Matches,
    sum(ttl_runs) as Total_Runs,
    round(avg(ttl_runs),2) as Avg_runs_per_match,
    round(avg(power_play),2) as 'Avg_power_play_run %',
    round(avg(middle_overs),2) as 'Avg_Middle_Over_run %',
    round(avg(slog_overs),2) as 'Avg_Slog_over_run %',
    sum(ttl_wickets) as Total_Wickets,
    round(avg(ttl_wickets),2) as Avg_wickets_per_match
from 
	venue v join matches m 
    on v.venue_id = m.venue_id
	left join match_dt md 
    on md.match_id = m.Match_Id
group by 
	v.Venue_Name
order by 
	Avg_runs_per_match desc;
	

--#8. Home ground advantage

--#Home Ground advantage
with result_data as (select 
	match_id,
    (case when team_1 = Match_Winner then 'Home_Team'
		  when team_2 = Match_Winner then 'Away_Team'
	end) as Match_win_team
from 
	matches)
select 
	Match_Win_Team,
    count(match_id) as Matches_Win,
    round(count(match_id)*100/(select count(*) from matches),2) as 'Win %'
from 
	result_data 
where 
	Match_win_team is not null
group by 
	Match_win_team;

--#Home Ground advantage for each team 
with  home_dt as ( -- Home Games Calculations
select 
	t.Team_Name,
    'Home' as Venue,
    count(*) as Total_Matches,
    round(sum(case when m.team_1 = m.toss_winner 
			then 1 else 0 end)*100/count(*),2) as 'Toss_Win %',
    round(sum(case when m.team_1 != m.toss_winner 
			then 1 else 0 end)*100/count(*),2) as 'Toss_Lost %',
    round(sum(case when m.team_1 = m.Match_Winner 
			then 1 else 0 end)*100/count(*),2) as 'Match_Win %',
    round(sum(case when m.team_1 != m.Match_Winner 
			then 1 else 0 end)*100/count(*),2) as 'Match_Lost %'
from 
	team t join matches m 
    on t.team_id = m.team_1
    join venue v 
    on v.venue_id = m.Venue_Id
    join city ct 
    on v.City_Id = ct.City_Id
    join country c
    on c.Country_Id = ct.Country_id
where 
	c.Country_Name = 'India'
group by 
	t.Team_Name),
away_dt as ( -- Away Games Calculation
select 
	t.Team_Name,
    'Away' as Venue,
    count(*) as Total_Matches,
    round(sum(case when m.team_2 = m.toss_winner 
			then 1 else 0 end)*100/count(*),2) as 'Toss_Win %',
    round(sum(case when m.team_2 != m.toss_winner 
			then 1 else 0 end)*100/count(*),2) as 'Toss_Lost %',
    round(sum(case when m.team_2 = m.Match_Winner 
			then 1 else 0 end)*100/count(*),2) as 'Match_Win %',
    round(sum(case when m.team_2 != m.Match_Winner 
			then 1 else 0 end)*100/count(*),2) as 'Match_Lost %'
from 
	team t join matches m 
    on t.team_id = m.team_2
    join venue v 
    on v.venue_id = m.Venue_Id
    join city ct 
    on v.City_Id = ct.City_Id
    join country c
    on c.Country_Id = ct.Country_id
where 
	c.Country_Name = 'India'
group by 
	t.Team_Name)

select 
	*
from 
(select * from home_dt
union
select * from away_dt)dt 
order by 
	dt.team_name ;



--9. Match Performance of Royal Challengers Bangalore

--# Match Performance by each season
select 
	'Royal Challengers Bangalore' as Team,
	Season_Id,
	year(Match_Date) as  Year,
	count(*) as Total_Matches,
    sum(case when Match_Winner = 2 then 1 else 0 end) as Wins,
    sum(case when Match_Winner !=2 then 1 else 0 end) as Loss,
    sum(case when Outcome_type = 2 then 1 else 0 end) as No_Result,
    round((sum(case when Match_Winner = 2 then 1 else 0 end)*100/count(Match_Id)),2) as 'Win %',
    round((sum(case when Match_Winner != 2 then 1 else 0 end)*100/count(Match_Id)),2) as 'Loss %'
from 
	matches
where 
	Team_1 = 2 or Team_2 = 2
group by 
	Season_Id,
    Year;


--#Venue Wise comparision 
select 
	v.Venue_Name,
    count(*) as Total_Matches,
    sum(case when Match_Winner = 2 then 1 else 0 end) as Wins,
    sum(case when Match_Winner !=2 then 1 else 0 end) as Loss,
    sum(case when Outcome_type = 2 then 1 else 0 end) as No_Result,
    round((sum(case when Match_Winner = 2 then 1 else 0 end)*100/count(Match_Id)),2) as Win_percentage,
    round((sum(case when Match_Winner != 2 then 1 else 0 end)*100/count(Match_Id)),2) as Loss_percentage 
from 
	matches m join venue v 
    on m.Venue_Id = v.Venue_Id
	join city ct 
    on v.City_Id = ct.City_Id
    join country c
    on c.Country_Id = ct.Country_id
where 
	(team_1 = 2 or Team_2 = 2)
    and 
	c.Country_Name = 'India'
group by 
	v.Venue_Name
having 
	round((sum(case when Match_Winner != 2 then 1 else 0 end)*100/count(Match_Id)),2) >0
order by 
	Loss_percentage desc;
	
-- Innings Dynamics 
with cte as 
(select -- match wise calculations
	t.Team_Name,
	match_id,
    (case 
		when (m.Toss_Winner = 2 and td.Toss_Name = 'field') 
			or (m.Toss_Winner != 2 and td.Toss_Name = 'bat') 
		then 'chasing'
		when (m.Toss_Winner = 2 and td.Toss_Name = 'bat') 
			or (m.Toss_Winner != 2 and td.Toss_Name = 'field') 
		then 'defending'
	end )as Innings_context,
	(case  
		when (
			case 
				when ((m.Toss_Winner = 2 and td.Toss_Name = 'field') 
					or (m.Toss_Winner != 2 and td.Toss_Name = 'bat')) 
					and (m.Match_Winner = 2) 
				then 'won'
				when ((m.Toss_Winner = 2 and td.Toss_Name = 'bat') 
					or (m.Toss_Winner != 2 and td.Toss_Name = 'field')) 
					and (m.Match_Winner = 2) 
				then 'won'
			else 'lost' end) = 'won' then 'won'
	 else 'lost' end) AS outcome
from 
	matches m join toss_decision td
    on m.Toss_Decide = td.toss_id 
    join team t 
    on t.team_id = m.Team_1
    or t.Team_Id = m.Team_2
where 
	t.team_name = 'Royal Challengers Bangalore'
    and 
    m.Match_Winner is not null)
-- Final Result Calculation
select 
	Team_name,
    Innings_context,
    Outcome,
    count(outcome) as Match_Result,
    round(count(outcome)*100/
    (select count(*) from cte c2 where c.Innings_context = c2.Innings_context),2) 
    as Match_Result_Percentage
from 
	cte c 
group by 
	Team_name, 
    Innings_context,
    outcome
order by 
	Innings_context, outcome desc;


--11. Updating Records
UPDATE MATCH 
SET Opponent_Team = 'Delhi_Daredevils'	
WHERE Opponent_Team = 'Delhi_Capitals';
