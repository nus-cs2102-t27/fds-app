$.ajax(`/api/ptridersum/ptrider`, { dataType: "json" }).done(rows => {
    rows.forEach(row => {
        $("#ptrider").append(`
            <tr>
              <td>${row.ordersThisWeek}</td>
              <td>${row.hoursWorkedThisWeek}</td>
              <td>${row.salary}</td>
              <td>${row.lifetime_salary}</td>
            </tr>
        `);
    })
})

const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];