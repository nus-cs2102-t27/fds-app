const express = require("express");
const auth = require("./auth");
const res = require("./restaurants");
const menu = require("./menu")

const apiRouter = express.Router();

apiRouter.get("/health", (req, res) => {
    res.sendStatus(200);
});
apiRouter.use("/auth", auth);
apiRouter.use("/res", res);
apiRouter.use("/menu", menu);

module.exports = apiRouter;
