const express = require("express");
const pgPool = require("../pg-pool");

const riderSumRouter = express.Router();
/*
const SalaryQuery =
    `SELECT ((EXTRACT(year FROM age(CURRENT_DATE, U.date_joined)) * 12 + EXTRACT(month FROM age(CURRENT_DATE, U.date_joined)) + 10) * F.monthly_base_salary)
    + ((SELECT COUNT(*) FROM Deliveries where uid = $1) * 2))
    AS monthly_base_salary
    FROM Users U, FTRiders F
    WHERE U.uid = $1`;

*/
      

riderSumRouter.get("/ptrider", async (req, res) => {
    const { rows: hoursWorked } = await pgPool.query(SalaryQuery, [req.cookies.uid]);
    const { rows: salary } = await pgPool.query(SalaryQuery, [req.cookies.uid]);
    console.log(salary);
    res.send(salary);
});


function formatDate(date) {
    var year = date.getFullYear(),
        month = monthNames[date.getMonth()];
        day = date.getDate(),
        hour = date.getHours();

    return `${day} ${month} ${year}`;
}

module.exports = riderSumRouter;