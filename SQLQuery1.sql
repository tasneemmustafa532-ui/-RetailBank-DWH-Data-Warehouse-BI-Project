SELECT 
TRY_CAST(merchant_id AS INT ) AS [merchant_id],
TRY_CAST(merchant_name AS nvarchar(100) ) AS [merchant_name],
ISNULL ( LTRIM(RTRIM(dominant_category)), '') AS [dominant_category],
ISNULL ( LTRIM(RTRIM(merchant_city)),'Unknown') AS [merchant_city],
ISNULL ( LTRIM(RTRIM(merchant_state)), '') AS [merchant_state],
TRY_CAST(merchant_lat AS decimal(9,4) )  AS [merchant_lat],
TRY_CAST(merchant_long AS decimal(9,4) )  AS [merchant_long],
TRY_CAST(merchant_since AS DATE )          AS [merchant_since],
TRY_CAST(is_active AS INT ) AS is_active

INTO Silver.[Merchants]
FROM Bronze.[Merchants]

ALTER TABLE [Silver].[Merchants] ALTER COLUMN [merchant_id] INT NOT NULL;
ALTER TABLE Silver.[Merchants] ADD CONSTRAINT PK_SILVER_card PRIMARY KEY ([merchant_id]);



--- DimDate

CREATE TABLE Gold.DimDate(
datekey     INT NOT NULL PRIMARY KEY,
full_date   DATE NOT NULL,
[year]      INT  NOT NULL,
[quarter]   INT  NOT NULL,
[month]     INT NOT NULL,
month_name  VARCHAR (20) NOT NULL,
[day]       INT NOT NULL,
day_name    VARCHAR (20) NOT NULL,
is_weekend  BIT NOT NULL
);
GO

DECLARE @start_date DATE, @end_date DATE, @current_date DATE

SELECT 
@start_date = MIN ([trans_date_trans_time]),
@end_date =  MAX ([trans_date_trans_time]) 
FROM [Silver].[Transactions]

SET @current_date = @start_date
SELECT @start_date,@end_date, @current_date

WHILE @current_date <= @end_date
Begin
     INSERT INTO GOLD.DimDate(
      datekey     ,
      full_date   ,
      [year]      ,
      [quarter]   ,
      [month]     ,
      month_name  ,
      [day]       ,
      day_name    ,
      is_weekend)
VALUES (
CAST(FORMAT(@current_date,'yyyyMMdd') AS INT),
@current_date,
YEAR(@current_date),
DATEPART(QUARTER,@current_date),
MONTH(@current_date),
DATENAME(MONTH,@current_date),
DAY(@current_date),
DATENAME(WEEKDAY,@current_date),
CASE
     WHEN DATEPART(WEEKDAY,@current_date) IN(1,7) THEN 1
     ELSE 0
END
);

SET @current_date = DATEADD(DAY,1,@current_date)
END;


SELECT * 
FROM GOLD.DimDate

--- DimCustomer
SELECT *
INTO Gold.DimCustomers
FROM [Silver].[Customers];

ALTER TABLE Gold.DimCustomers ALTER COLUMN customer_id INT NOT NULL;
ALTER TABLE Gold.DimCustomers ADD CONSTRAINT PK_DimCustomers PRIMARY KEY (customer_id); 

--- DimMerchant
SELECT *
INTO Gold.DimMerchants
FROM [Silver].[Merchants];

ALTER TABLE Gold.DimMerchants ALTER COLUMN merchant_id INT NOT NULL;
ALTER TABLE Gold.DimMerchants ADD CONSTRAINT PK_DimMerchant PRIMARY KEY (merchant_id); 


--- FactTransaction

SELECT 
[transaction_id],
CAST(FORMAT([trans_date_trans_time], 'yyyyMMdd')AS INT) AS date_key,
[customer_id],
[merchant_id],
[category],
[amt],
[tax_amt],
[discount_amt],
[currency],
[payment_method],
[channel],
[entry_mode],
[device_mode],
[transaction_status],
[trans_num],
[session_id],
[unix_time],
[is_fraud]
INTO Gold.FactTransaction
FROM [Silver].[Transactions]


ALTER TABLE Gold.FactTransaction ALTER COLUMN [transaction_id] INT NOT NULL;
ALTER TABLE Gold.FactTransaction ADD CONSTRAINT PK_FactTransaction PRIMARY KEY (transaction_id); 


---- foreign keys
ALTER TABLE Gold.FactTransaction
      ADD CONSTRAINT FK_Fact_DimDate FOREIGN KEY (date_key)
      REFERENCES Gold.DimDate ([datekey]);
GO

ALTER TABLE Gold.FactTransaction
      ADD CONSTRAINT FK_Fact_DimCustomers FOREIGN KEY (customer_id)
      REFERENCES Gold.DimCustomers ([customer_id]);
GO

ALTER TABLE Gold.FactTransaction
      ADD CONSTRAINT FK_Fact_DimMerchants FOREIGN KEY (merchant_id)
      REFERENCES Gold.DimMerchants ([merchant_id]);

--- Indexes

CREATE INDEX IX_Fact_Datekey    ON Gold.FactTransaction ([date_key]);
CREATE INDEX IX_CustomerId      ON Gold.FactTransaction ([customer_id]);
CREATE INDEX IX_Fact_MerchantId ON Gold.FactTransaction ([merchant_id]);
