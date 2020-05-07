const express = require("express");
const pgPool = require("../pg-pool");

const riderSumRouter = express.Router();

const LifetimeSalaryQuery =
    `SELECT ((EXTRACT(year FROM age(CURRENT_DATE, U.date_joined)) * 12 + EXTRACT(month FROM age(CURRENT_DATE, U.date_joined)) + 10) * F.monthly_base_salary)
    + ((SELECT COUNT(*) FROM Deliveries where uid = $1) * 2)
    AS lifetime_salary
    FROM Users U, FTRiders F
    WHERE U.uid = $1`;

const MonthlySalaryQuery =
    `SELECT ((F.monthly_base_salary)  
    + ((SELECT COUNT(*) FROM Deliveries D, Users U
            WHERE
            D.t1 > current_date - interval '1 month'
            AND D.collected = TRUE
            AND U.uid = $1) * 2))
    AS monthly_base_salary
    FROM Users U, FTRiders F
    WHERE U.uid = $1`;

const MonthlyOrdersQuery =
    `(SELECT COUNT(*)
        AS monthly_orders
            FROM Deliveries D, Users U
            WHERE
            D.t1 > current_date - interval '1 month'
            AND D.collected = TRUE
            AND U.uid = $1)`;

const HoursWorkedQuery = 
    `SELECT COUNT(*) * 8
        AS hours_worked
            FROM FTWorkSchedules
            WHERE uid = $1`;
   

riderSumRouter.get("/ftrider", async (req, res) => {
    const { rows: ordersThisMonth } = await pgPool.query(MonthlyOrdersQuery, [req.cookies.uid]);
    const { rows: hoursWorkedThisMonth } = await pgPool.query(HoursWorkedQuery, [req.cookies.uid]);
    const { rows: lifetimeSalary } = await pgPool.query(LifetimeSalaryQuery, [req.cookies.uid]);
    const { rows: salary } = await pgPool.query(MonthlySalaryQuery, [req.cookies.uid]);
    lifetimeSalary[0].hoursWorkedThisMonth = hoursWorkedThisMonth[0].hours_worked;
    lifetimeSalary[0].ordersThisMonth = ordersThisMonth[0].monthly_orders;
    lifetimeSalary[0].salary = salary[0].monthly_base_salary;
    console.log(lifetimeSalary);
    res.send(lifetimeSalary);
});


function formatDate(date) {
    var year = date.getFullYear(),
        month = monthNames[date.getMonth()];
        day = date.getDate(),
        hour = date.getHours();

    return `${day} ${month} ${year}`;
}

module.exports = riderSumRouter;