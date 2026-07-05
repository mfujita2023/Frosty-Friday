use role sysadmin;

create  or replace database db_week103;
create or replace schema sales;
CREATE TABLE sales.transactions ( id INT, customer_name STRING, amount DECIMAL(10,2), transaction_date TIMESTAMP );

-- テーブルができたか確認
select * from DB_WEEK103.SALES.TRANSACTIONS;

-- データを入れる
INSERT INTO sales.transactions (id, customer_name, amount, transaction_date) VALUES (1, 'Alice', 100.00, '2024-07-20 10:00:00'), (2, 'Bob', 200.00, '2024-07-20 11:00:00'), (3, 'Charlie', 300.00, '2024-07-20 12:00:00');

-- データの中身を確認する
select * from DB_WEEK103.SALES.TRANSACTIONS;
-- 以下のように3件表示されていたらOK
/* ID	CUSTOMER_NAME	AMOUNT	TRANSACTION_DATE
1	Alice	100.00	2024-07-20 10:00:00.000
2	Bob	200.00	2024-07-20 11:00:00.000
3	Charlie	300.00	2024-07-20 12:00:00.000 */

-- ■データ加工1
-- id1のAmountを1.1倍、id2を削除
UPDATE sales.transactions SET amount = amount * 1.1 WHERE id = 1;
DELETE FROM sales.transactions WHERE id = 2;

-- id2が削除され、id1が1.1倍に
select * from sales.transactions;
/*
ID	CUSTOMER_NAME	AMOUNT	TRANSACTION_DATE
1	Alice	110.00	2024-07-20 10:00:00.000
3	Charlie	300.00	2024-07-20 12:00:00.000
*/


-- ■データ加工2
-- id3を削除
DELETE FROM sales.transactions WHERE id = 3;

--id3が削除され1のみに
table sales.transactions;
/*
ID	CUSTOMER_NAME	AMOUNT	TRANSACTION_DATE
1	Alice	110.00	2024-07-20 10:00:00.000
*/

-- ■データ加工3
-- id1を複製してInsert
INSERT INTO sales.transactions (id, customer_name, amount, transaction_date)
SELECT id, customer_name, amount, transaction_date FROM sales.transactions;

-- id1が複製されて1行挿入された
table sales.transactions;
/*
ID	CUSTOMER_NAME	AMOUNT	TRANSACTION_DATE
1	Alice	110.00	2024-07-20 10:00:00.000
1	Alice	110.00	2024-07-20 10:00:00.000
*/

-- タイムトラベルする
-- クローン先のスキーマを作成
create schema db_week103.clone;
-- https://docs.snowflake.com/ja/user-guide/data-time-travel#querying-historical-data
-- ■初期状態
-- モニタリング - クエリ履歴からクエリIDを検索しInsertの後のSelect時点のクエリIDをコピーして3レコードあることを確認する
SELECT * FROM db_week103.sales.transactions before(statement => '01c17f3e-0003-2322-0000-00033aea2d71');

-- 初期状態のデータをクローンする
create or replace table db_week103.clone.db_week103_init_query_ID as(
SELECT * FROM db_week103.sales.transactions before(statement => '01c17f3e-0003-2322-0000-00033aea2d71'));

-- クローン出来たか確認
table db_week103.clone.db_week103_init_query_ID;
/*
ID	CUSTOMER_NAME	AMOUNT	TRANSACTION_DATE
1	Alice	100.00	2024-07-20 10:00:00.000
2	Bob	200.00	2024-07-20 11:00:00.000
3	Charlie	300.00	2024-07-20 12:00:00.000
*/

-- ■データ加工1の後の状態をクローン
-- クローン前の状態を確認
SELECT * FROM db_week103.sales.transactions before(statement => '01c17f43-0003-2322-0000-00033aea2fd5');

create or replace table db_week103.clone.db_week103_data_process1 as(
SELECT * FROM db_week103.sales.transactions before(statement => '01c17f43-0003-2322-0000-00033aea2fd5'));

-- クローン後のデータ内容を確認
SELECT * FROM db_week103.clone.db_week103_data_process1;

-- ■データ加工2の後の状態
SELECT * FROM db_week103.sales.transactions before(statement => '01c17f44-0003-2322-0000-00033aea400d');
/*
ID	CUSTOMER_NAME	AMOUNT	TRANSACTION_DATE
1	Alice	110.00	2024-07-20 10:00:00.000
*/

create or replace table db_week103.clone.db_week103_data_process2 as(
SELECT * FROM db_week103.sales.transactions BEFORE(STATEMENT => '01c17f44-0003-2322-0000-00033aea400d'));

table DB_WEEK103.CLONE.DB_WEEK103_DATA_PROCESS2;
