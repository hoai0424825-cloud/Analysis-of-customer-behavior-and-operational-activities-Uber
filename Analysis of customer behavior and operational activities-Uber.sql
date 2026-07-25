## Operational Efficiency
SELECT COUNT(`Booking ID`) AS Total_Booking,(COUNT(`Booking ID`)/(SELECT COUNT(`Booking ID`)FROM booking))*100 AS Rate_Complete
FROM booking
WHERE `Booking Status`='Completed';
-- The trip completion rate for the entire dataset is 62%.
WITH Booking_Completed  AS (
SELECT `Vehicle Type`, COUNT(`Booking ID`) AS Total_Booking
FROM booking
WHERE `Booking Status`='Completed'
GROUP BY `Vehicle Type`
ORDER BY Total_Booking desc),
ALl_Booking AS
(SELECT `Vehicle Type`,COUNT(`Booking ID`) AS Total_Booking_2
FROM booking
GROUP BY `Vehicle Type`)
SELECT Booking_Completed.`Vehicle Type`, Total_Booking,Total_Booking_2,(Total_Booking/Total_Booking_2)*100 AS Rate_Compeleted
FROM Booking_Completed
LEFT JOIN ALl_Booking
ON Booking_Completed.`Vehicle Type`=ALl_Booking.`Vehicle Type`
ORDER BY Rate_Compeleted desc;
-- The completion rates for the different vehicle types are roughly similar, with Uber XL having the highest rate.
WITH Booking_Completed  AS (
SELECT `Vehicle Type`, COUNT(`Booking ID`) AS Total_Booking
FROM booking
WHERE `Booking Status` LIKE '%Cancelled%'
GROUP BY `Vehicle Type`
ORDER BY Total_Booking desc),
ALl_Booking AS
(SELECT `Vehicle Type`,COUNT(`Booking ID`) AS Total_Booking_2
FROM booking
GROUP BY `Vehicle Type`)
SELECT Booking_Completed.`Vehicle Type`, Total_Booking,Total_Booking_2,(Total_Booking/Total_Booking_2)*100 AS Rate_Compeleted
FROM Booking_Completed
LEFT JOIN ALl_Booking
ON Booking_Completed.`Vehicle Type`=ALl_Booking.`Vehicle Type`
ORDER BY Rate_Compeleted desc;
-- Cancellation rates across vehicle types show little variation, hovering around 25%. The highest cancellation rate is for Go Sedan.

WITH Booking_Completed  AS (
SELECT `Vehicle Type`, COUNT(`Booking ID`) AS Total_Booking
FROM booking
WHERE `Booking Status` LIKE 'No Driver Found'
GROUP BY `Vehicle Type`
ORDER BY Total_Booking desc),
ALl_Booking AS
(SELECT `Vehicle Type`,COUNT(`Booking ID`) AS Total_Booking_2
FROM booking
GROUP BY `Vehicle Type`)
SELECT Booking_Completed.`Vehicle Type`, Total_Booking,Total_Booking_2,(Total_Booking/Total_Booking_2)*100 AS Rate_No_Found
FROM Booking_Completed
LEFT JOIN ALl_Booking
ON Booking_Completed.`Vehicle Type`=ALl_Booking.`Vehicle Type`
ORDER BY Rate_No_Found desc;
-- The rate of vehicle unavailability is similar across the board, ranging from 6% to 7%, with Go Sedan recording the highest figure at 7.2%.
WITH Thoi_Gian AS (
SELECT `Avg VTAT`,`Avg CTAT`, booking.Time,booking.`Booking Status`,
       CASE WHEN EXTRACT(HOUR FROM Time) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM Time) BETWEEN 12 AND 13 THEN 'Noon'
            WHEN EXTRACT(HOUR FROM Time) BETWEEN 14 AND 17 THEN 'Afternoon'
            WHEN EXTRACT(HOUR FROM Time) BETWEEN 18 AND 23 THEN 'Night'
            ELSE 'Early morning' END AS Time_Of_Day
FROM grab.booking
)
SELECT Time_Of_Day,`Booking Status`,ROUND(AVG(`Avg VTAT`),2) AS Avg_VTAT,ROUND(AVG(`Avg CTAT`),2) AS Avg_CTAT
FROM Thoi_Gian
GROUP BY Time_Of_Day,`Booking Status`
-- The average time for drivers to reach the pickup location and the average waiting time remain relatively stable throughout the day; however, it is noticeable that trips cancelled by customers exhibit a higher Avg_VTAT compared to other statuses.

SELECT `Pickup Location`,COUNT(`Booking ID`) AS Total_Booking
FROM booking
WHERE `Booking Status`= 'No Driver Found'
GROUP BY `Pickup Location`
ORDER BY Total_Booking desc
LIMIT 5;
-- Top 5 locations where customers place bookings but no drivers accept them—for example, 'Old Gurgaon', 'Pataudi Chowk', and 'Paharganj'.
## Revenue & Demand Analysis
SELECT SUM(booking.`Booking Value`) AS Total_Amount
FROM booking
WHERE `Booking Status`='Completed';

SELECT `Vehicle Type`, SUM(`Booking Value`) AS Total_Amount
FROM booking
WHERE `Booking Status`='Completed'
GROUP BY `Vehicle Type`
ORDER BY Total_Amount DESC;
-- Revenue from completed trips amounted to 46,859,058 Rupees, with auto-rickshaws generating the highest revenue at 11,631,357 Rupees.
WITH Avg AS (SELECT `Vehicle Type`,ROUND(AVG(`Booking Value`),2) AS Avg_Amount, ROUND(AVG(`Ride Distance`),2) AS Avg_Distance
FROM booking WHERE `Booking Status`='Completed'GROUP BY `Vehicle Type`)
SELECT `Vehicle Type`,Avg_Distance,Avg_Amount,ROUND(Avg_Amount/Avg_Distance,2) AS Avg_Per_Trip
FROM Avg
GROUP BY `Vehicle Type`;
-- The average cost per trip is similar across vehicle types, indicating that there is no significant price difference between them.

SELECT `Payment Method`,COUNT(`Booking ID`) AS Total_Booking
FROM booking
WHERE `Booking Value`>(SELECT AVG(`Booking Value`) FROM booking WHERE `Booking Status`='Completed')
GROUP BY `Payment Method`
ORDER BY Total_Booking DESC;
-- UPI is the preferred payment method for high-value bookings.

## Root Cause & Experience Analysis
SELECT `Reason for cancelling by Customer`,COUNT(`Booking ID`) AS Total_Booking
FROM booking
WHERE `Booking Status`= 'Cancelled by Customer'
GROUP BY `Reason for cancelling by Customer`
ORDER BY Total_Booking DESC;
-- Common reasons for customer-initiated cancellations include: wrong address, change of plans, the driver not moving toward the pickup location, or the driver asking to cancel

SELECT `Driver Cancellation Reason`,COUNT(`Booking ID`) AS Total_Booking
FROM booking
WHERE `Booking Status`= 'Cancelled by Driver'
GROUP BY `Driver Cancellation Reason`
ORDER BY Total_Booking DESC;
-- Reasons for trip cancellations initiated by drivers typically include the following: customer-related issues, the customer coughing or appearing sick, personal or vehicle-related issues, and the number of passengers exceeding the permitted limit.

SELECT `Incomplete Rides Reason`,COUNT(`Booking ID`) AS Total_Booking
FROM booking
WHERE `Booking Status`= 'Incomplete'
GROUP BY `Incomplete Rides Reason`
ORDER BY Total_Booking DESC;
-- The trip was labeled "Incomplete" due to the following reasons: Customer Demand, Vehicle Breakdown, or Other Issue.
WITH Stats AS (
    SELECT
        AVG(`Driver Ratings`) AS avg_dr,
        AVG(`Customer Rating`) AS avg_cr,
        AVG(`Avg VTAT`) AS avg_vtat
    FROM grab.booking
    WHERE `Driver Ratings` IS NOT NULL
      AND `Customer Rating` IS NOT NULL
      AND `Avg VTAT` IS NOT NULL
)
SELECT
    SUM((b.`Driver Ratings` - s.avg_dr) * (b.`Customer Rating` - s.avg_cr)) /
    (SQRT(SUM((b.`Driver Ratings` - s.avg_dr) * (b.`Driver Ratings` - s.avg_dr))) *
     SQRT(SUM((b.`Customer Rating` - s.avg_cr) * (b.`Customer Rating` - s.avg_cr)))) AS Corr_Driver_Customer,

    SUM((b.`Avg VTAT` - s.avg_vtat) * (b.`Customer Rating` - s.avg_cr)) /
    (SQRT(SUM((b.`Avg VTAT` - s.avg_vtat) * (b.`Avg VTAT` - s.avg_vtat))) *
     SQRT(SUM((b.`Customer Rating` - s.avg_cr) * (b.`Customer Rating` - s.avg_cr)))) AS Corr_VTAT_Customer
FROM
    grab.booking b
CROSS JOIN
    Stats s
WHERE
    b.`Driver Ratings` IS NOT NULL
    AND b.`Customer Rating` IS NOT NULL
    AND b.`Avg VTAT` IS NOT NULL;
-- -	The Pearson correlation coefficient between Avg VTAT and Customer Rating is -0.004, indicating no linear relationship. The time spent waiting for vehicle dispatch does not affect the customer's final satisfaction level on the app.

## Time-Series & Loyalty Analysis
SELECT EXTRACT(HOUR  FROM Time) AS Time_Group,COUNT(`Booking ID`) AS Total_Booking
FROM booking
GROUP BY Time_Group
ORDER BY Total_Booking DESC
-- The 5:00 PM to 7:00 PM time slot is the peak period.
SELECT EXTRACT(HOUR  FROM Time) AS Time_Group,COUNT(`Booking ID`) AS Total_Booking
FROM booking
WHERE `Booking Status`='No Driver Found'
GROUP BY Time_Group
ORDER BY Total_Booking DESC;
-- This time slot also frequently sees bookings where no driver is found

SELECT Weekday,COUNT(`Booking ID`) AS Total_Booking
FROM booking
GROUP BY  Weekday
ORDER BY Total_Booking DESC;
-- The demand for booking rides is the same across weekdays.

WITH Customer_Metric AS (
SELECT `Customer ID`,COUNT(`Booking ID`) AS Total_Booking,
           SUM(
           CASE WHEN `Booking Status`='Completed' THEN `Booking Value` ELSE 0 END
           ) AS Total_Amount
FROM booking
GROUP BY `Customer ID`),
Customer_Segemnt AS (
SELECT `Customer ID`,Total_Booking,Total_Amount,
       CASE
           WHEN Total_Booking > 2 AND Total_Amount> (SELECT avg(`Booking Value`) FROM booking WHERE `Booking Status`='Completed') THEN 'Loyal Customer'
           WHEN Total_Booking > 1 AND  Total_Amount > 200 THEN 'Regular'
           ELSE 'New / Low Value' END AS Customer_Segment1
FROM Customer_Metric
ORDER BY Total_Booking DESC)
SELECT Customer_Segment1,COUNT(`Customer ID`) AS Total_Customer
FROM Customer_Segemnt
GROUP BY Customer_Segment1;
-- This is the number of customers in each segment.

WITH Ordered_Bookings AS (
    SELECT
        `Customer ID`,
        `Booking ID`,
        `Booking Status`,
        -- Lấy trạng thái của chuyến đi liền sau
        LEAD(`Booking Status`, 1) OVER(PARTITION BY `Customer ID` ORDER BY `Date` ASC, `Time` ASC) AS next_status_1,
        -- Lấy trạng thái của chuyến đi sau đó 2 lượt
        LEAD(`Booking Status`, 2) OVER(PARTITION BY `Customer ID` ORDER BY `Date` ASC, `Time` ASC) AS next_status_2
    FROM grab.booking
)
SELECT DISTINCT
    `Customer ID`
FROM Ordered_Bookings
WHERE `Booking Status` = 'Cancelled by Customer'
  AND next_status_1 = 'Cancelled by Customer'
  AND next_status_2 = 'Cancelled by Customer';
-- No customer has cancelled more than two consecutive trips.
