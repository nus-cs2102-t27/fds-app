const express = require("express");
const pgPool = require("../pg-pool");

const riderSumRouter = express.Router();
      
const LifetimeSalaryQuery =
    `SELECT ((((EXTRACT(days FROM (now() - U.date_joined)) / 7)::int) * P.weekly_base_salary) 
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


riderSumRouter.get("/ptrider", async (req, res) => {
    //const { rows: ordersThisMonth } = await pgPool.query(LifetimeSalaryQuery, [req.cookies.uid]);
    //const { rows: hoursWorked } = await pgPool.query(LifetimeSalaryQuery, [req.cookies.uid]);
    const { rows: lifetimeSalary } = await pgPool.query(LifetimeSalaryQuery, [req.cookies.uid]);
    const { rows: salary } = await pgPool.query(WeeklySalaryQuery, [req.cookies.uid]);
    lifetimeSalary[0].salary = salary[0].weekly_base_salary;
    console.log(salary);
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