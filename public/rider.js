let status = "";

$("#rid-name").load("/api/auth/me/name");

$.ajax("/api/del/status").done(s => {
    status = s;
    $("#status").text(status);
    $("#rider-button").append(getRiderButton(status));
});

function getRiderButton(status) {
    switch (status) {
        case "Travelling to restaurant":
            return `<form action="/api/del/t2" method="post">
                        <input class="btn btn-danger submit-btn" type="submit" value="Reached Restaurant"></input>
                    </form>`;
        case "Waiting for customer's order":
            return `<form action="/api/del/t3" method="post">
                        <input class="btn btn-warning submit-btn" type="submit" value="Received customer's order"></input>
                    </form>`;
        case "Travelling to delivery address":
            return `<form action="/api/del/t4" method="post">
                        <input class="btn btn-success submit-btn" type="submit" value="Reached delivery address"</input>
                    </form>`;
        default:
            return "";
    }
}