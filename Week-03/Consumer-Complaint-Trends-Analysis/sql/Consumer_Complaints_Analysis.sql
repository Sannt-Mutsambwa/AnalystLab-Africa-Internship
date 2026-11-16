/*
=========================================================
PROJECT: Consumer Complaint Trends and Response
         Intelligence Platform
DATA SOURCE: Consumer Financial Protection Bureau (CFPB)
COMPANY: Bank of America
PERIOD: 01 May 2017 - 28 August 2023
DATABASE: consumer_complaints
TABLE: complaints

PURPOSE:
To analyse consumer complaint patterns, product and issue
distributions, company response outcomes, and complaint
forwarding intervals.

NOTE:
Complaint volume does not establish complaint rates or prove misconduct. 
Forwarding intervals measure the time between CFPB receipt and company receipt, not company
resolution time.

=========================================================
*/

USE consumer_complaints;


/*=========================================================
SECTION 1: DATA QUALITY ASSESSMENT
=========================================================*/
SELECT
    COUNT(*) AS total_records,

    COUNT(DISTINCT `Complaint ID`) AS unique_complaint_ids,

    SUM(CASE
        WHEN `Sub-product` = '' THEN 1
        ELSE 0
    END) AS missing_subproducts,

    SUM(CASE
        WHEN `Sub-issue` = '' THEN 1
        ELSE 0
    END) AS missing_subissues,

    SUM(CASE
        WHEN `Company public response` = '' THEN 1
        ELSE 0
    END) AS missing_public_responses,

    SUM(CASE
        WHEN `Timely response?` = '' THEN 1
        ELSE 0
    END) AS missing_timely_responses,

    SUM(CASE
        WHEN `Forwarding interval (days)` < 0 THEN 1
        ELSE 0
    END) AS negative_forwarding_intervals,

    SUM(CASE
        WHEN `Forwarding interval (days)` <>
             DATEDIFF(`Date received`, `Date submitted`)
        THEN 1
        ELSE 0
    END) AS forwarding_interval_mismatches

FROM complaints;
/*=========================================================
SECTION 2: KEY PERFORMANCE INDICATORS (KPIs)
=========================================================*/

/* Overall complaint and response metrics */
SELECT
    COUNT(*) AS total_complaints,

    SUM(CASE
        WHEN `Timely response?` = 'Yes' THEN 1
        ELSE 0
    END) AS timely_yes,

    SUM(CASE
        WHEN `Timely response?` = 'No' THEN 1
        ELSE 0
    END) AS timely_no,

    ROUND(
        100.0 * SUM(CASE WHEN `Timely response?` = 'Yes' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN `Timely response?` IN ('Yes', 'No') THEN 1 ELSE 0 END), 0),
        2
    ) AS timely_response_percentage,

    ROUND(AVG(`Forwarding interval (days)`), 2) AS average_forwarding_interval_days,

    SUM(CASE
        WHEN `Forwarding interval (days)` = 0 THEN 1
        ELSE 0
    END) AS same_day_complaints,

    ROUND(
        100.0 * SUM(CASE WHEN `Forwarding interval (days)` = 0 THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS same_day_forwarding_percentage,

    SUM(CASE
        WHEN `Company response to consumer` = 'In progress' THEN 1
        ELSE 0
    END) AS in_progress_complaints

FROM complaints;
/*=========================================================
SECTION 3: COMPLAINT DISTRIBUTION
=========================================================*/

/* 3.1 Complaint distribution by product */
SELECT
    Product,
    COUNT(*) AS complaint_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM complaints), 2) AS percentage_of_total
FROM complaints
GROUP BY Product
ORDER BY complaint_count DESC;
/* 3.2 Most frequently reported complaint issues */

SELECT
    Issue,
    COUNT(*) AS complaint_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM complaints), 2) AS percentage_of_total
FROM complaints
GROUP BY Issue
ORDER BY complaint_count DESC;
/* 3.3 Complaint issues within each product */

SELECT
    Product,
    Issue,
    COUNT(*) AS complaint_count
FROM complaints
GROUP BY Product, Issue
ORDER BY Product, complaint_count DESC;


/* 3.4 Most frequently reported sub-issues
   Blank sub-issues are excluded because they represent
   missing detail, not missing complaints. */
   SELECT
    Product,
    Issue,
    `Sub-issue`,
    COUNT(*) AS complaint_count
FROM complaints
WHERE `Sub-issue` <> ''
GROUP BY Product, Issue, `Sub-issue`
ORDER BY complaint_count DESC;


/*=========================================================
SECTION 4: COMPANY RESPONSE ANALYSIS
=========================================================*/
/* 4.1 Distribution of company public response categories
   Blank values mean no public response category was recorded.
   They do not automatically mean the company did not respond. */

SELECT
    CASE
        WHEN `Company public response` = ''
            THEN 'No public response recorded'
        ELSE `Company public response`
    END AS public_response_category,
    COUNT(*) AS complaint_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM complaints), 2) AS percentage_of_total
FROM complaints
GROUP BY public_response_category
ORDER BY complaint_count DESC;

/* 4.2 Company response outcomes */

SELECT
    `Company response to consumer` AS response_outcome,
    COUNT(*) AS complaint_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM complaints), 2) AS percentage_of_total
FROM complaints
GROUP BY `Company response to consumer`
ORDER BY complaint_count DESC;


/* 4.3 Timely response distribution
   The blank category is kept separate from Yes and No. */
SELECT
    CASE
        WHEN `Timely response?` = ''
            THEN 'Not recorded'
        ELSE `Timely response?`
    END AS timely_response_status,
    COUNT(*) AS complaint_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM complaints), 2) AS percentage_of_total
FROM complaints
GROUP BY timely_response_status
ORDER BY complaint_count DESC;

/*=========================================================
SECTION 5: TIMELINE ANALYSIS
=========================================================*/

/* 5.1 Annual complaint volume */

SELECT
    `Submission year`,
    COUNT(*) AS complaint_count
FROM complaints
GROUP BY `Submission year`
ORDER BY `Submission year`;

/* 5.2 Monthly complaint volume */

SELECT
    `Submission year-month`,
    COUNT(*) AS complaint_count
FROM complaints
GROUP BY `Submission year-month`
ORDER BY `Submission year-month`;


/* 5.3 Complaint volume by day of the week */

SELECT
    `Submission day`,
    COUNT(*) AS complaint_count
FROM complaints
GROUP BY `Submission day`
ORDER BY FIELD(
    `Submission day`,
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
);


/*=========================================================
SECTION 6: CFPB FORWARDING INTERVAL ANALYSIS
=========================================================*/

/* Important:
   Forwarding interval measures the time between the CFPB
   receiving a complaint and forwarding it to the company.
   It does NOT measure the company's resolution time.
*/


/* 6.1 Overall forwarding interval statistics */

SELECT
    COUNT(*) AS total_complaints,
    ROUND(AVG(`Forwarding interval (days)`), 2) AS average_days,
    MIN(`Forwarding interval (days)`) AS minimum_days,
    MAX(`Forwarding interval (days)`) AS maximum_days,
    SUM(CASE WHEN `Forwarding interval (days)` = 0 THEN 1 ELSE 0 END) AS same_day_count,
    ROUND(
        100.0 * SUM(CASE WHEN `Forwarding interval (days)` <= 2 THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS forwarded_within_two_days_percentage
FROM complaints;


/* 6.2 Distribution by forwarding category */

SELECT
    `Forwarding Category`,
    COUNT(*) AS complaint_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM complaints), 2) AS percentage_of_total,
    ROUND(AVG(`Forwarding interval (days)`), 2) AS average_forwarding_days
FROM complaints
GROUP BY `Forwarding Category`
ORDER BY complaint_count DESC;


/* 6.3 Forwarding category distribution by year */

SELECT
    `Submission year`,
    `Forwarding Category`,
    COUNT(*) AS complaint_count,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY `Submission year`),
        2
    ) AS percentage_within_year
FROM complaints
GROUP BY `Submission year`, `Forwarding Category`
ORDER BY `Submission year`, complaint_count DESC;


/* 6.4 Forwarding interval patterns by product */

SELECT
    Product,
    COUNT(*) AS total_complaints,

    SUM(CASE
        WHEN `Forwarding Category` = 'Same day' THEN 1
        ELSE 0
    END) AS same_day_count,

    ROUND(
        100.0 * SUM(CASE WHEN `Forwarding Category` = 'Same day' THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS same_day_percentage,

    SUM(CASE
        WHEN `Forwarding Category` IN ('Long', 'Extended') THEN 1
        ELSE 0
    END) AS long_or_extended_count,

    ROUND(
        100.0 * SUM(CASE WHEN `Forwarding Category` IN ('Long', 'Extended') THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS long_or_extended_percentage,

    ROUND(AVG(`Forwarding interval (days)`), 2) AS average_forwarding_days

FROM complaints
GROUP BY Product
ORDER BY total_complaints DESC;


/*=========================================================
END OF ANALYSIS SCRIPT
=========================================================*/