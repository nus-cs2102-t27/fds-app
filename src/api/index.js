const express = require("express");
const auth = require("./auth");

const apiRouter = express.Router();

apiRouter.get("/health", (req, res) => {
    res.sendStatus(200);
});
apiRouter.use("/auth", auth);

module.exports = apiRouter;
