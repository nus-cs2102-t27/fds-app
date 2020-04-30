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

$.ajax("/api/ord/review", { dataType: "json" }).done(orders => {
    orders.forEach(order => {        
        $("#review").append(`
            <tr>
              <td>${formatDate(new Date(order.order_time))}</td>
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
              <td>${order.total_price}</td>
              <td>
                <textarea class="form-control" name="${order.oid}" rows="4" style="resize: none"></textarea>
                <input type="button" onclick="window.location = '/app/review-orders.html'" class="btn btn-primary submit-btn" value="Submit">
              </td>
              <td><select class="custom-select" required>
                <option selected>Choose...</option>
                <option>1</option>
                <option>2</option>
                <option>3</option>
                <option>4</option>
                <option>5</option>
              </select></td>
            </tr>
        `);
    })
})
