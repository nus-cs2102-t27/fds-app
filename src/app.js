const express = require("express");
const api = require("./api");
const bodyParser = require("body-parser");
const cookieParser = require("cookie-parser");

require("dotenv").config();

const app = express();

app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(cookieParser());

app.use("/app", express.static("public"));
app.use("/api", api);

app.listen(3000, () => {
    console.log("listening on port 3000")
});
