------------ A. CREATE WAREHOUSE ------------

-------- BULK LOAD --------

DROP TABLE IF EXISTS CardTransactions;

CREATE TABLE CardTransactions(
	pid INT,
	pname VARCHAR(50),
	age INT,
	gender CHAR(1),
	cardno CHAR(16),
	card_brand VARCHAR(30),
	card_type VARCHAR(20),
	tdate DATETIME,
	amount DECIMAL(6,2),
	ttc INT,
	trans_type VARCHAR(30),
	mcc INT,
	merchant_city VARCHAR(50),
);

-- TODO: !!! CHANGE PATH !!!

BULK INSERT CardTransactions
FROM 'YOUR\PATH\HERE\CardsTransactions.txt'
WITH (FIRSTROW =2, FIELDTERMINATOR='|', ROWTERMINATOR = '\n');

-------- CREATE STAR SCHEMA --------

DROP TABLE IF EXISTS Transactions, Holder, Card, DatetimeInfo, TransactionType, City;

--- DIMENSION TABLES ---

CREATE TABLE Holder(
	pid INT PRIMARY KEY,
	pname VARCHAR(50),
	age INT,
	gender CHAR(1),
);

CREATE TABLE Card(
	cardno CHAR(16) PRIMARY KEY,
	card_brand VARCHAR(30),
	card_type VARCHAR(20),
);

CREATE TABLE DatetimeInfo(
	tdate DATETIME PRIMARY KEY,
	tyear INT,
	tquarter INT,
	tmonth INT,
	tday INT,
	tdayofyear INT,
	tweek INT,
	tweekday INT,
);

CREATE TABLE TransactionType(
	ttc INT PRIMARY KEY,
	trans_type VARCHAR(30),
);

CREATE TABLE City(
	mcc INT PRIMARY KEY,
	merchant_city VARCHAR(50),
);

--- FACT TABLE ---

CREATE TABLE Transactions(
	pid INT FOREIGN KEY REFERENCES Holder(pid),
	cardno CHAR(16) FOREIGN KEY REFERENCES Card(cardno),
	ttc INT FOREIGN KEY REFERENCES TransactionType(ttc),
	mcc INT FOREIGN KEY REFERENCES City(mcc),
	tdate DATETIME FOREIGN KEY REFERENCES DatetimeInfo(tdate),
	amount DECIMAL(6,2),
	PRIMARY KEY(pid, cardno, tdate),
);

--- INSERT DATA INTO STAR SCHEMA ---

--- DIMENSION TABLES ---

INSERT INTO Holder
SELECT DISTINCT pid, pname, age, gender
FROM CardTransactions;

INSERT INTO Card
SELECT DISTINCT cardno, card_brand, card_type
FROM CardTransactions;

INSERT INTO DatetimeInfo
SELECT DISTINCT tdate, DATEPART(year, tdate), DATEPART(quarter, tdate),
	DATEPART(month, tdate), DATEPART(day, tdate), DATEPART(dayofyear, tdate), 
	DATEPART(week, tdate), DATEPART(weekday, tdate)
FROM CardTransactions;

-- see the range of days for each year
-- 2020 only has data for the first two months
SELECT MIN(tdayofyear), MAX(tdayofyear), tyear FROM DatetimeInfo GROUP BY tyear ORDER BY tyear;

INSERT INTO TransactionType
SELECT DISTINCT ttc, trans_type
FROM CardTransactions;

INSERT INTO City
SELECT DISTINCT mcc, merchant_city
FROM CardTransactions;

--- FACT TABLE ---

INSERT INTO Transactions
SELECT pid, cardno, ttc, mcc, tdate, amount
FROM CardTransactions;

--- ATTEMPT AT USCITIES ---

-- Source/Attribution: https://simplemaps.com/data/us-cities

-- load data using SQLServer's import tool
-- Right-click on Database > Tasks > Import Data

-- drop columns which are not necessary for our analysis
ALTER TABLE dbo.uscities DROP COLUMN county_fips, county_name, source, military, timezone, zips;

-- count occurences of each city of our dataset in the uscities table
SELECT DISTINCT merchant_city, COUNT(state_name) as number_of_states
FROM City
JOIN uscities ON uscities.city = City.merchant_city
GROUP BY merchant_city
ORDER BY number_of_states DESC;

-- find how many cities are present in N states, for various values of N
SELECT temp.number_of_states, COUNT(temp.number_of_states) as number_of_cities
FROM (
	SELECT DISTINCT merchant_city, COUNT(state_name) as number_of_states
	FROM City
	JOIN uscities ON uscities.city = City.merchant_city
	GROUP BY merchant_city
) temp
GROUP BY number_of_states
ORDER BY number_of_cities DESC, number_of_states;

-- find cities with no state
SELECT merchant_city
FROM City
FULL OUTER JOIN uscities ON uscities.city = City.merchant_city
WHERE state_name is NULL
ORDER BY merchant_city;

-- Conclusion: Too many cities are present in more than one states,
--			   and some cities don't have state information. 
--			   Therefore per-state statistics will not be accurate.

--- CUBE ---

SELECT gender, age, tmonth, SUM(amount) as transaction_amount
FROM Transactions
JOIN Holder ON Transactions.pid = Holder.pid
JOIN DatetimeInfo ON Transactions.tdate = DatetimeInfo.tdate
GROUP BY CUBE (gender, age, tmonth);


------------ B. VISUALISATIONS ------------

-- average per person spending per city
-- create view to import into powerbi
DROP VIEW IF EXISTS transaction_amount_per_person;

CREATE VIEW transaction_amount_per_person AS
SELECT SUM(amount) / COUNT(DISTINCT pid) as amount_per_person, merchant_city
FROM Transactions
JOIN City ON City.mcc = Transactions.mcc
GROUP BY merchant_city;
--ORDER BY amount_per_person DESC;

SELECT *
FROM transaction_amount_per_person
ORDER BY amount_per_person DESC


------------ C. MODELS ------------

-------- MODEL 1 --------

-- time series of sum(amount) across months and years
SELECT SUM(amount) as sum_amount, tyear, tmonth
FROM Transactions
JOIN Holder ON Holder.pid = Transactions.pid
JOIN DatetimeInfo ON DatetimeInfo.tdate = Transactions.tdate
GROUP BY tmonth, tyear
ORDER BY tyear, tmonth;


-------- MODEL 2 --------

-- most frequent city of transactions per holder
DROP VIEW IF EXISTS holder_sum_trans_per_count_of_city;

CREATE VIEW holder_sum_trans_per_count_of_city AS
SELECT Holder.pid, City.merchant_city, COUNT(Transactions.mcc) AS count_of_city
FROM Transactions
JOIN Holder ON Transactions.pid = Holder.pid
JOIN City ON City.mcc = Transactions.mcc
GROUP BY Holder.pid, City.merchant_city
ORDER BY Holder.pid, count_of_city DESC;

-- pid, gender, age, most frequent city and total transactions per holder
SELECT Holder.pid, gender, age, merchant_city, SUM(amount) AS transaction_amount
FROM Transactions
JOIN Holder ON Holder.pid = Transactions.pid
JOIN holder_sum_trans_per_count_of_city v1 ON v1.pid = Transactions.pid
WHERE count_of_city = (
	 SELECT MAX(count_of_city)
	 FROM holder_sum_trans_per_count_of_city v2
	 WHERE v1.pid = v2.pid
)
GROUP BY Holder.pid, gender, age, merchant_city
ORDER BY Holder.pid;
