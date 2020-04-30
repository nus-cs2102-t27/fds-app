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

function formatReview(review) {
    if (review) {
        return review;
    } else {
        return "No review written";
    }
}

$.ajax("/api/ord/all", { dataType: "json" }).done(orders => {
    orders.forEach(order => {        
        $("#orders").append(`
            <tr>
              <td>${formatDate(new Date(order.order_time))}</td>
              <td>
                <table class="table-borderless">
                  ${order.food.map((f) => `
                    <tr>
                      <td>${f.qty} x ${f.name}</td>
                      <td>$${f.price}</td>
                    </tr>
                  `).join("")}
                </table>
              </td>
              <td>${formatReview(order.review)}</td>
              <td>$${order.total_price}</td>
            </tr>
        `);
    })
})
