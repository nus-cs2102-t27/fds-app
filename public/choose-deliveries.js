const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function formatDate(date) {
    var year = date.getFullYear(),
        month = monthNames[date.getMonth()];
        day = date.getDate(),
        hour = date.getHours(),
        minute = date.getMinutes(),
        second = date.getSeconds(),
        hourFormatted = hour % 12 || 12, // hour returned in 24 hour format
        minuteFormatted = minute < 10 ? "0" + minute : minute,
        morning = hour < 12 ? "am" : "pm";

    return `${day} ${month} ${year} &nbsp ${hourFormatted}:${minuteFormatted}${morning}`;
}

$.ajax("/api/del/orders", { dataType: "json" }).done(orders => {
    orders.forEach(order => {
        $("#current_orders").append(`
            <tr>
              <td>${formatDate(new Date(order.order_time))}</td>
              <td>${order.restaurant}</td>
              <td>
                <table class="table-borderless">
                  ${order.food.map((f) => `
                    <tr>
                      <td>${f.qty} x ${f.name}</td>
                      <td>${f.price}</td>
                    </tr>
                  `).join("")}
                </table>
              </td>
              <td>${order.location}</td>
              <td>
                <input type="button" class="btn btn-primary submit-btn" value="Select">
              </td>
            </tr>
        `);
    })
})