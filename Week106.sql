-- Dynamic data masking implementation with role-based access control for customer sensitive data
-- Co-authored with CoCo
-- https://www.frostyfri.day/en/challenges/blog/2024/08/16/week-106-security-governance

-- 今週のテーマは、Snowflakeの動的データマスキング機能を活用して、ユーザーの役割に基づいて機密情報を保護することです。

-- 貴社SecureDataCorpは先日、セキュリティ監査を受け、機密性の高い顧客情報を保護するためのデータマスキング手法の改善が必要であることが明らかになりました。
-- 監査の結果、クレジットカード番号、メールアドレス、口座残高などの機密データが、適切な権限を持たないユーザーにもアクセス可能になっていたことが判明しました。貴社の任務は、Snowflakeのダイナミックデータマスキングを実装し、権限のあるユーザーのみが機密情報を閲覧でき、それ以外のユーザーにはマスキングされたデータのみが表示されるようにすることです。

-- ============================================================
-- 初期設定
-- ============================================================
-- データベース作成
CREATE DATABASE dynamic_data_masking_db;
USE DATABASE dynamic_data_masking_db;

CREATE TABLE customer_data (
    customer_id INTEGER,
    name STRING,
    email STRING,
    phone STRING,
    address STRING,
    credit_card_number STRING,
    account_balance FLOAT
);

INSERT INTO customer_data (customer_id, name, email, phone, address, credit_card_number, account_balance) VALUES
    (1, 'John Doe', 'john.doe@example.com', '123-456-7890', '123 Main St', '4111111111111111', 15000.00),
    (2, 'Jane Smith', 'jane.smith@example.com', '234-567-8901', '456 Elm St', '4222222222222222', 8500.00),
    (3, 'Alice Johnson', 'alice.johnson@example.com', '345-678-9012', '789 Oak St', '4333333333333333', 3000.00),
    (4, 'Bob Brown', 'bob.brown@example.com', '456-789-0123', '101 Pine St', '4444444444444444', 500.00),
    (5, 'Charlie Davis', 'charlie.davis@example.com', '567-890-1234', '202 Maple St', '4555555555555555', 12000.00),
    (6, 'Diana Evans', 'diana.evans@example.com', '678-901-2345', '303 Cedar St', '4666666666666666', 2000.00),
    (7, 'Frank Green', 'frank.green@example.com', '789-012-3456', '404 Birch St', '4777777777777777', 30000.00),
    (8, 'Hannah White', 'hannah.white@example.com', '890-123-4567', '505 Willow St', '4888888888888888', 4500.00),
    (9, 'Ian Black', 'ian.black@example.com', '901-234-5678', '606 Aspen St', '4999999999999999', 7500.00),
    (10, 'Jill Blue', 'jill.blue@example.com', '012-345-6789', '707 Cherry St', '4000000000000000', 500.00);

-- 初期構築ロジックのあと結果を確認する
table dynamic_data_masking_db.public.customer_data;

-- ロールAdminを作る
create role admin;

-- ロール：Managerを作る
create role manager;

-- ロール：Analystを作る
create role analyst;

-- 自分のユーザーを各ロールに割り当て
GRANT ROLE admin TO USER MFUJITA2026;
GRANT ROLE manager TO USER MFUJITA2026;
GRANT ROLE analyst TO USER MFUJITA2026;

-- テーブルへのアクセス権限を付与
GRANT USAGE ON DATABASE dynamic_data_masking_db TO ROLE admin;
GRANT USAGE ON DATABASE dynamic_data_masking_db TO ROLE manager;
GRANT USAGE ON DATABASE dynamic_data_masking_db TO ROLE analyst;
GRANT USAGE ON SCHEMA public TO ROLE admin;
GRANT USAGE ON SCHEMA public TO ROLE manager;
GRANT USAGE ON SCHEMA public TO ROLE analyst;
GRANT SELECT ON TABLE customer_data TO ROLE admin;
GRANT SELECT ON TABLE customer_data TO ROLE manager;
GRANT SELECT ON TABLE customer_data TO ROLE analyst;

-- ============================================================
-- 動的データマスキングポリシーの作成
-- ============================================================

-- クレジットカード番号のマスキングポリシー
-- Admin: フルデータ表示 / Manager: 下4桁のみ表示 / Analyst: 完全マスク
CREATE OR REPLACE MASKING POLICY credit_card_mask AS (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('ADMIN', 'ACCOUNTADMIN', 'SYSADMIN') THEN val
        WHEN CURRENT_ROLE() = 'MANAGER' THEN CONCAT('XXXX-XXXX-XXXX-', RIGHT(val, 4))
        ELSE '****-****-****-****'
    END;

-- メールアドレスのマスキングポリシー
-- Admin: フルデータ表示 / Manager & Analyst: ドメイン部分をマスク
CREATE OR REPLACE MASKING POLICY email_mask AS (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('ADMIN', 'ACCOUNTADMIN', 'SYSADMIN') THEN val
        ELSE CONCAT(SPLIT_PART(val, '@', 1), '@***.***')
    END;

-- 口座残高のマスキングポリシー
-- Admin: フルデータ表示 / Manager: 千の位に丸める / Analyst: 完全マスク
CREATE OR REPLACE MASKING POLICY account_balance_mask AS (val FLOAT) RETURNS FLOAT ->
    CASE
        WHEN CURRENT_ROLE() IN ('ADMIN', 'ACCOUNTADMIN', 'SYSADMIN') THEN val
        WHEN CURRENT_ROLE() = 'MANAGER' THEN ROUND(val, -3)::FLOAT
        ELSE NULL
    END;

-- ============================================================
-- マスキングポリシーをテーブルのカラムに適用
-- ============================================================
ALTER TABLE customer_data MODIFY COLUMN credit_card_number
    SET MASKING POLICY credit_card_mask;

ALTER TABLE customer_data MODIFY COLUMN email
    SET MASKING POLICY email_mask;

ALTER TABLE customer_data MODIFY COLUMN account_balance
    SET MASKING POLICY account_balance_mask;

-- ============================================================
-- 各ロールでの動作確認
-- ============================================================

-- Adminロールでの確認（全データが見える）
USE ROLE admin;
SELECT * FROM dynamic_data_masking_db.public.customer_data;

-- Managerロールでの確認（部分マスク）
USE ROLE manager;
SELECT * FROM dynamic_data_masking_db.public.customer_data;

-- Analystロールでの確認（完全マスク）
USE ROLE analyst;
SELECT * FROM dynamic_data_masking_db.public.customer_data;

-- ACCOUNTADMINに戻す
USE ROLE ACCOUNTADMIN;
SELECT * FROM dynamic_data_masking_db.public.customer_data;
