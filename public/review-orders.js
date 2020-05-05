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
            <div class="review-row">
              <div class="order-column">${formatDate(new Date(order.order_time))}</div>
              <div class="restaurant-column">${order.restaurant}</div>
              <div class="food-column">
                <div class="review-food-map">
                  ${order.food.map((f) => `
                    <div class="review-food-item">
                      <div>${f.qty} x ${f.name}</div>
                      <div>${f.price}</div>
                    </div>
                  `).join("")}
                </div>
              </div>
              <div class="price-column">${order.total_price}</div>
              <form class="review-form" action="/api/ord/makereview" method="post">
                <div class="review-column">
                  <input type="hidden" name="oid" value="${order.oid}">
                  <textarea class="form-control" name="review" rows="4" style="resize: none"></textarea>
                  <input class="btn btn-primary submit-btn" type="submit" value="Submit">
                </div>
                <div class="rating-column"><select class="custom-select" required name="rating">
                  <option selected>Choose...</option>
                  <option value=1>1</option>
                  <option value=2>2</option>
                  <option value=3>3</option>
                  <option value=4>4</option>
                  <option value=5>5</option>
                </select></div>
              </form>
            </div>
            <hr>
        `);
        // $("#review").append(`
        //     <tr>
        //       <td>${formatDate(new Date(order.order_time))}</td>
        //       <td>
        //         <table class="table-borderless">
        //           ${order.food.map((f) => `
        //             <tr>
        //               <td>${f.qty} x ${f.name}</td>
        //               <td>${f.price}</td>
        //             </tr>
        //           `).join("")}
        //         </table>
        //       </td>
        //       <td>${order.total_price}</td>
        //       <form action="/api/ord/review" method="post">
        //         <td>
        //           <input type="hidden" name="oid" value="${order.oid}">
        //           <textarea class="form-control" name="review" rows="4" style="resize: none"></textarea>
        //           <input class="btn btn-primary submit-btn" type="submit" value="Submit">
        //         </td>
        //         <td><select class="custom-select" required name="rating">
        //           <option selected>Choose...</option>
        //           <option value=1>1</option>
        //           <option value=2>2</option>
        //           <option value=3>3</option>
        //           <option value=4>4</option>
        //           <option value=5>5</option>
        //         </select></td>
        //       </form>
        //     </tr>
        // `);
    })
})
