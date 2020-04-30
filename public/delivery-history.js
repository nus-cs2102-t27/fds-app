const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function formatDate(date) {
    console.log("test)");
    var year = date.getFullYear(),
        month = monthNames[date.getMonth()];
        day = date.getDate(),
        hour = date.getHours();

    return `${day} ${month} ${year}`;
}

function formatTime(date) {
    var minute = date.getMinutes(),
        hourFormatted = hour % 12 || 12, // hour returned in 24 hour format
        minuteFormatted = minute < 10 ? "0" + minute : minute,
        morning = hour < 12 ? "am" : "pm";

    return `${hourFormatted}:${minuteFormatted}${morning}`;
}

function formatRating(rating) {
    if (rating) {
        return rating;
    } else {
        return "Your delivery service has not been rated.";
    }
}

$.ajax("/api/del/all", { dataType: "json" }).done(deliveries => {
    deliveries.forEach(d => {        
        $("#deliveries").append(`
            <tr>
              <td>${formatDate(new Date(d.t4))}</td>
              <td>${d.name}
              <td>
                <table class="table-borderless">
                  ${d.food.map((f) => `
                    <tr>
                      <td>${f.qty} x ${f.name}</td>
                      <td>${f.price}</td>
                    </tr>
                  `).join("")}
                </table>
              </td>
              <td>
                <table class="table-borderless">
                  <tr>
                    <th>Left for Restaurant</th>
                    <th>Reached Restaurant</th>
                    <th>Left for Customer</th>
                    <th>Reached Customer</th>
                  <tr>
                    <td>${formatTime(new Date(d.t1))}</td>
                    <td>${formatTime(new Date(d.t2))}</td>
                    <td>${formatTime(new Date(d.t3))}</td>
                    <td>${formatTime(new Date(d.t4))}</td>
                  </tr>
                </table>
              </td>
              <td>${formatRating(d.rating)}</td>
            </tr>
        `);
    })
})
