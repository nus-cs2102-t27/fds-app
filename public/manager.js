$("#manager-name").load("/api/auth/me/name");

$.ajax("/api/sum/status").done(status =>
    $("#status-box").css("background-color", status ? "#7AFF6B": "#FF6B6B")
);