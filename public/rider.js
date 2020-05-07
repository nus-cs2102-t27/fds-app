let status = "";

$("#rid-name").load("/api/auth/me/name");

$.ajax("/api/del/status").done(s => {
    status = s;
    $("#status").text(status);
    $("#rider-button").append(getRiderButton(status));
});

$.ajax("/api/rid/ftwork").done(status => {
    status ? $("#ft-work").append(`Start delivering!`) : "";
    $("#ft-work-status").append(`
        ${status ? "YES" : "NO"}
    `);
});

$.ajax("/api/rid/ptwork").done(status => {
    status ? $("#pt-work").append(`Start delivering!`) : "";
    $("#pt-work-status").append(`
        ${status ? "YES" : "NO"}
    `);
});

$.ajax(`/api/ftridersum/ftrider`, { dataType: "json" }).done(rows => {
    rows.forEach(row => {
        $("#ft-orders").text(row.monthly_orders);
        $("#ft-hours").text(row.hours_worked);
        $("#ft-salary").text(row.monthly_base_salary);
        $("#ft-earnings").text(row.lifetime_salary);
    })
});

$.ajax(`/api/ptridersum/ptrider`, { dataType: "json" }).done(rows => {
    rows.forEach(row => {
        $("#pt-orders").text(row.weekly_orders);
        $("#pt-hours").text(row.hours_worked);
        $("#pt-salary").text(row.weekly_base_salary);
        $("#pt-earnings").text(row.lifetime_salary);
    })
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