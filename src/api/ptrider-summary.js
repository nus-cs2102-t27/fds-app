const express = require("express");
const pgPool = require("../pg-pool");

const riderSumRouter = express.Router();
      
const LifetimeSalaryQuery =
    `SELECT (((((EXTRACT(days FROM (now() - U.date_joined)) / 7)::int) + 1) * P.weekly_base_salary) 
    + ((SELECT COUNT(*) FROM Deliveries where uid = $1) * 2))
    AS lifetime_salary
    FROM Users U, PTRiders P
    WHERE U.uid = $1`;

const WeeklySalaryQuery =
    `SELECT ((P.weekly_base_salary)  
    + ((SELECT COUNT(*) FROM Deliveries D, Users U
            WHERE
            D.t1 > current_date - interval '7 days'
            AND D.collected = TRUE
            AND U.uid = $1) * 2))
    AS weekly_base_salary
    FROM Users U, PTRiders P
    WHERE U.uid = $1`;

const WeeklyOrdersQuery =
    `(SELECT COUNT(*) 
        AS weekly_orders
            FROM Deliveries D, Users U
            WHERE
            D.t1 > current_date - interval '7 days'
            AND D.collected = TRUE
            AND U.uid = $1)`;

const HoursWorkedQuery = 
    `SELECT COUNT(*)
        AS hours_worked
            FROM PTWorkSchedules
            WHERE uid = $1`;


riderSumRouter.get("/ptrider", async (req, res) => {
    const { rows: ordersThisWeek } = await pgPool.query(WeeklyOrdersQuery, [req.cookies.uid]);
    const { rows: hoursWorkedThisWeek } = await pgPool.query(HoursWorkedQuery, [req.cookies.uid]);
    const { rows: lifetimeSalary } = await pgPool.query(LifetimeSalaryQuery, [req.cookies.uid]);
    const { rows: salary } = await pgPool.query(WeeklySalaryQuery, [req.cookies.uid]);
    lifetimeSalary[0].hoursWorkedThisWeek = hoursWorkedThisWeek[0].hours_worked;
    lifetimeSalary[0].ordersThisWeek = ordersThisWeek[0].weekly_orders;
    lifetimeSalary[0].salary = salary[0].weekly_base_salary;
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