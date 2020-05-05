const express = require("express");
const pgPool = require("../pg-pool");
const userUtil = require("../util/userUtil");
const getRedirectionForUserType = userUtil.getRedirectionForUserType;

const authRouter = express.Router();

const SIGNUP_QUERY = `SELECT NewCustomer($1, $2, $3, $4, $5, $6, $7, $8, $9)`;

const checkIfPTQuery = `SELECT * FROM PTRiders WHERE uid = $1`;

authRouter.post("/login", async (req, res) => {
    const { username, password } = req.body;
    let { userType } = req.body;

    const { rows } = await pgPool.query(getLoginQuery(userType), [username]);
    if (rows.length === 0) {
        console.log("User not found");
        res.sendStatus(404);
        return;
    }
    const user = rows[0];
    if (userType === "rider") {
        const { rows } = await pgPool.query(checkIfPTQuery, [user.uid]);
        if (rows.length === 0) {
            userType = "ftrider";
        } else {
            userType = "ptrider";
        }
    }
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

authRouter.get("/user_home", async (req, res) => {
    const role = req.cookies.role;
    res.redirect(getRedirectionForUserType(role));
});

authRouter.get("/me/:col", async (req, res) => {
    try {
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
}catch(e) {
    console.log(e);
}
});

function getTableForUserType(userType) {
    switch (userType) {
        case "customer":
            return "Customers";
        case "staff":
            return "RestaurantStaff";
        case "manager":
            return "FDSManager";
        case "ptrider":
        case "ftrider":
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

module.exports = authRouter;

