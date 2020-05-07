$.ajax(`/api/sum/loc`, { dataType: "json" }).done(rows => {
    rows.forEach(row => {
        $("#cust").append(`
            <tr>
              <td>${monthNames[row.month]}</td>
              <td>${row.day}</td>
              <td>${row.hour}</td>
              <td>${row.location}</td>
              <td>${row.orders}</td>
            </tr>
        `);
    })
})

const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];