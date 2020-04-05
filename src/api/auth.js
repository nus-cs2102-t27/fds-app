const express = require("express");
const pgPool = require("../pg-pool");

const authRouter = express.Router();

authRouter.post("/login", async (req, res) => {
    const username = req.body.username;
    const password = req.body.password;
    const userType = req.body.userType;

    const { rows } = await pgPool.query(getQueryForUserType(userType), [username]);
    if (rows.length === 0) {
        console.log("User not found");
        res.sendStatus(404);
        return;
    }
    const user = rows[0];
    if (user.password === password) {
        res.cookie(JSON.stringify({ ...user, role: userType }));
        res.redirect(getRedirectionForUserType(userType));
        return;
    } 
    res.sendStatus(401);
});

function getQueryForUserType(userType) {
    switch (userType) {
        case "customer":
            return "SELECT * FROM Users NATURAL JOIN Customers WHERE username = $1";
        case "staff":
            return "SELECT * FROM Users NATURAL JOIN RestaurantStaff WHERE username = $1";
        case "manager":
            return "SELECT * FROM Users NATURAL JOIN FDSManager WHERE username = $1";
        case "rider":
            return "SELECT * FROM Users NATURAL JOIN Riders WHERE username = $1";
    }
}

function getRedirectionForUserType(userType) {
    switch (userType) {
        case "customer":
            return "/app/customer.html"
        case "staff":
            return "/app/staff.html"
        case "manager":
            return "/app/manager.html"
        case "rider":
            return "/app/rider.html"
    }
}

module.exports = authRouter;

