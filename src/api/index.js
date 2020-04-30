const express = require("express");
const auth = require("./auth");
const res = require("./restaurants");
const menu = require("./menu");
const ord = require("./orders");
const del = require("./delivery");

const apiRouter = express.Router();

apiRouter.get("/health", (req, res) => {
    res.sendStatus(200);
});
apiRouter.use("/auth", auth);
apiRouter.use("/res", res);
apiRouter.use("/menu", menu);
apiRouter.use("/ord", ord);
apiRouter.use("/del", del);

module.exports = apiRouter;
