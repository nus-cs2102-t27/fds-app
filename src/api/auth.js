const express = require("express");
const pgPool = require("../pg-pool");

const authRouter = express.Router();

const SIGNUP_QUERY = `SELECT NewCustomer($1, $2, $3, $4, $5, $6, $7, $8, $9)`;

authRouter.post("/login", async (req, res) => {
    const { username, password, userType } = req.body;

    const { rows } = await pgPool.query(getLoginQuery(userType), [username]);
    if (rows.length === 0) {
        console.log("User not found");
        res.sendStatus(404);
        return;
    }
    const user = rows[0];
    if (user.password === password) {
		res.cookie("uid", user.uid);
		res.cookie("role", userType);
        res.redirect(getRedirectionForUserType(userType));
        return;
    } 
    res.sendStatus(401);
});

authRouter.post("/signup", async (req, res) => {
    const { 
        name, 
        username, 
        password, 
        passwordRetype,
        contact,
        email,
        address,
        cardNumber,
        cvc,
        defaultPayment
    } = req.body;

    if (password !== passwordRetype) {
        res.status(400).send("Passwords don't match");
        return;
    }

    await pgPool.query(SIGNUP_QUERY, [name, username, password, contact, email,
                                        address, cardNumber, cvc, defaultPayment]);
    res.redirect("/app/signup-success.html");
    return;
})

authRouter.get("/me", async (req, res) => {
	const userId = req.cookies.uid;
	const role = req.cookies.role;
    const { rows } = await pgPool.query(getUserByUidQuery(role), [userId]);
    if (rows.length === 0) {
        console.log("User not found");
        res.sendStatus(404);
        return;
    }
    res.send(rows[0]);
});

authRouter.get("/me/:col", async (req, res) => {
	const userId = req.cookies.uid;
	const role = req.cookies.role;
    const { rows } = await pgPool.query(getUserByUidQuery(role), [userId]);
    if (rows.length === 0) {
        console.log("User not found");
        res.sendStatus(404);
        return;
    }
    const col = req.params.col;
    if (!(col in rows[0])) {
        console.log(`column ${col} does not exist`);
        res.sendStatus(404);
        return;
    }
    res.send(rows[0][col]);
});

function getTableForUserType(userType) {
    switch (userType) {
        case "customer":
            return "Customers";
        case "staff":
            return "RestaurantStaff";
        case "manager":
            return "FDSManager";
        case "rider":
            return "Riders";
    }
}

function getLoginQuery(userType) {
	const table = getTableForUserType(userType);
	return `SELECT * FROM Users NATURAL JOIN ${table} WHERE username = $1`;
}

function getUserByUidQuery(userType) {
	const table = getTableForUserType(userType);
	return `SELECT * FROM Users NATURAL JOIN ${table} WHERE uid = $1`;
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

