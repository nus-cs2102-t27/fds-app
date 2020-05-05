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
  $.ajax("/api/del/status").done(status => {
    orders.forEach(order => {
        $("#current_orders").append(`
            <div class="choose-row">
              <div class="d-order-column">${formatDate(new Date(order.order_time))}</div>
              <div class="d-restaurant-column">${order.restaurant}</div>
              <div class="d-food-column">
                <div class="review-food-map">
                  ${order.food.map((f) => `
                    <div class="review-food-item">
                      <div>${f.qty} x ${f.name}</div>
                      <div>${f.price}</div>
                    </div>
                  `).join("")}
                </div>
              </div>
              <div class="d-address-column">${order.location}</div>
              <div class="d-take-column">
                ${status === "No current delivery" ? `
                  <form class="choose-form" action="/api/del/choose" method="post">
                    <input type="hidden" name="oid" value="${order.oid}">
                    <input type="submit" class="btn btn-primary submit-btn" value="Select">
                  </form>` : ""
                }
              </div>
            </div>
        `);
    })
  });
})